//
//  Radio.m
//  iOS Radio
//
//  Created by Hamed Hashemi on 11/18/13.
//  Copyright (c) 2013 Hamed Hashemi. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "Radio.h"

@implementation Radio

#define DEBUG_LOG 1
#define VERBOSE_LOG 0
#define kPacketSize 8000
#define kAudioBufferSize 8000
#define kNumberBuffers 6
#define kMaxOutOfBuffers 15

#pragma mark - stream connection

- (id)init:(NSString *)userAgent {
    self = [super init];
	if (self != nil) {
		playing = YES;
		stopped = NO;
		connectionUserAgent = userAgent;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleInterruption:) name:AVAudioSessionInterruptionNotification object:[AVAudioSession sharedInstance]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRouteChange:) name:AVAudioSessionRouteChangeNotification object:[AVAudioSession sharedInstance]];
	}
	return self;
}

- (BOOL)connect: (NSString *)connectUrl withDelegate:(NSObject <RadioDelegate> *)delegate withGain:(float)gain {
	if (currentPacket == nil) {
		currentPacket = [[NSMutableData alloc] init];
	}
	else {
		[currentPacket setLength:0];
	}
	if (metaData == nil) {
		metaData = [[NSMutableData alloc] init];
	}
	else {
		[metaData setLength:0];
	}
	radioDelegate = delegate;
	if (currentAudio == nil) {
		currentAudio = [[NSMutableData alloc] init];
	}
	else {
		[currentAudio setLength:0];
	}
	streamCount = 0;
	icyInterval = 0;
	packetQueue = [[Queue alloc] init];
	audioPaused = NO;
	audioTotalBytes = 0;
	audioCurrentGain = gain;
	
	AudioFileStreamOpen((__bridge void *)(self),  &PropertyListener, &PacketsProc,  kAudioFileMP3Type, &audioStreamID);
	
    NSError *audio_error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:0 error:&audio_error];
    
	url = connectUrl;
	if (conn) {
		[conn cancel];
	}
	
	NSURL *u = [NSURL URLWithString: url];
    if (DEBUG_LOG) {
        NSLog(@"connecting to url %@", u);
    }
	NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:u];
	[req setCachePolicy:NSURLCacheStorageNotAllowed];
	[req setValue:@"1" forHTTPHeaderField:@"icy-metadata"];
	[req setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
	[req setValue:connectionUserAgent forHTTPHeaderField:@"User-Agent"];
	[req setTimeoutInterval:10];
	conn = [NSURLConnection connectionWithRequest:req delegate:self];
    
    if (radioDelegate && [radioDelegate respondsToSelector:@selector(updateBuffering:)]) {
        [radioDelegate updateBuffering:YES];
    }
	buffering = YES;
	interrupted = NO;
	audioBuffering = YES;
	
	return YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	NSHTTPURLResponse *u = (NSHTTPURLResponse *)response;
    if (DEBUG_LOG) {
        NSLog(@"HTTP response =  %d", (int)[u statusCode]);
    }
	
	streamHeaders = [u allHeaderFields];
    if (DEBUG_LOG) {
        NSLog(@"HTTP response Headers = %@", streamHeaders);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (VERBOSE_LOG) {
        NSLog(@"didReceiveData %d bytes", (int)[data length]);
    }
	NSInteger length = [data length];
	const char *bytes = (const char *)[data bytes];
	if (!icyInterval) {
		icyInterval = [[streamHeaders objectForKey:@"Icy-Metaint"] intValue];
        if (DEBUG_LOG) {
            NSLog(@"Icy interval = %u", icyInterval);
        }
		[self fillcurrentPacket:bytes withLength:length];
	}
	else {
		[self fillcurrentPacket:bytes withLength:length];
	}
}

- (void)reconnect {
    if (DEBUG_LOG) {
        NSLog(@"attempting to reconnect");
    }
	
	attemptCount++;
    if (DEBUG_LOG) {
        NSLog(@"attemptCount = %u", attemptCount);
    }
	if (attemptCount == 10) {
        if (radioDelegate && [radioDelegate respondsToSelector:@selector(connectProblem)]) {
            [radioDelegate connectProblem];
        }
		attemptCount = 0;
	}
	else {
		[self connect:url withDelegate:radioDelegate withGain:audioCurrentGain];
	}
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if (DEBUG_LOG) {
        NSLog(@"didFailWithError %@", error);
    }
	[self pause];
	if (stopped == YES) {
        if (DEBUG_LOG) {
            NSLog(@"stopped");
        }
		return;
	} else {
		buffering = YES;
        if (radioDelegate && [radioDelegate respondsToSelector:@selector(updateBuffering:)]) {
            [radioDelegate updateBuffering:YES];
        }
		[self reconnect];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (DEBUG_LOG) {
        NSLog(@"connectionDidFinishLoading");
    }
	[self pause];
	if (stopped == YES) {
		NSLog(@"stopped");
		return;
	} else {
		buffering = YES;
        if (radioDelegate && [radioDelegate respondsToSelector:@selector(updateBuffering:)]) {
            [radioDelegate updateBuffering:YES];
        }
		[self reconnect];
	}
}

#pragma mark - core audio processing

static void audioQueueCallBack(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    @autoreleasepool {
        Radio *streamer = (__bridge Radio *)inUserData;
        [streamer handleAudioQueueCallBack:inAQ withBuffer:inBuffer];
    }
}

- (void)handleAudioQueueCallBack:(AudioQueueRef)inAQ withBuffer:(AudioQueueBufferRef)inBuffer {
	if (audioPaused) {
        if (DEBUG_LOG) {
            NSLog(@"audioQueueCallBack returning, paused");
        }
		return;
	}
	Queue *queue = packetQueue;
	int numDescriptions = 0;
	inBuffer->mAudioDataByteSize = 0;
	
	@synchronized (packetQueue) {
		while ([queue peak]) {
			Packet *packet = [queue peak];
			NSData *data = [packet audioData];
			if ([data length]+inBuffer->mAudioDataByteSize < kAudioBufferSize) {
				packet = [queue returnAndRemoveOldest];
                memcpy((char*)inBuffer->mAudioData+inBuffer->mAudioDataByteSize, (const char*)[data bytes], [data length]);
				audioDescriptions[numDescriptions] = [packet audioDescription];
				audioDescriptions[numDescriptions].mStartOffset = inBuffer->mAudioDataByteSize;
				inBuffer->mAudioDataByteSize += [data length];
				numDescriptions++;
			}
			else {
                if (VERBOSE_LOG) {
                    NSLog(@"audioQueueCallBack %d bytes, %d bytes", (int)[data length], (int)inBuffer->mAudioDataByteSize);
                }
				break;
			}
		}
		
		if (inBuffer->mAudioDataByteSize > 0) {
            if (VERBOSE_LOG) {
                NSLog(@"AudioQueueEnqueueBuffer %d bytes, %d descriptions", (int)inBuffer->mAudioDataByteSize, numDescriptions);
            }
			AudioQueueEnqueueBuffer(inAQ, inBuffer, numDescriptions, audioDescriptions);
			audioBuffering = NO;
		}
		else if (inBuffer->mAudioDataByteSize == 0) {
            if (DEBUG_LOG) {
                NSLog(@"out of Buffers");
            }
			for (int i = 0; i < kNumberBuffers; i++) {
				if (!audioFreeBuffers[i]) {
					audioFreeBuffers[i] = inBuffer;
					break;
				}
			}
			audioBuffering = YES;
			audioOutOfBuffers++;
		}
	}
}

static void PropertyListener(void *inClientData,
							 AudioFileStreamID inAudioFileStream,
							 AudioFileStreamPropertyID inPropertyID,
							 UInt32 *ioFlags) {
    Radio *streamer = (__bridge Radio *)inClientData;
    [streamer handlePropertlyListener:inAudioFileStream fileStreamPropertyID:inPropertyID ioFlags:ioFlags];
}

- (void)handlePropertlyListener:(AudioFileStreamID)inAudioFileStream fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID ioFlags:(UInt32 *)ioFlags {
    
    OSStatus err = noErr;
    
    if (inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets) {
        NSError *audio_error;
        [[AVAudioSession sharedInstance] setActive:YES error:&audio_error];
		AudioStreamBasicDescription asbd;
		UInt32 asbdSize = sizeof(asbd);
		AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd);
		AudioQueueNewOutput(&asbd, audioQueueCallBack, (__bridge void *)(self), NULL, NULL, 0, &audioQueue);
		
		for (int i = 0; i < kNumberBuffers; ++i) {
			AudioQueueAllocateBuffer(audioQueue, kAudioBufferSize, &audioBuffers[i]);
		}
		
		// get magic cookie
		UInt32 cookieSize;
		Boolean writable;
		err = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
		if (err) {
            return;
        }
		void *cookieData = calloc(1, cookieSize);
		AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
		AudioQueueSetProperty(audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
	}
}

static void PacketsProc(void *inClientData,
						UInt32 inNumberBytes,
						UInt32 inNumberPackets,
						const void *inInputData,
						AudioStreamPacketDescription *inPacketDescriptions) {
	
    Radio *streamer = (__bridge Radio *)inClientData;
    [streamer handlePacketsProc:inInputData numberBytes:inNumberBytes numberPackets:inNumberPackets packetDescriptions:inPacketDescriptions];
	
    if (VERBOSE_LOG) {
        NSLog(@"processing packets %d bytes", (int)inNumberBytes);
    }
}

- (void)handlePacketsProc:(const void *)inInputData numberBytes:(UInt32)inNumberBytes numberPackets:(UInt32)inNumberPackets packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions {
    
    for (int i = 0; i < inNumberPackets; ++i) {
		Packet *packet = [[Packet alloc] init];
		AudioStreamPacketDescription description = inPacketDescriptions[i];
		[packet setAudioDescription:description];
		[packet setAudioData: [[NSData alloc] initWithBytes:(const char*)inInputData+description.mStartOffset length:description.mDataByteSize]];
		@synchronized (packetQueue) {
			[packetQueue addItem:packet];
		}
		audioTotalBytes += description.mDataByteSize;
	}
	
	if (!audioStarted && audioTotalBytes >= kNumberBuffers* kAudioBufferSize) {
		for (int i = 0; i < kNumberBuffers; ++i) {
            [self handleAudioQueueCallBack:audioQueue withBuffer:audioBuffers[i]];
		}
        if (DEBUG_LOG) {
            NSLog(@"starting the queue");
        }
		AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, audioCurrentGain);
		AudioQueueStart(audioQueue, NULL);
		audioStarted = YES;
	}
	
	// check for free buffers
	@synchronized (packetQueue) {
		for (int i = 0; i < kNumberBuffers; i++) {
			if (audioFreeBuffers[i]) {
                [self handleAudioQueueCallBack:audioQueue withBuffer:audioFreeBuffers[i]];
				audioFreeBuffers[i] = nil;
				break;
			}
		}
	}
    
}

- (void)processAudio: (const char*)buffer withLength:(NSInteger)length {
	if (!audioPaused) {
        if (VERBOSE_LOG) {
            NSLog(@"processAudio %d bytes", (int)length);
        }
		AudioFileStreamParseBytes(audioStreamID, (int)length, buffer, 0);
		if (audioBuffering && !buffering) {
			buffering = YES;
            if (radioDelegate && [radioDelegate respondsToSelector:@selector(updateBuffering:)]) {
                [radioDelegate updateBuffering:YES];
            }
		}
		else if (!audioBuffering && buffering) {
			buffering = NO;
            if (radioDelegate && [radioDelegate respondsToSelector:@selector(updateBuffering:)]) {
                [radioDelegate updateBuffering:NO];
            }
		}
		@synchronized (packetQueue) {
			if (audioOutOfBuffers > kMaxOutOfBuffers) {
				[self pause];
				if (stopped == YES) {
                    if (DEBUG_LOG) {
                        NSLog(@"out of buffers but stopped");
                    }
					return;
				}
				else {
					[NSTimer scheduledTimerWithTimeInterval:35 target:self selector:@selector(resume) userInfo:nil repeats:NO];
					audioOutOfBuffers = 0;
				}
			}
		}
	}
}

- (void)fillcurrentPacket: (const char *)buffer withLength:(NSInteger)len {
	for (unsigned i = 0; i < len; i++) {
		if (metaLength != 0) {
			if (buffer[i] != '\0')
			{
				[metaData appendBytes:buffer+i length:1];
			}
			metaLength--;
			if (metaLength == 0) {
                if (DEBUG_LOG) {
                    NSLog(@"song meta info, %s", [metaData bytes]);
                }
				title = [[NSString alloc] initWithBytes:[metaData bytes] length:[metaData length] encoding:NSUTF8StringEncoding];
                if (radioDelegate && [radioDelegate respondsToSelector:@selector(metaTitleUpdated:)]) {
                    [radioDelegate metaTitleUpdated:title];
                }
				[metaData setLength:0];
			}
		}
		else {
			if (streamCount++ < icyInterval) {
				[currentPacket appendBytes:buffer+i length:1];
				if ([currentPacket length] == kPacketSize) {
					[self processAudio:[currentPacket bytes] withLength:[currentPacket length]];
					[currentPacket setLength:0];
				}
			}
			else {
				metaLength = 16*(unsigned char)buffer[i];
				streamCount = 0;
			}
		}
	}
}

#pragma mark - interruptions/route change

- (void)handleInterruption:(NSNotification *)notification {
    int type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    
    if (type == AVAudioSessionInterruptionTypeBegan && !stopped) {
        if (radioDelegate && [radioDelegate respondsToSelector:@selector(interruptRadio)]) {
            [radioDelegate interruptRadio];
        }
		interrupted = YES;
    }
    else if (type == AVAudioSessionInterruptionTypeEnded && interrupted && !stopped) {
        if (radioDelegate && [radioDelegate respondsToSelector:@selector(resumeInterruptedRadio)]) {
            [radioDelegate resumeInterruptedRadio];
        }
    }
}

- (void)handleRouteChange:(NSNotification *)notification {
    int type = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] intValue];
    if (type == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        [self audioUnplugged];
    }
}


#pragma mark - controls

- (void)updateGain: (float)value {
	audioCurrentGain = value;
	if (audioStarted) {
		AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, audioCurrentGain);
	}
}

- (void)pause {
    if (DEBUG_LOG) {
        NSLog(@"pause");
    }
	Queue *queue = packetQueue;
	@synchronized (queue) {
		audioPaused = YES;
		[conn cancel];
		AudioFileStreamClose(audioStreamID);
		if (audioStarted) {
			AudioQueueStop(audioQueue, YES);
			AudioQueueReset(audioQueue);
			for (int i = 0; i < kNumberBuffers; ++i) {
				if (audioBuffers[i]) {
					AudioQueueFreeBuffer(audioQueue, audioBuffers[i]);
				}
			}
			AudioQueueDispose(audioQueue, YES);
			audioStarted = NO;
		}
		
		Packet *packet = [queue returnAndRemoveOldest];
		while (packet) {
			packet = [queue returnAndRemoveOldest];
		}
		for (int i = 0; i < kNumberBuffers; i++) {
			audioFreeBuffers[i] = nil;
		}
        NSError* audio_error;
        [[AVAudioSession sharedInstance] setActive:NO error:&audio_error];
	}
}

- (void)resume {
    if (DEBUG_LOG) {
        NSLog(@"resume");
    }
	if (!audioStarted) {
		audioPaused = NO;
		[self connect:url withDelegate:radioDelegate withGain:audioCurrentGain];
		buffering = YES;
        if (radioDelegate && [radioDelegate respondsToSelector:@selector(updateBuffering:)]) {
            [radioDelegate updateBuffering:YES];
        }
	}
}

- (void)updatePlay: (BOOL)play {
    if (DEBUG_LOG) {
        NSLog(@"updatePlay %d", play);
    }
	if (!play) {
		playing = NO;
		[self pause];
	}
	else {
		playing = YES;
		stopped = NO;
		[self resume];
	}
}

- (void)stopRadio {
	stopped = YES;
}

- (void)networkChanged {
    if (DEBUG_LOG) {
        NSLog(@"networkChanged");
    }
	[self connectionDidFinishLoading:nil];
}

- (void)audioUnplugged {
    if (radioDelegate && [radioDelegate respondsToSelector:@selector(audioUnplugged)]) {
        [radioDelegate audioUnplugged];
    }
}

- (void)dealloc {
	AudioFileStreamClose(audioStreamID);
	AudioQueueStop(audioQueue, YES);
	AudioQueueReset(audioQueue);
	for (int i = 0; i < kNumberBuffers; ++i) {
		AudioQueueFreeBuffer(audioQueue, audioBuffers[i]);
	}
	AudioQueueDispose(audioQueue, YES);
    
    packetQueue = nil;
    currentPacket = nil;
    metaData = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
