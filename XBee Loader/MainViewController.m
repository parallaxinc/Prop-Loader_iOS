//
//  MainViewController.m
//  Prop Loader
//
//	Implements functionality for the main view of the Prop Loader app.
//
//	Loading generally begins when the user clicks load button, causing a call to loadButton:. Loading
//	is done using asychronous TCP and UDP connections, so the flow of control is not straight-forward.
//	The flow is controlled through the use of a state handler. See checkStatus for an overview of the
//	flow of control through the state handler.
//
//  Created by Mike Westerfield on 2/10/14 at the Byte Works, Inc.
//  Copyright (c) 2014 Parallax. All rights reserved.
//

#import "MainViewController.h"

#import "Common.h"
#import "ConfigurationViewController.h"
#import "NetworkTestViewController.h"
#import "TXBee.h"

@interface MainViewController () {
    BOOL doingLoad;							// YES if we are currently doing a load, else NO.
    int maxLoads;							// The maximum number of load attempts before giving up.
    int serialPort;							// The serial port.
}

@property (nonatomic, retain) NSMutableArray *binaries;				// List of the binary files that can be loaded.
@property (nonatomic, retain) IBOutlet UIPickerView *binaryPicker;	// The picker control used to display and select binaries for uplaod.
@property (nonatomic, retain) NSString *ipAddress;					// The IP address of the XBee radio.
@property (nonatomic) BOOL viewingAlert;							// True when the user is viewing an alert.
@property (nonatomic) TXBee *xBee;									// Information about the current device.

@end


@implementation MainViewController

@synthesize binaries;
@synthesize binaryPicker;
@synthesize epromSwitch;
@synthesize ipAddress;
@synthesize ipAddressLabel;
@synthesize loadButton;
@synthesize nameLabel;
@synthesize progressView;
@synthesize statusLabel;
@synthesize viewingAlert;
@synthesize xBee;

/*!
 * Load a binary to the propeller. 
 *
 * This method must be called on a background thread.
 */

- (void) load {
    long index = [binaryPicker selectedRowInComponent: 0];
    NSString *fileName = [binaries objectAtIndex: index];
    
    Loader *loader = [Loader defaultLoader];
    loader.delegate = self;

    NSError *error = nil;
    [loader load: fileName
           eprom: epromSwitch.isOn
            xBee: xBee
    loadAttempts: maxLoads
           error: &error];
    if (error)
        [self performSelectorOnMainThread: @selector(reportError:) withObject: error waitUntilDone: NO];
}

/*!
 * Handle a hit on the load button.
 *
 * @param sender			The button that triggered this call.
 */

- (IBAction) loadButton: (id) sender {
    if (doingLoad) {
        [self resetLoadButton];
        [[Loader defaultLoader] cancel];
    } else {
        // Change the button to be a cancel button.
        [loadButton setTitle: @"Cancel the Load" forState: UIControlStateNormal];
        
        // Do the load on another thread.
        [self performSelectorInBackground: @selector(load) withObject: nil];
    }
    doingLoad = !doingLoad;
}

/*!
 * Load the preferences.
 */

- (void) loadPreferences {
    // TODO: Add support for FTP binaries
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
 * Report an error.
 *
 * If the app is in test mode, this just records the kind of error for statistics. If the user is loading a single
 * program, this reports the error in an error dialog.
 *
 * The caller is responsible for clean up and placing the machine back into a stable state.
 *
 * @param error		The system error to report.
 */

- (void) reportError: (NSError *) error {
    // Make sure the user isn't already seeing an error. (This prevents the stream methods from
    // reporting a cascade of errors, forcing the user to dismiss each one.)
    if (!viewingAlert) {
        // Display the error in an alert.
        self.viewingAlert = YES;
        NSString *title = @"Load Failed";
        if (error.code >= 10)
            title = @"Device Not Found";
        NSString *message = [error localizedDescription];
        if (error.localizedFailureReason != nil)
            message = [NSString stringWithFormat: @"%@\n\n%@", message, error.localizedFailureReason];
        if (error.localizedRecoverySuggestion != nil)
            message = [NSString stringWithFormat: @"%@\n\n%@", message, error.localizedRecoverySuggestion];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                        message: message
                                                       delegate: self
                                              cancelButtonTitle: @"OK"
                                              otherButtonTitles: nil];
        [alert show];
    }
    [self resetLoadButton];
}

/*!
 * Reset the load button so it prompts to start a new load.
 */

- (void) resetLoadButton {
    [loadButton setTitle: @"Load the Image" forState: UIControlStateNormal];
    doingLoad = NO;
}

/*!
 * Update the name of the current device.
 *
 * Do not call this method from the main thread.
 */

- (void) updateDeviceName {
    NSString *deviceName = [[Loader defaultLoader] getDeviceName: xBee];
    if (deviceName != nil)
        deviceName =[NSString stringWithFormat: @"Name: %@", deviceName];
    else {
        NSError *error = [NSError errorWithDomain: [[Loader defaultLoader] loaderDomain]
                                             code: 20
                                         userInfo: [NSDictionary dictionaryWithObjectsAndKeys:
                                                    @"An XBee device with the given IP address was not found.",
                                                    NSLocalizedDescriptionKey,
                                                    @"Make sure the device is turned on and in range. Use Settings to scan for available devices; this will also confirm the device is turned on.",
                                                    NSLocalizedRecoverySuggestionErrorKey,
                                                    nil]];
        [self performSelectorOnMainThread: @selector(reportError:) withObject: error waitUntilDone: NO];
    }
    
    [nameLabel performSelectorOnMainThread: @selector(setText:) withObject: deviceName waitUntilDone: NO];
}

#pragma mark - View maintenance

/*!
 * Called after the controller’s view is loaded into memory.
 */

- (void) viewDidLoad {
    [super viewDidLoad];
    
    // Create the binary file picker. This is done in code rather than in the nib file to avoid a bug in
    // iOS 6.1 that causes the picker to be resized when the view is rerdawn, particularly when the
    // Load the Image button is pressed, the keyboard is shown/hidden, or the view appears after showing
    // the network test view.
    if (IS_4_INCH_IPHONE)
        binaryPicker = [[UIPickerView alloc] initWithFrame: CGRectMake(0, 237, 320, 216)];
    else
        binaryPicker = [[UIPickerView alloc] initWithFrame: CGRectMake(0, 232, 320, 162)];
    binaryPicker.delegate = self;
    binaryPicker.dataSource = self;
    binaryPicker.showsSelectionIndicator = YES;
    [self.view addSubview: binaryPicker];
    
    // Get the list of available binaries.
    binaries = [[NSMutableArray alloc] init];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *path = [paths objectAtIndex: 0];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath: path error: NULL];
	for (NSString *fileName in files) {
        if ([[fileName pathExtension] isEqualToString: @"binary"])
            [binaries addObject: [path stringByAppendingPathComponent: fileName]];
    }

    // Set our initial state.
    Loader *loader = [Loader defaultLoader];
    loader.delegate = self;
    
    // Load the preferences once. This makes sure they are set on a new install, enabling test mode to fetch
    // an IP address and TCP port.
    [self loadPreferences];
    
    // Set up an XBee device record.
    if (xBee == nil) {
        self.xBee = [[TXBee alloc] init];
        xBee.ipAddr = ipAddress;
        xBee.ipPort = serialPort;
        xBee.cfgChecksum = CHECKSUM_UNKNOWN;
        xBee.name = @"";
    }
}

/*!
 * Notifies the view controller that its view was added to a view hierarchy.
 *
 * You can override this method to perform additional tasks associated with presenting the view. If you override 
 * this method, you must call super at some point in your implementation.
 *
 * @param animated	If YES, the view was added to the window using an animation.
 */

- (void) viewDidAppear: (BOOL) animated {
	// Update the IP address.
    [self loadPreferences];
    ipAddressLabel.text = [NSString stringWithFormat: @"IP: %@", ipAddress];
    
    // Get the XBee object for this iP address (if any).
    NSArray *devices = [ConfigurationViewController xBeeDevices];
    TXBee *device = nil;
    for (TXBee *aDevice in devices)
        if ([aDevice.ipAddr isEqualToString: ipAddress]) {
            device = aDevice;
            break;
        }
    
    if (device) {
        nameLabel.text = device.name;
        ipAddress = device.ipAddr;
        self.xBee = device;
    } else {
        // Update the device name, but since it uses the Loader, which must listen to the UDP port on the main
        // thread, do this on another thread.
        [self performSelectorInBackground: @selector(updateDeviceName) withObject: nil];
    }
    
    [super viewDidAppear: animated];
}

#pragma mark - Navigation

/*!
 * Notifies the view controller that a segue is about to be performed.
 *
 * The default implementation of this method does nothing. Your view controller overrides this method when it needs to
 * pass relevant data to the new view controller. The segue object describes the transition and includes references to
 * both view controllers involved in the segue.
 *
 * Because segues can be triggered from multiple sources, you can use the information in the segue and sender parameters
 * to disambiguate between different logical paths in your app. For example, if the segue originated from a table view,
 * the sender parameter would identify the table view cell that the user tapped. You could use that information to set
 * the data on the destination view controller.
 *
 * @param seque		The segue object containing information about the view controllers involved in the segue.
 * @param sender	The object that initiated the segue. You might use this parameter to perform different actions
 *					based on which control (or other object) initiated the segue.
 */

- (void) prepareForSegue: (UIStoryboardSegue *) segue sender: (id) sender {
    if ([segue.identifier isEqualToString: @"NetworkTest"]) {
        NetworkTestViewController *networkTestViewController = segue.destinationViewController;
        long index = [binaryPicker selectedRowInComponent: 0];
        networkTestViewController.fileName = [binaries objectAtIndex: index];
        networkTestViewController.burnToEPROM = epromSwitch.isOn;
    }
}

#pragma mark - UIPickerViewDataSource

/*!
 * Called by the picker view when it needs the number of components.
 *
 * @param pickerView		The picker view requesting the data.
 *
 * @return					The number of components (or “columns”) that the picker view should display.
 */

- (NSInteger) numberOfComponentsInPickerView: (UIPickerView *) pickerView {
    return 1;
}

/*!
 * Called by the picker view when it needs the number of rows for a specified component.
 *
 * @param pickerView		The picker view requesting the data.
 * @param component			A zero-indexed number identifying a component of pickerView. Components are
 *							numbered left-to-right.
 *
 * @return					The number of rows for the component.
 */

- (NSInteger) pickerView: (UIPickerView *) pickerView numberOfRowsInComponent: (NSInteger) component {
    return binaries.count;
}

#pragma mark - UIPickerViewDelegate

/*!
 * Called by the picker view when it needs the title to use for a given row in a given component.
 *
 * @param pickerView		An object representing the picker view requesting the data.
 * @param row				A zero-indexed number identifying a row of component. Rows are numbered 
 *							top-to-bottom.
 * @param component			A zero-indexed number identifying a component of pickerView. Components 
 *							are numbered left-to-right.
 *
 * @return					The string to use as the title of the indicated component row.
 */

- (NSString *) pickerView: (UIPickerView *) pickerView titleForRow: (NSInteger) row forComponent: (NSInteger) component {
    return [[[binaries objectAtIndex: row] lastPathComponent] stringByDeletingPathExtension];
}

#pragma mark - UIAlertViewDelegate

/*!
 * Sent to the delegate when the user clicks a button on an alert view.
 *
 * @param alertView			The alert view containing the button.
 * @param buttonIndex		The index of the button that was clicked. The button indices start at 0.
 */

- (void) alertView: (UIAlertView *) alertView clickedButtonAtIndex: (NSInteger) buttonIndex {
    self.viewingAlert = NO;
}

#pragma mark - LoaderDelegate

/*!
 * Called when the loader has completed loading the binary.
 *
 * The loader is now in a dormant state, waiting for a new load.
 *
 * This method is always called from the main thread.
 */

- (void) loaderComplete {
    [progressView setHidden: YES];
    [self resetLoadButton];
}

/*!
 * Called when the loader is sending bytes from the binary image to the XBee, this allows the UI to report
 * progress to the user.
 *
 * @param progress		The progress. The range is 0.0 (starting) to 1.0 (complete).
 */

- (void) loaderProgress: (float) progress {
    if (progressView.isHidden)
	    [progressView setHidden: NO];
    progressView.progress = progress;
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
 * This method is always called from the main thread.
 *
 * @param error			The error.
 */

- (void) loaderFatalError: (NSError *) error {
    [progressView setHidden: YES];
    [self reportError: error];
}

/*!
 * Called when the internal status of the loader changes, this method supplies a status string suitable for
 * display in a UI to provide textual progress information.
 *
 * This method is always called from the main thread.
 *
 * @param status		The test message indicating the status.
 */

- (void) loaderState: (NSString *) message {
    statusLabel.text = message;
}

@end
