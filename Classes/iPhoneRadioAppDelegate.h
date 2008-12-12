//
//  iPhoneRadioAppDelegate.h
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

#import <UIKit/UIKit.h>

@class Radio;

@interface iPhoneRadioAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
	Radio *radio;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) Radio *radio;

-(void)loadMainView;
-(void)updateTitle:(NSString*)title;
-(void)updateGain:(float)value;
-(void)updatePlay:(BOOL)play;
-(void)updateBuffering: (BOOL)value;

@end

