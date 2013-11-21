# Radio

Radio is an open-source wrapper to play Icecast Internet radio stations on iOS.

## Description

This project is the streaming part of the [Radio Javan](https://itunes.apple.com/us/app/radio-javan/id286225933?mt=8) app. The code here streams an Icecast stream (based on the URL), plays out the music to the audio device using Core Audio, and reads the metadata from the stream as the now playing title changes.

This code was initially written 5 years ago when the iOS SDK was first introduced. It's still used in production on a very popular app with hundreds of thousands of users.

Radio has been recently updated to support

* ARC
* 64-bit compiles
* iOS7 audio APIs

## Usage

You can create an instance of Radio:

	radio = [[Radio alloc] init];
	
Then connect to an Icecast stream:

	[radio connect:@"http://stream.radiojavan.com" withDelegate:self withGain:(1.0)];
	
The example in RadioViewController shows how to use the Radio class and also use the delegate callbacks to update the view, handle interruptions, buffering, connection issues, etc

## Requirements

Latest iOS SDK (7.0+)

## License

Radio is available under the MIT license. See the LICENSE file for more info.

## Credits

Created by Hamed Hashemi