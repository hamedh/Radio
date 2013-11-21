//
//  RadioViewController.m
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

#import "RadioViewController.h"

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

#define STREAM_URL @"http://stream.radiojavan.com"

@interface RadioViewController ()

@end

@implementation RadioViewController

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame: [UIScreen mainScreen].applicationFrame];
    self.view.backgroundColor = [UIColor blackColor];
    self.view.clipsToBounds = YES;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    radio = [[Radio alloc] init:@"my app"];
    [radio connect:STREAM_URL withDelegate:self withGain:(1.0)];
    playing = YES;
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:@"Stop" forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    button.frame = CGRectMake((self.view.frame.size.width - 50) / 2, 100, 50, 33);
    [button addTarget:self action:@selector(toggleRadio) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 130, self.view.frame.size.width - 20, 50)];
    titleLabel.font = [UIFont boldSystemFontOfSize:14];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.numberOfLines = 0;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)toggleRadio {
    if (playing) {
        playing = NO;
        [radio updatePlay:NO];
        [button setTitle:@"Play" forState:UIControlStateNormal];
    }
    else {
        playing = YES;
        [radio updatePlay:YES];
        [button setTitle:@"Stop" forState:UIControlStateNormal];
    }
}

#pragma mark -

- (void)updateBuffering:(BOOL)value {
    NSLog(@"delegate update buffering %d", value);
}

- (void)interruptRadio {
    NSLog(@"delegate radio interrupted");
}

- (void)resumeInterruptedRadio {
    NSLog(@"delegate resume interrupted radio");
}

- (void)networkChanged {
    NSLog(@"delegate network changed");
}

- (void)connectProblem {
    NSLog(@"delegate connection problem");
}

- (void)audioUnplugged {
    NSLog(@"delegate audio unplugged");
}

- (void)metaTitleUpdated:(NSString *)title {
    NSLog(@"delegate title updated to %@", title);
    
    NSArray *chunks = [title componentsSeparatedByString:@";"];
    if ([chunks count]) {
        NSArray *streamTitle = [[chunks objectAtIndex:0] componentsSeparatedByString:@"="];
        if ([streamTitle count] > 1) {
            titleLabel.text = [streamTitle objectAtIndex:1];
        }
    }
}

@end
