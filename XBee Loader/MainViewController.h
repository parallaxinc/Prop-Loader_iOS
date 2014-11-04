//
//  MainViewController.h
//  Prop Loader
//
//  Created by Mike Westerfield on 2/10/14 at the Byte Works, Inc.
//  Copyright (c) 2014 Parallax. All rights reserved.
//

#import <UIKit/UIKit.h>

#include "Loader.h"

@interface MainViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate, UIAlertViewDelegate, LoaderDelegate>

@property (nonatomic, retain) IBOutlet UISwitch *epromSwitch;
@property (nonatomic, retain) IBOutlet UILabel *ipAddressLabel;
@property (nonatomic, retain) IBOutlet UIButton *loadButton;
@property (nonatomic, retain) IBOutlet UILabel *nameLabel;
@property (nonatomic, retain) IBOutlet UIProgressView *progressView;
@property (nonatomic, retain) IBOutlet UILabel *statusLabel;

- (IBAction) loadButton: (id) sender;

@end
