//
//  NetworkTestViewController.h
//  Prop Loader
//
//	This class implements a network test mode that sends repeated tests to the Propeller.
//
//  Created by Mike Westerfield on 3/12/14 at the Byte Works, Inc.
//  Copyright (c) 2014 Parallax. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Loader.h"

@interface NetworkTestViewController : UIViewController <UITextFieldDelegate, LoaderDelegate>

@property (nonatomic) BOOL burnToEPROM;											// YES if we are burning the image to EPROM, else NO.
@property (nonatomic, retain) IBOutlet UITextField *checksumFailuresTextField;
@property (nonatomic, retain) NSString *fileName;								// The name of the binary file to load.
@property (nonatomic, retain) IBOutlet UITextField *loadRetriesTextField;
@property (nonatomic, retain) IBOutlet UITextField *numberOfTrialsTextField;
@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) IBOutlet UITextField *successfulLoadsTextField;
@property (nonatomic, retain) IBOutlet UIButton *testButton;
@property (nonatomic, retain) IBOutlet UITextField *unsuccessfulLoadsTextField;

- (IBAction) testButton: (id) sender;

@end
