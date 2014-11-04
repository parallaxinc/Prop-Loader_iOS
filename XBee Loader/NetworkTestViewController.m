//
//  NetworkTestViewController.m
//  Prop Loader
//
//	Implements a test mode used to check loader reliability on a network.
//
//  Created by Mike Westerfield on 3/12/14 at the Byte Works, Inc.
//  Copyright (c) 2014 Parallax. All rights reserved.
//

#import "NetworkTestViewController.h"

#import "Common.h"
#import "TXBee.h"


#define SLEEP_TIME (2.0)					/* Time between loads. This gives the program time to start so we */
											/* get visual verification of success. */

@interface NetworkTestViewController () {
    BOOL canceling;							// Are we canceling a test?
    int count;								// The number of remaining loads in the test.
    BOOL doingTest;							// YES if we are currently doing a test, else NO.
    NSString *ipAddress;					// The IP address of the XBee radio.
    int maxLoads;							// The maximum number of load attempts before giving up.
    int serialPort;							// The Serial port.
    float trials;							// The number of total trials in the test.
}

@property (nonatomic, retain) TXBee *xBee;	// The active XBee component.

@end

@implementation NetworkTestViewController

@synthesize burnToEPROM;
@synthesize checksumFailuresTextField;
@synthesize fileName;
@synthesize loadRetriesTextField;
@synthesize numberOfTrialsTextField;
@synthesize progressView;
@synthesize successfulLoadsTextField;
@synthesize testButton;
@synthesize unsuccessfulLoadsTextField;
@synthesize xBee;

/*!
 * Call to perform another test after a successful or unsuccessful load.
 */

- (void) anotherTest {
	if (count-- > 0 && !canceling) {
        // Do another test.
        progressView.progress = (trials - count - 1)/trials;
        [self performSelectorInBackground: @selector(load) withObject: nil];
    } else {
        // The tests are complete; stop the tests.
        [testButton setTitle: @"Start the Test" forState: UIControlStateNormal];
        doingTest = NO;
        progressView.hidden = YES;
    }
}

/*!
 * Call the loader to load and execute the program.
 */

- (void) load {
    self.xBee = [[TXBee alloc] init];
    xBee.ipAddr = ipAddress;
    xBee.ipPort = serialPort;
    xBee.cfgChecksum = CHECKSUM_UNKNOWN;
    xBee.name = @"";
    
    Loader *loader = [Loader defaultLoader];
    loader.delegate = self;
    
    NSError *error = nil;
    [loader load: fileName
           eprom: burnToEPROM
            xBee: xBee
    loadAttempts: maxLoads
           error: &error];
    if (error != nil)
	    printf("Error(%d): %s\n", (int) error.code, [error.localizedDescription UTF8String]);
}

/*!
 * Load the preferences.
 */

- (void) loadPreferences {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *preferenceIPAddress = [defaults stringForKey: @"ip_address_preference"];
    if (preferenceIPAddress != nil)
        ipAddress = preferenceIPAddress;
    
    serialPort = 9750;
    NSString *serialPortPreference = [defaults stringForKey: @"serial_port_preference"];
    if (serialPortPreference != nil)
        serialPort = (int) [serialPortPreference integerValue];
    
    NSString *loadsPreference = [defaults stringForKey: @"load_retry_preference"];
    if (loadsPreference == nil)
        maxLoads = 2;
    else
        maxLoads = (int) [loadsPreference integerValue];
}

/*!
 * Handle a hit on the load button.
 *
 * @param sender			The button that triggered this call.
 */

- (IBAction) testButton: (id) sender {
    if (doingTest) {
        canceling = YES;
        doingTest = NO;
        [testButton setTitle: @"Start the Test" forState: UIControlStateNormal];
        progressView.hidden = YES;
        [NSObject cancelPreviousPerformRequestsWithTarget: self];
        [[Loader defaultLoader] cancel];
    } else {
        // Change the button to be a cancel button.
        [testButton setTitle: @"Cancel the Test" forState: UIControlStateNormal];
        
        // Get the IP address, ports, etc.
        [self loadPreferences];
        
        // Reset all counts.
        successfulLoadsTextField.text = @"0";
        unsuccessfulLoadsTextField.text = @"0";
        loadRetriesTextField.text = @"0";
        checksumFailuresTextField.text = @"0";
        
        // Start the test.
        canceling = NO;
        progressView.progress = 0.0;
        progressView.hidden = NO;
        [self performSelectorInBackground: @selector(test) withObject: nil];
    }
    doingTest = !doingTest;
}

/*!
 * Perform the load test multiple times, collecting statistics as we go.
 */

- (void) test {
    // Get the number of times to perform the test.
    count = (int) [numberOfTrialsTextField.text integerValue] - 1;
    trials = count + 1;
    
    // Start the first load.
    [self load];
}

#pragma mark - View maintenance

/*!
 * Notifies the view controller that its view is about to be added to a view hierarchy.
 *
 * @param animated		If YES, the view is being added to the window using an animation.
 */

- (void) viewDidAppear: (BOOL) animated {
    [super viewDidAppear: animated];
    [self.navigationController setNavigationBarHidden: NO animated: YES];
}

/*!
 * Notifies the view controller that its view is about to be removed from a view hierarchy.
 *
 * @param animated		If YES, the view is being removed using an animation.
 */

- (void) viewWillDisappear: (BOOL) animated {
    [self.navigationController setNavigationBarHidden: YES animated: NO];
    [super viewWillDisappear: animated];
}

#pragma mark - UITextFieldDelegate

/*!
 * Asks the delegate if the text field should process the pressing of the return button. We use this
 * to dismiss the keyboard when the user is entering text in one of the UITextField objects and to
 * record the new values.
 *
 * @param textField		The text field whose return button was pressed.
 */

- (BOOL) textFieldShouldReturn: (UITextField *) textField {
    [textField resignFirstResponder];
    return NO;
}

#pragma mark - LoaderDelegate

/*!
 * Called when the Propeller board reported a checksum failure. This may or may not result in an unsuccessful
 * load, depending on whether there are load retries left.
 *
 * This method is always called from the main thread.
 */

- (void) checksumFailure {
    checksumFailuresTextField.text = [NSString stringWithFormat: @"%d", (int) [checksumFailuresTextField.text integerValue] + 1];
}

/*!
 * Called when the laoder has completed loading the binary.
 *
 * The loader is now in a dormant state, waiting for a new load.
 *
 * This method is not called if loaderFatalError is called to report an unsuccessful load.
 *
 * This method is always called from the main thread.
 */

- (void) loaderComplete {
    successfulLoadsTextField.text = [NSString stringWithFormat: @"%d", (int) [successfulLoadsTextField.text integerValue] + 1];
	[self performSelector: @selector(anotherTest) withObject: nil afterDelay: SLEEP_TIME];
}

/*!
 * Called when the binary failed to load. This may or may not result in an unsuccessful load, depending on
 * whether there are load retries left. This count includes any checksum failures, and also includes handshake
 * failures if they exceeded the number of handshake retries..
 *
 * This method is always called from the main thread.
 */

- (void) loadFailure {
    loadRetriesTextField.text = [NSString stringWithFormat: @"%d", (int) [loadRetriesTextField.text integerValue] + 1];
}

/*!
 * Called when the internal status of the loader changes, this method supplies a status string suitable for
 * display in a UI to provide textual progress information.
 *
 * Errors whose domain is [[Loader defaultLoader] loaderDomain] indicate internal errors in the loader, as follows:
 *
 *		id		error
 *		--		-----
 *		1		The Propeller did not respond to a reset/handshake attempt, even after the maximum allowed number
 *				of tries, as specified when starting the laod.
 *		2		The handshake was successfu, but the Propeller did not respond. This is only reported if the
 *				load has failed the maximum number of allowed times, as specified when starting the laod.
 *		3		The Propeller reaponded to a load, but the checksum was invalid. This is only reported if the
 *				load has failed the maximum number of allowed times, as specified when starting the load.
 *
 * Any other error is passed up from iOS, and generally indicates an error that inticates a fundamental problem
 * that makes trying again pointless.
 *
 * The loader is now in a dormant state, waiting for a new load.
 *
 * This method is always called from the main thread.
 *
 * @param error			The error.
 */

- (void) loaderFatalError: (NSError *) error {
    unsuccessfulLoadsTextField.text = [NSString stringWithFormat: @"%d", (int) [unsuccessfulLoadsTextField.text integerValue] + 1];
	[self anotherTest];
}

@end
