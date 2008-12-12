//
//  Queue.m
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

#import "Queue.h"


@implementation Queue

// Initialize a empty mutable array for queue items
// which we can fill
-(id) init
{
	self = [super init];
	{
		mItemArray = [NSMutableArray arrayWithCapacity:0];
		[mItemArray retain];
	}
	
	return self;
}

// Returns (and removes) the oldest item in the queue
-(id)returnAndRemoveOldest
{
	id anObject = nil;
	
	anObject = [mItemArray lastObject];
	if (anObject)
	{
		[anObject retain];
		[mItemArray removeLastObject];    
	}
	
	return anObject;  
}

// Peak at the next item in the queue
-(id)peak
{
	return [mItemArray lastObject];
}

// Adds the specified item to the queue
-(void)addItem:(id)anItem
{
	[mItemArray insertObject:anItem atIndex:0];
}

-(int)size
{
	return [mItemArray count];
}

-(void)empty
{
	[mItemArray removeAllObjects];
}

-(void) dealloc
{
	[mItemArray release];
	[super dealloc];
}

@end
