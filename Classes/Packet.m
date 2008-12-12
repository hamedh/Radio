//
//  Packet.m
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

#import "Packet.h"

@implementation Packet
-(AudioStreamPacketDescription)getDescription {
	return audioDescription;
}
-(void)setDescription: (AudioStreamPacketDescription)description {
	audioDescription = description;
}
-(NSData*)getData {
	return audioData;
}

-(void)setData: (NSData*)data {
	audioData = data;
}

-(void)dealloc {
	[audioData release];
	[super dealloc];
}

@end
