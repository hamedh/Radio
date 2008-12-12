//
//  Radio.m
//
//  Created by Hamed Hashemi on 7/17/08.
//  Copyright 2008 by Hamed Hashemi. All rights reserved.
//
//
// This file is part of iPhoneRadioApp.
// 
// iPhoneRadioApp is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 2 of the License.
// 
// iPhoneRadioApp is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with iPhoneRadioApp.  If not, see <http://www.gnu.org/licenses/>.
//
//

#import "Radio.h"

@implementation Radio

static int kPacketSize = 8000;
static int kAudioBufferSize = 8000;
static int kNumberBuffers = 6;
static int kMaxOutOfBuffers = 15;

static void audioQueueCallBack(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) 
{
	AQPlayerState *audioState = (AQPlayerState *)inUserData;
	if (audioState->paused) {
		NSLog(@"audioQueueCallBack returning, paused");
		return;
	}
	Queue *queue = audioState->packetQueue;
	int numDescriptions = 0;
	inBuffer->mAudioDataByteSize = 0;
	
	@synchronized (audioState->packetQueue) {
		while ([queue peak]) {
			Packet *packet = [queue peak];
			NSData *data = [packet getData];
			if ([data length]+inBuffer->mAudioDataByteSize < kAudioBufferSize) {
				packet = [queue returnAndRemoveOldest];
				data = [packet getData];
				memcpy((char*)inBuffer->mAudioData+inBuffer->mAudioDataByteSize, (const char*)[data bytes], [data length]);
				audioState->descriptions[numDescriptions] = [packet getDescription];
				audioState->descriptions[numDescriptions].mStartOffset = inBuffer->mAudioDataByteSize;
				inBuffer->mAudioDataByteSize += [data length];
				numDescriptions++;
				[packet release];
			}
			else {
				//				NSLog(@"audioQueueCallBack %d bytes, %d bytes", [data length], inBuffer->mAudioDataByteSize);
				break;
			}
		}
		
		if (inBuffer->mAudioDataByteSize > 0) {
			NSLog(@"AudioQueueEnqueueBuffer %d bytes, %d descriptions", inBuffer->mAudioDataByteSize, numDescriptions);
			AudioQueueEnqueueBuffer(inAQ, inBuffer, numDescriptions, audioState->descriptions);
			audioState->buffering = NO;
		}
		else if (inBuffer->mAudioDataByteSize == 0) {
			NSLog(@"OUT OF BUFFERS");
			for (int i = 0; i < kNumberBuffers; i++) {
				if (!audioState->freeBuffers[i]) {
					audioState->freeBuffers[i] = inBuffer;
					break;
				}
			}
			audioState->buffering = YES;
			audioState->outOfBuffers++;
		}
	}
}

static void PropertyListener(void *inClientData,
							 AudioFileStreamID inAudioFileStream,
							 AudioFileStreamPropertyID inPropertyID,
							 UInt32 *ioFlags) {
	OSStatus err = noErr;
	AQPlayerState *audioState = (AQPlayerState *)inClientData;
	
	NSLog(@"found property '%c%c%c%c'\n", (inPropertyID>>24)&255, (inPropertyID>>16)&255, (inPropertyID>>8)&255, inPropertyID&255);
	
	if (inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets) {
		AudioSessionSetActive(true);
		AudioStreamBasicDescription asbd;
		UInt32 asbdSize = sizeof(asbd);
		AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &asbdSize, &asbd);
		AudioQueueNewOutput(&asbd, audioQueueCallBack, inClientData, NULL, NULL, 0, &audioState->mQueue);
		
		for (int i = 0; i < kNumberBuffers; ++i) {
			AudioQueueAllocateBuffer(audioState->mQueue, kAudioBufferSize, &audioState->mBuffers[i]);
		}
		
		// get magic cookie
		UInt32 cookieSize;
		Boolean writable;
		err = AudioFileStreamGetPropertyInfo(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
		if (err) { return; }
		void* cookieData = calloc(1, cookieSize);
		AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
		AudioQueueSetProperty(audioState->mQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
	}
}

static void PacketsProc(void *inClientData,
						UInt32 inNumberBytes,
						UInt32 inNumberPackets,
						const void *inInputData,
						AudioStreamPacketDescription *inPacketDescriptions) {
	
	AQPlayerState *audioState = (AQPlayerState *)inClientData;
	
	//	NSLog(@"PacketsProc %d bytes", inNumberBytes);
	
	for (int i = 0; i < inNumberPackets; ++i) {
		Packet *packet = [[Packet alloc] init];
		AudioStreamPacketDescription description = inPacketDescriptions[i];
		[packet setDescription:description];
		[packet setData: [[NSData alloc] initWithBytes:(const char*)inInputData+description.mStartOffset length:description.mDataByteSize]];
		@synchronized (audioState->packetQueue) {
			[audioState->packetQueue addItem:packet];
		}
		audioState->totalBytes += description.mDataByteSize;
		[packet release];
	}
	
	if (!audioState->started && audioState->totalBytes >= kNumberBuffers* kAudioBufferSize) {
		for (int i = 0; i < kNumberBuffers; ++i) {
			audioQueueCallBack(inClientData, audioState->mQueue, audioState->mBuffers[i]);
		}
		NSLog(@"STARTING THE QUEUE");
		AudioQueueSetParameter(audioState->mQueue, kAudioQueueParam_Volume, audioState->currentGain);
		AudioQueueStart(audioState->mQueue, NULL);
		audioState->started = YES;
	}
	
	// check for free buffers
	@synchronized (audioState->packetQueue) {
		for (int i = 0; i < kNumberBuffers; i++) {
			if (audioState->freeBuffers[i]) {
				audioQueueCallBack(inClientData, audioState->mQueue, audioState->freeBuffers[i]);
				audioState->freeBuffers[i] = nil;
				break;
			}
		}
	}
}

void interruptionListenerCallback (void	*inUserData, UInt32 interruptionState) {
	Radio *radio = (Radio*)inUserData;
	if (interruptionState == kAudioSessionBeginInterruption) {
		[radio pause];
		NSLog(@"kAudioSessionBeginInterruption");
	}
	else if (interruptionState == kAudioSessionEndInterruption && radio->playing) {
		[radio resume];
		NSLog(@"kAudioSessionEndInterruption");
	}
}

-(BOOL) connect: (NSString *)loc withDelegate:(iPhoneRadioAppDelegate*)delegate withGain:(float)gain {
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
	appDelegate = delegate;
	if (audioState.currentAudio == nil) {
		audioState.currentAudio = [[NSMutableData alloc] init];
	}
	else {
		[audioState.currentAudio setLength:0];
	}
	streamCount = 0;
	icyInterval = 0;
	audioState.packetQueue = [[Queue alloc] init];
	audioState.paused = NO;
	audioState.totalBytes = 0;
	audioState.currentGain = gain;
	
	AudioFileStreamOpen(&audioState,  &PropertyListener, &PacketsProc,  kAudioFileMP3Type, &audioState.streamID);
	
	UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
	AudioSessionSetProperty (kAudioSessionProperty_AudioCategory, sizeof (sessionCategory), &sessionCategory);
	
	url = loc;
	if (conn) {
		[conn cancel];
		[conn release];
	}
	NSURL *u = [NSURL URLWithString: loc];
	NSLog(@"URL = %@", u);
	NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:u];
	[req setCachePolicy:NSURLCacheStorageNotAllowed];
	[req autorelease];
	[req setValue:@"1" forHTTPHeaderField:@"icy-metadata"];
	[req setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];
	[req setValue:@"iPhone/RJ 1.1" forHTTPHeaderField:@"User-Agent"];
	[req setTimeoutInterval:15];
	conn = [[NSURLConnection connectionWithRequest:req delegate:self] retain];	
	return YES;
}

-(void)updateGain: (float)value {
	audioState.currentGain = value;
	if (audioState.started) {
		AudioQueueSetParameter(audioState.mQueue, kAudioQueueParam_Volume, audioState.currentGain);
	}
}

-(void)pause {
	NSLog(@"pause");
	Queue *queue = audioState.packetQueue;
	@synchronized (queue) {
		if (audioState.started) {
			audioState.paused = YES;
			[conn cancel];
			AudioFileStreamClose(audioState.streamID);
			AudioQueueStop(audioState.mQueue, YES);
			AudioQueueReset(audioState.mQueue);
			for (int i = 0; i < kNumberBuffers; ++i) {
				AudioQueueFreeBuffer(audioState.mQueue, audioState.mBuffers[i]);
			}
			AudioQueueDispose(audioState.mQueue, YES);
			audioState.started = NO;
			
			Packet *packet = [queue returnAndRemoveOldest];
			while (packet) {
				[packet release];
				packet = [queue returnAndRemoveOldest];
			}
			for (int i = 0; i < kNumberBuffers; i++) {
				audioState.freeBuffers[i] = nil;
			}
			AudioSessionSetActive(false);
			[appDelegate updateBuffering:NO];
		}
	}
}

-(void)resume {
	NSLog(@"resume");
	if (!audioState.started) {
		audioState.paused = NO;
		[self connect:url withDelegate:appDelegate withGain:audioState.currentGain];
		buffering = YES;
		[appDelegate updateBuffering:YES];
	}
}

-(void)updatePlay: (BOOL)play {
	NSLog(@"updatePlay %d", play);
	if (!play) {
		playing = NO;
		[self pause];
	}
	else {
		playing = YES;
		[self resume];
	}
}

-(void) processAudio: (const char*)buffer withLength:(int)length {
	if (!audioState.paused) {
		//		NSLog(@"processAudio %d bytes", length);
		AudioFileStreamParseBytes(audioState.streamID, length, buffer, 0);
		if (audioState.buffering && !buffering) {
			buffering = YES;
			[appDelegate updateBuffering:YES];
		}
		else if (!audioState.buffering && buffering) {
			buffering = NO;
			[appDelegate updateBuffering:NO];
		}
		@synchronized (audioState.packetQueue) {
			if (audioState.outOfBuffers > kMaxOutOfBuffers) {
				[self pause];
				[NSTimer scheduledTimerWithTimeInterval:35 target:self selector:@selector(resume) userInfo:nil repeats:NO];
				audioState.outOfBuffers = 0;
			}
		}
	}
}

-(void) updateTitle {
	[appDelegate updateTitle:title];
}

-(void) fillcurrentPacket: (const char *)buffer withLength:(int)len {
	for (unsigned i = 0; i < len; i++) {
		if (metaLength != 0) {
			if (buffer[i] != '\0')
			{
				[metaData appendBytes:buffer+i length:1];
			}
			metaLength--;
			if (metaLength == 0) {
				[title release];
				title = [[NSString alloc] initWithBytes:[metaData bytes] length:[metaData length] encoding:NSUTF8StringEncoding];
				NSLog(@"SONG META %@", title);
				if (!alreadyLoaded) {
					[self updateTitle];
					[NSTimer scheduledTimerWithTimeInterval:0.5 target:appDelegate selector:@selector(loadMainView) userInfo:nil repeats:NO];
					alreadyLoaded = 1;
				}
				else {
					[NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(updateTitle) userInfo:nil repeats:NO];
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

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	NSHTTPURLResponse *u = (NSHTTPURLResponse *)response;
	NSLog(@"HTTP Response =  %u", [u statusCode]);
	
	streamHeaders = [u allHeaderFields];
    [streamHeaders retain];
	
	NSLog(@"HTTP Response Headers = %@", streamHeaders);
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	//	NSLog(@"didReceiveData %u bytes", [data length]);
	int length = [data length];
	const char *bytes = (const char *)[data bytes];
	if (!icyInterval) {
		icyInterval = [[streamHeaders objectForKey:@"Icy-Metaint"] intValue];
		NSLog(@"ICY INTERVAL = %u", icyInterval);
		[self fillcurrentPacket:bytes withLength:length];
	}
	else {
		[self fillcurrentPacket:bytes withLength:length];
	}
}

-(void)reconnect {
	NSLog(@"Attempting to reconnect");
	[self connect:url withDelegate:appDelegate withGain:audioState.currentGain];
	
	attemptCount++;
	NSLog(@"attemptCount = %u", attemptCount);
	if (attemptCount == 3)
	{
		alert = [[UIAlertView alloc] initWithTitle:@"Unable To Play" message:@"We can't seem to play Radio Javan at this moment. Please check your internet connection on your device and make sure you are either on a 3G or WiFi connection." 
										  delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		attemptCount = 0;
	}
}

-(void)alertViewCancel:(UIAlertView *)alertView
{
	[alert release];
}

-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"didFailWithError %@", error);
	if (alreadyLoaded) {
		[self pause];
		audioState.buffering = YES;
		[appDelegate updateBuffering:YES];
	}
	[NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(reconnect) userInfo:nil repeats:NO];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSLog(@"connectionDidFinishLoading");
	if (alreadyLoaded) {
		[self pause];
		audioState.buffering = YES;
		[appDelegate updateBuffering:YES];
	}
	[NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(reconnect) userInfo:nil repeats:NO];
}

- (id)init {
	if (self = [super init]) {
		playing = YES;
		AudioSessionInitialize (NULL, NULL, interruptionListenerCallback, self);
	}
	return self;
}

-(void)dealloc {
	AudioFileStreamClose(audioState.streamID);
	AudioQueueStop(audioState.mQueue, YES);
	AudioQueueReset(audioState.mQueue);
	for (int i = 0; i < kNumberBuffers; ++i) {
		AudioQueueFreeBuffer(audioState.mQueue, audioState.mBuffers[i]);
	}
	AudioQueueDispose(audioState.mQueue, YES);
	[audioState.packetQueue release];
	[currentPacket release];
	[metaData release];
	[alert release];
	[super dealloc];
}
@end
