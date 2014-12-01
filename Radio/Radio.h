//
//  Radio.h
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

#import <UIKit/UIKit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AudioToolbox/AudioFileStream.h>
#include <AudioToolbox/AudioServices.h>
#include "Queue.h"
#include "Packet.h"
#import <AVFoundation/AVFoundation.h>


@protocol RadioDelegate
@optional
- (void)updateBuffering: (BOOL)value;
- (void)interruptRadio;
- (void)resumeInterruptedRadio;
- (void)networkChanged;
- (void)connectProblem;
- (void)audioUnplugged;
- (void)metaTitleUpdated:(NSString *)title;
@end

@interface Radio : NSObject {
    AudioFileStreamID             audioStreamID;
    AudioStreamBasicDescription   audioDataFormat;
    AudioQueueRef                 audioQueue;
    NSMutableData                *currentAudio;
    AudioQueueBufferRef           audioBuffers[6];
	BOOL						  audioStarted;
	BOOL						  audioPaused;
	BOOL						  audioBuffering;
    Queue                        *packetQueue;
	int							  audioTotalBytes;
	AudioStreamPacketDescription  audioDescriptions[512];
	AudioQueueBufferRef			  audioFreeBuffers[6];
	float						  audioCurrentGain;
	int							  audioOutOfBuffers;
    
	NSString *url;
	NSURLConnection *conn;
	NSMutableData *currentPacket;
	NSString *title;
	NSMutableData *metaData;
	NSDictionary *streamHeaders;
	int icyInterval;
	int metaLength;
	int streamCount;
	int alreadyLoaded;
	BOOL buffering;
	BOOL playing;
	BOOL interrupted;
	int attemptCount;
	NSObject<RadioDelegate> *radioDelegate;
	BOOL stopped;
	NSString *connectionUserAgent;
}

- (id)init:(NSString *)userAgent __deprecated_msg("Use initWithUserAgent instead");
- (id)initWithUserAgent:(NSString *)userAgent;
- (BOOL)connect:(NSString *)url withDelegate:(NSObject<RadioDelegate> *)delegate withGain:(float)gain;
- (void)updateGain:(float)value;
- (void)updatePlay:(BOOL)play;
- (void)pause;
- (void)resume;
- (void)stopRadio;
- (void)networkChanged;
- (void)audioUnplugged;

@end