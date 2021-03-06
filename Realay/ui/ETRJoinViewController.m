//
//  ETRJoinViewController.m
//  Realay
//
//  Created by Michel on 10/03/15.
//  Copyright (c) 2015 Easy Target. All rights reserved.
//

#import "ETRJoinViewController.h"

#import "ETRAlertViewFactory.h"
#import "ETRAnimator.h"
#import "ETRConversationViewController.h"
#import "ETRCoreDataHelper.h"
#import "ETRRoom.h"
#import "ETRUIConstants.h"
#import "ETRServerAPIHelper.h"
#import "ETRSessionManager.h"

static NSTimeInterval const ETRIntervalJoinDelayed = 15.0;


@interface ETRJoinViewController ()

//@property (strong, nonatomic) NSThread * joinThread;

@property (atomic) BOOL didFinish;

@property (atomic) BOOL isCanceled;

@property (nonatomic) NSTimer * delayTimer;

@end


@implementation ETRJoinViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ETRRoom * preparedRoom = [[ETRSessionManager sharedManager] room];
    if (!preparedRoom) {
        [[self navigationController] popToRootViewControllerAnimated:YES];
        NSLog(@"ERROR: No Room prepared in SessionManager. Cancelling join procedure.");
        return;
    }
        
    NSString * entering = [NSString stringWithFormat:@"%@...", [preparedRoom title]];
    [[self statusLabel] setText:entering];
    
    _isCanceled = NO;
    
    [ETRServerAPIHelper joinRoomAndShowProgressInLabel:_statusLabel
                                     completionHandler:^(BOOL didSucceed) {
                                         if (!_isCanceled) {
                                             [NSThread detachNewThreadSelector:@selector(handleJoinCompletion:)
                                                                      toTarget:self
                                                                    withObject:@(didSucceed)];
                                         }
                                     }];
    
    _delayTimer = [NSTimer scheduledTimerWithTimeInterval:ETRIntervalJoinDelayed
                                                   target:self
                                                 selector:@selector(handleDelay:)
                                                 userInfo:@(1)
                                                  repeats:NO];
}
     
-(void)handleDelay:(NSTimer *)timer {
    id userInfo = [timer userInfo];
    if (userInfo && [userInfo isKindOfClass:[NSNumber class]]) {
        NSNumber * timerID = (NSNumber *)userInfo;
        if ([timerID isEqualToValue:@(1)]) {
            // Notify user of connection delay and start timeout Timer.
            
            NSString * delayText = NSLocalizedString(@"Connecting_seems_longer", @"Slow connection");
            [[self statusLabel] setText:delayText];
            
            _delayTimer = [NSTimer scheduledTimerWithTimeInterval:ETRIntervalJoinDelayed
                                                           target:self
                                                         selector:@selector(handleDelay:)
                                                         userInfo:@(2)
                                                          repeats:NO];
            
        } else if ([timerID isEqualToValue:@(2)]) {
            // The process timed out.
            [[ETRSessionManager sharedManager] endSessionWithNotificaton:NO];
            [ETRAlertViewFactory showReachabilityAlert];
            [[self navigationController] popToRootViewControllerAnimated:YES];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _didFinish = NO;
    [[self activityIndicator] startAnimating];
    
    // Reset Bar elements that might have been changed during navigation to other View Controllers.
    [[self navigationController] setToolbarHidden:YES];
    [[[self navigationController] navigationBar] setTranslucent:YES];
    
    if ([[ETRSessionManager sharedManager] didStartSession]) {
        [self handleJoinCompletion:@(YES)];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [_delayTimer invalidate];
    _isCanceled = YES;
    
    if (!_didFinish) {
        [[self navigationController] popToRootViewControllerAnimated:YES];
    }
}

- (void)handleJoinCompletion:(NSNumber *)didSucceed {
    [_delayTimer invalidate];
    
    if (_isCanceled) {
        [[ETRSessionManager sharedManager] endSessionWithNotificaton:YES];
        return;
    }
    
    if ([didSucceed boolValue]) {
        [ETRAnimator fadeView:[self activityIndicator] doAppear:NO completion:nil];
        [ETRAnimator fadeView:[self statusLabel] doAppear:NO completion:nil];
        [ETRAnimator toggleBounceInView:[self logoView]
                         animateFromTop:NO
                             completion:^{
                                 if (_isCanceled) {
#ifdef DEBUG
                                     NSLog(@"Login animation completed while login was canceled."); 
#endif
                                     [[self navigationController] popToRootViewControllerAnimated:YES];
                                 } else {
                                     _didFinish = YES;
                                     [super pushToPublicConversationViewController];
                                 }
                             }];
    } else {
        NSLog(@"ERROR: handleJoinCompletion:NO");
        [ETRAlertViewFactory showReachabilityAlert];
        [[self navigationController] popToRootViewControllerAnimated:YES];
    }
}

@end
