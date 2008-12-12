//
//  iPhoneRadioAppDelegate.m
//
//  Created by Hamed Hashemi on 12/12/08.
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

#import "iPhoneRadioAppDelegate.h"
#import "Radio.h"

@implementation iPhoneRadioAppDelegate

@synthesize window;
@synthesize radio;

-(void)loadMainView {
	// this was used to switch from the starting/buffering view to the now playing view, see the "Radio Javan" app in the App Store for how that works
}

-(void)updateTitle:(NSString*)title {
	// update view text
}

-(void)updateGain:(float)value {
	// update volume slider
}

-(void)updatePlay:(BOOL)play {
	// toggle play/pause button
}

-(void)updateBuffering: (BOOL)value {
	// update buffer indicator
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {
	// Configure and show the window
	[window makeKeyAndVisible];
	
	radio = [[Radio alloc] init];
	[radio connect:@"http://stream.radiojavan.com/radiojavan" withDelegate:self withGain:(0.5)];
}


- (void)applicationWillTerminate:(UIApplication *)application {
	// Save data if appropriate
}


- (void)dealloc {
	[window release];
	[radio release];
	[super dealloc];
}

@end
