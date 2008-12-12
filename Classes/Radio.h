//
//  Radio.h
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

#import <UIKit/UIKit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AudioToolbox/AudioFileStream.h>
#include <AudioToolbox/AudioServices.h>
#include "Queue.h"
#include "Packet.h"
#include "iPhoneRadioAppDelegate.h"

typedef struct {
    AudioFileStreamID             streamID;
    AudioStreamBasicDescription   mDataFormat;
    AudioQueueRef                 mQueue;
	NSMutableData				  *currentAudio;
    AudioQueueBufferRef           mBuffers[6];
	BOOL						  started;
	BOOL						  paused;
	BOOL						  buffering;
	Queue						  *packetQueue;
	int							  totalBytes;
	AudioStreamPacketDescription  descriptions[512];
	AudioQueueBufferRef			  freeBuffers[6];
	float						  currentGain;
	int							  outOfBuffers;
} AQPlayerState;

@interface Radio : NSObject {
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
	int attemptCount;
	UIAlertView *alert;
	iPhoneRadioAppDelegate *appDelegate;
	AQPlayerState audioState;
}

-(id)init;
-(BOOL)connect:(NSString *)loc withDelegate:(iPhoneRadioAppDelegate*)delegate withGain:(float)gain;
-(void)updateGain:(float)value;
-(void)updatePlay:(BOOL)play;
-(void)pause;
-(void)resume;

@end
