//
//  ETRBaseViewController.m
//  Realay
//
//  Created by Michel on 11/05/15.
//  Copyright (c) 2015 Easy Target. All rights reserved.
//

#import "ETRBaseViewController.h"

#import "ETRAnimator.h"
#import "ETRAlertViewFactory.h"
#import "ETRConversationViewController.h"
#import "ETRJoinViewController.h"
#import "ETRLocationManager.h"
#import "ETRSessionManager.h"
#import "ETRUIConstants.h"

static CFAbsoluteTime LastSettingsAlert = 0.0;

static CFTimeInterval ETRIntervalSettingsWarnings = 60.0;


@interface ETRBaseViewController ()

@property (strong, nonatomic) ETRAlertViewFactory * alertViews;

@end


@implementation ETRBaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[ETRSessionManager sharedManager] setNavigationController:[self navigationController]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self updateAlertViews];
}

- (UIStatusBarStyle) preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)updateAlertViews {
    // TODO: Check Bouncer for AlertViews first.
    // Other dialogs will not be displayed if a kick or warning is to be shown.
    
    if (!_alertViews) {
        _alertViews = [[ETRAlertViewFactory alloc] init];
    }
    
    if ([[ETRLocationManager sharedManager] didAuthorize]) {
        UIAlertView * settingsAlert = [_alertViews existingSettingsAlert];
        if (settingsAlert) {
            [settingsAlert dismissWithClickedButtonIndex:-1 animated:YES];
            LastSettingsAlert = CFAbsoluteTimeGetCurrent();
        }
    } else {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        
        if (now - LastSettingsAlert > ETRIntervalSettingsWarnings) {
            [_alertViews showSettingsAlert];
            LastSettingsAlert = now;
        }
    }
}

- (void)pushToPublicConversationViewController {
    UIStoryboard * storyboard = [self storyboard];
    ETRConversationViewController * conversationController;
    conversationController = [storyboard instantiateViewControllerWithIdentifier:ETRViewControllerIDConversation];
    [conversationController setIsPublic:YES];
    
    [[self navigationController] pushViewController:conversationController animated:YES];
}

- (void)pushToJoinViewController {
    UIStoryboard * storyboard = [self storyboard];
    ETRJoinViewController * viewController;
    viewController = [storyboard instantiateViewControllerWithIdentifier:ETRViewControllerIDJoin];
    
    [[self navigationController] pushViewController:viewController animated:YES];
}

- (void)setPrivateMessagesBadgeNumber:(NSInteger )number
                              inLabel:(UILabel *)label
                       animateFromTop:(BOOL)doAnimateFromTop {
    
    //    NSString * privateChats = NSLocalizedString(@"Private_Chats", @"Private Conversations");
    //    NSString * title;
    
    if (number < 1) {
        [ETRAnimator fadeView:label doAppear:NO];
    } else {
        NSString * displayValue;
        if (number <= 100)  {
            displayValue = [NSString stringWithFormat:@"%ld", number];
        } else {
            displayValue = @"100+";
        }
        
        if (![displayValue isEqualToString:[label text]]) {
            // Force the animation if the content of the badge changes.
            [label setHidden:YES];
        }
        
        [label setText:displayValue];
        
        //        [ETRAnimator fadeView:[self unreadCounterLabel] doAppear:YES];
        
        if ([label isHidden]) {
            [ETRAnimator toggleBounceInView:label
                             animateFromTop:doAnimateFromTop
                                 completion:^{
                CGFloat cornerRadius = label.frame.size.width * 0.5f;
                [[label layer] setCornerRadius:cornerRadius];
            }];
        }
    }
    
    //        [[[self viewControllers] objectAtIndex:1] setTitle:title];
    //    [[[self tabBar] layer] setNeedsDisplay];
}

@end



