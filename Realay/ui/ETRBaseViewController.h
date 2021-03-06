//
//  ETRBaseViewController.h
//  Realay
//
//  Created by Michel on 11/05/15.
//  Copyright (c) 2015 Easy Target. All rights reserved.
//

#import <UIKit/UIKit.h>


@class ETRAlertViewFactory;


static CFAbsoluteTime LastSettingsAlert = 0.0;


@interface ETRBaseViewController : UIViewController

@property (strong, nonatomic) ETRAlertViewFactory * alertHelper;

- (void)pushToPublicConversationViewController;

- (void)pushToJoinViewController;

- (void)setPrivateMessagesBadgeNumber:(unsigned short)number
                              inLabel:(UILabel *)label
                       animateFromTop:(BOOL)doAnimateFromTop;

@end
