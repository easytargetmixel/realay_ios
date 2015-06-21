//
//  ETRBouncer.m
//  Realay
//
//  Created by Michel on 11/05/15.
//  Copyright (c) 2015 Easy Target. All rights reserved.
//

#import "ETRBouncer.h"

#import "ETRMapViewController.h"
#import "ETRReadabilityHelper.h"
#import "ETRRoom.h"
#import "ETRSessionManager.h"
#import "ETRUIConstants.h"


static ETRBouncer * sharedInstance = nil;

static NSTimeInterval const ETRTimeIntervalFiveMinutes = 5.0 * 60.0;

static NSTimeInterval const ETRTimeIntervalTenMinutes = 10.0 * 60.0;


@interface ETRBouncer () <UIAlertViewDelegate>

@property (strong, nonatomic) UIViewController * viewController;

@property (nonatomic) BOOL hasPendingKick;

@property (nonatomic) BOOL hasPendingAlertView;

@property (strong, nonatomic) NSTimer * warnTimer;

@property (nonatomic) short numberOfWarnings;

@property (nonatomic) NSInteger lastReason;

@property (strong, nonatomic) NSString * sessionEnd;

@end


@implementation ETRBouncer

#pragma mark -
#pragma mark Singleton Instantiation

+ (void)initialize {
    if (!sharedInstance) {
        sharedInstance = [[ETRBouncer alloc] init];
    }
}

+ (ETRBouncer *)sharedManager {
    return sharedInstance;
}

#pragma mark -
#pragma mark Runtime Constants

+ (NSArray *)locationWarningIntervals {
    return [NSArray arrayWithObjects:
            @(60.0),
            @(60.0),
            @(60.0),
            @(60.0),
            nil];
    
//    return [NSArray arrayWithObjects:
//            @(ETRTimeIntervalTenMinutes),
//            @(ETRTimeIntervalTenMinutes),
//            @(ETRTimeIntervalFiveMinutes),
//            @(ETRTimeIntervalFiveMinutes),
//            nil];
}

#pragma mark -
#pragma mark Session Lifecycle

- (void)resetSession {
    [_warnTimer invalidate];
    _numberOfWarnings = 0;
    _hasPendingKick = NO;
}

- (BOOL)showPendingAlertViewsInViewController:(UIViewController *)viewController {
    _viewController = viewController;
    if (_hasPendingAlertView) {
        [self showPendingAlert];
        return YES;
    } else {
        return NO;
    }
}

- (void)didEnterBackground {
    _viewController = nil;
}

- (void)warnForReason:(short)reason {
    if (![[ETRSessionManager sharedManager] didBeginSession]) {
        return;
    }
    
    NSArray * intervals = [ETRBouncer locationWarningIntervals];
    
    _lastReason = reason;
    
    if (_numberOfWarnings < [intervals count]) {
#ifdef DEBUG
        NSLog(@"Bouncer warning: %d/4 - %d.", _numberOfWarnings, reason);
#endif
        
        [self notifyUser];
        
        NSTimeInterval interval;
        interval = [[intervals objectAtIndex:_numberOfWarnings] doubleValue];
        _warnTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                         target:self
                                       selector:@selector(triggerNextWarning:)
                                       userInfo:nil
                                        repeats:NO];
    } else {
        [self kickForReason:reason calledBy:@"Warning Limit reached."];
    }
    _numberOfWarnings++;
}

- (void)kickForReason:(short)reason calledBy:(NSString *)caller {
#ifdef DEBUG
    NSLog(@"Kicking. Reason: %d, Caller: %@", reason, caller);
#endif
    
    _hasPendingKick = YES;
    _lastReason = reason;

    ETRRoom * lastRoom = [ETRSessionManager sessionRoom];
    [[ETRSessionManager sharedManager] endSession];
    [[ETRSessionManager sharedManager] prepareSessionInRoom:lastRoom
                                       navigationController:[_viewController navigationController]];
    [self notifyUser];
}

- (void)cancelLocationWarnings {
    if (_lastReason == ETRKickReasonLocation) {
        [self resetSession];
    }
}

- (void)triggerNextWarning:(NSTimer *)timer {
    [self warnForReason:_lastReason];
}

#pragma mark -
#pragma mark Notificiations & AlertViews

- (void)notifyUser {    
    if (_viewController) {
        [self showPendingAlert];
    } else {
        _hasPendingAlertView = YES;
//        [self showNotification];
    }
}

- (void)showPendingAlert {
    NSString * title;
    NSString * message;
    NSString * firstButton;
    NSString * secondButton;
    
    if (_hasPendingKick) {
        title = NSLocalizedString(@"Session_Terminated", @"Kicked");
    }
    
    switch (_lastReason) {
        case ETRKickReasonLocation:
            if (_hasPendingKick) {
                message = NSLocalizedString(@"Stay_in_area", @"Do not leave radius.");
            } else {
                title = NSLocalizedString(@"Where_Are_You", @"Location Note");

                NSString * messageFormat;
                messageFormat = NSLocalizedString(@"Return_until", @"Come back until %@");
                message = [NSString stringWithFormat:messageFormat, [self kickTime]];
                
                firstButton = NSLocalizedString(@"Map", @"Session Map");
                secondButton = NSLocalizedString(@"Location_Settings", @"Preferences");
            }
            break;
            
        case ETRKickReasonClosed:
            if (_hasPendingKick) {
                message = NSLocalizedString(@"Event_ended", @"Closing hour reached");
            } else {
                NSString * messageFormat;
                messageFormat = NSLocalizedString(@"Part_of_event", @"Event ended at %@. Stay until %@");
                message = [NSString stringWithFormat:messageFormat, [self sessionEnd], [self kickTime]];
            }
            break;
            
        case ETRKickReasonTimeout:
            message = NSLocalizedString(@"Timeout_occurred", @"Connection timeout");
            break;
        
        case ETRKickReasonDataOff:
            title = NSLocalizedString(@"Something_wrong", @"Error happened");
            message = NSLocalizedString(@"Sorry", @"");
            break;
            
        case ETRKickReasonKick:
            message = NSLocalizedString(@"Requested_to_leave", @"You got kicked");
            break;
            
        default:
            return;
    }

    UIAlertView * alert;
    alert = [[UIAlertView alloc] initWithTitle:title
                                       message:message
                                      delegate:self
                             cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
                             otherButtonTitles:firstButton, secondButton, nil];
    [alert setTag:_lastReason];
    [alert show];
    _hasPendingAlertView = NO;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if (buttonIndex == 0) {
        return;
    }
    
    switch ([alertView tag]) {
        case ETRKickReasonLocation:
            if (buttonIndex == 1) {
                // Map button:
                if (_viewController) {
                    UIStoryboard * storyBoard = [_viewController storyboard];
                    ETRMapViewController * conversationViewController;
                    conversationViewController = [storyBoard instantiateViewControllerWithIdentifier:ETRViewControllerIDMap];
                    [[_viewController navigationController] pushViewController:conversationViewController
                                                                      animated:YES];
                }
                
                
            } else {
                // Settings button:
                NSString * settingsURL = UIApplicationOpenSettingsURLString;
                if (settingsURL) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:settingsURL]];
                }
            }
    }
}

#pragma mark -
#pragma mark Date Helper

/**
 * Uses the warning intervals to calculate when the final warning will be displayed
 * and stores the value as a readable HH:MM string
 */
- (NSString *)kickTime {
    CFTimeInterval warningIntervalSum = 0.0;
    for (NSNumber * interval in [ETRBouncer locationWarningIntervals]) {
        warningIntervalSum += [interval doubleValue];
    }
    
    CFAbsoluteTime kickTime = CFAbsoluteTimeGetCurrent() + warningIntervalSum;
    return [ETRReadabilityHelper formattedDate:[NSDate dateWithTimeIntervalSinceReferenceDate:kickTime]];
}

/**
 
 */
- (NSString *)sessionEnd {
    ETRRoom * sessionRoom = [ETRSessionManager sessionRoom];
    if ([sessionRoom endDate]) {
        return [ETRReadabilityHelper formattedDate:[sessionRoom endDate]];
    } else {
        return @"-";
    }
}

@end
