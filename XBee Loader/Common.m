//
//  Common.m
//  XBee Loader
//
//	This class contains macros and methods for reporting hardware specific values and system wide constants.
//
//  Created by Mike Westerfield on 4/17/14 at the Byte Works, Inc.
//  Copyright (c) 2014 Parallax. All rights reserved.
//

#import "Common.h"

static int port;				// The UDP Port.
static BOOL udpPortSet;			// True if the UDP port has been set, else false.

@implementation Common

/*!
 * Get the UDP port.
 *
 * The UDP port cannot be changed once set, and generally should not be changed. This method returns the XBee UDP port for all classes in the program.
 *
 * The defult prot is 0x0BEE.
 *
 * @return		The UDP port number.
 */

+ (int) udpPort {
    if (!udpPortSet) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *udpPortPreference = [defaults stringForKey: @"ap_port_preference"];
        if (udpPortPreference == nil)
            port = 0xBEE;
        else
            port = (int) [udpPortPreference integerValue];
        udpPortSet = YES;
    }
    return port;
}

@end
