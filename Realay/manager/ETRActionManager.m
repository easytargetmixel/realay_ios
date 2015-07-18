//
//  ETRActionManager.m
//  Realay
//
//  Created by Michel on 11/03/15.
//  Copyright (c) 2015 Easy Target. All rights reserved.
//

#import "ETRActionManager.h"

#import "ETRAction.h"
#import "ETRCoreDataHelper.h"
#import "ETRDefaultsHelper.h"
#import "ETRNotificationManager.h"
#import "ETRRoom.h"
#import "ETRServerAPIHelper.h"
#import "ETRSessionManager.h"
#import "ETRUser.h"
#import "ETRUserListViewController.h"


static ETRActionManager * sharedInstance = nil;

static CFTimeInterval const ETRQueryIntervalFastest = 1.5;

static CFTimeInterval const ETRQueryIntervalMaxJitter = 1.2;

static CFTimeInterval const ETRQueryIntervalSlowest = 8.0;

static CFTimeInterval const ETRQueryIntervalIdle = 45.0;

static CFTimeInterval const ETRWaitIntervalToIdleQueries = 4.0 * 60.0;

static CFTimeInterval const ETRPingInterval = 20.0;




@interface ETRActionManager ()

@property (strong, nonatomic) NSTimer * timer;

/**
 Last ID of received actions
 */
@property (nonatomic) long lastActionID;

/*
 
 */
@property (nonatomic) CFTimeInterval queryInterval;

/*
 
 */
@property (strong, nonatomic) UINavigationController * navCon;               // Navigation Controller for quit-pops

/*
 
 */
@property (nonatomic) CFAbsoluteTime lastActionTime;

/*
 
 */
@property (nonatomic) CFAbsoluteTime lastPingTime;


/*
 
 */
@property (strong, nonatomic) NSMutableDictionary * notificationCounters;

@property (strong, nonatomic) NSMutableArray * privateMessageNotificationQuery;

@property (strong, nonatomic) NSMutableArray * publicMessageNotificationQuery;

@property (strong, nonatomic) UILocalNotification * lastPrivateMessageNotification;

@property (strong, nonatomic) UILocalNotification * lastPublicMessageNotification;

@end


@implementation ETRActionManager

#pragma mark -
#pragma mark Singleton Instantiation

+ (void)initialize {
    static BOOL initialized = NO;
    if (!initialized) {
        initialized = YES;
        sharedInstance = [[ETRActionManager alloc] init];
    }
}

+ (ETRActionManager *)sharedManager {
    return sharedInstance;
}

#pragma mark -
#pragma mark Session Life Cycle

- (void)startSession {
    // Consider the join successful and start the query timer.
    _lastActionTime = CFAbsoluteTimeGetCurrent();
//    _queryInterval = ETRQueryIntervalFastest;
    [self cancelAllNotifications];

    [self dispatchQueryTimerWithResetInterval:YES];
    
    return;
}

- (void)endSession {
    _lastActionID = 0L;
    [self cancelAllNotifications];
}

- (void)didEnterBackground {
    [_timer invalidate];
}

- (void)dispatchQueryTimerWithResetInterval:(BOOL)doResetInterval {
    UIApplicationState applicationState = [[UIApplication sharedApplication] applicationState];
    if (applicationState == UIApplicationStateBackground) {
        return;
    }
    
    if (doResetInterval || _queryInterval < ETRQueryIntervalFastest) {
        _queryInterval = ETRQueryIntervalFastest;
        _lastActionTime = CFAbsoluteTimeGetCurrent();
#ifdef DEBUG
        NSLog(@"New query Timer interval: %g", _queryInterval);
#endif
    } else if (_queryInterval > ETRQueryIntervalSlowest) {
        if (CFAbsoluteTimeGetCurrent() - _lastActionTime > ETRWaitIntervalToIdleQueries) {
            _queryInterval = ETRQueryIntervalIdle;
#ifdef DEBUG
            NSLog(@"New query Timer interval: %g", _queryInterval);
#endif
        }
    } else {
        CFTimeInterval random = drand48();
        _queryInterval += random * ETRQueryIntervalMaxJitter;
#ifdef DEBUG
        NSLog(@"New query Timer interval: %g", _queryInterval);
#endif
    }
    
    dispatch_async(
                   dispatch_get_main_queue(),
                   ^{
                       _timer = [NSTimer scheduledTimerWithTimeInterval:_queryInterval
                                                        target:self
                                                      selector:@selector(fetchUpdates:)
                                                      userInfo:nil
                                                       repeats:NO];
                   });
}

- (void)fetchUpdates:(NSTimer *)timer {
    UIApplicationState applicationState = [[UIApplication sharedApplication] applicationState];
    if (applicationState != UIApplicationStateActive) {
        // Ignore the timer if the app is not active.
        // Background Fetches will load new data.
#ifdef DEBUG
        NSLog(@"fetchUpdates: ignored because the app is not active.");
#endif
        return;
    } else if (![[ETRSessionManager sharedManager] didStartSession]) {
#ifdef DEBUG
        NSLog(@"fetchUpdates: called outside of Session.");
#endif
        return;
    }
    
    [self fetchUpdatesWithCompletionHandler:nil];
}

/**
 Check didStartSession == YES before calling this.
*/
- (void)fetchUpdatesWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    BOOL isInitial = _lastActionID < 100L;
    BOOL doSendPing = [self doSendPing];
    
    [ETRServerAPIHelper getActionsAndPing:doSendPing
                               completion:^(id<NSObject> receivedObject) {
                                   BOOL didReceiveNewData = NO;
                                   
                                   int new = -1;
                                   
                                   if ([receivedObject isKindOfClass:[NSArray class]]) {
                                       NSArray * jsonActions = (NSArray *) receivedObject;
                                       new++;
                                       for (NSObject *jsonAction in jsonActions) {
                                           if ([jsonAction isKindOfClass:[NSDictionary class]]) {
                                               new++;
                                               ETRAction * action;
                                               action = [ETRCoreDataHelper addActionFromJSONDictionary:(NSDictionary *)jsonAction];
                                               if (action && !isInitial) {
                                                   [self queryNotificationForAction:action];
                                               }
                                               didReceiveNewData = YES;
                                           }
                                       }
                                       
                                       if (!isInitial && new > 0) {
                                           // All Actions have been processed. Show those bundled Notifications.
                                           [self presentQueuedNotifications];
                                       }
                                   }
                                   
#ifdef DEBUG
                                   NSLog(@"New: %d", new);
#endif
                                   
                                   [self dispatchQueryTimerWithResetInterval:didReceiveNewData];
                                   
                                   if (doSendPing) {
                                       _lastPingTime = CFAbsoluteTimeGetCurrent();
                                   }
                                   
                                   if (completionHandler) {
                                       completionHandler(UIBackgroundFetchResultNewData);
                                   }
                               }];
}

- (BOOL)doSendPing {
    return CFAbsoluteTimeGetCurrent() - _lastPingTime > ETRPingInterval;
}

- (void)ackknowledgeActionID:(long)remoteActionID {
    if (_lastActionID < remoteActionID) {
        _lastActionID = remoteActionID;
    }
    _lastActionTime = CFAbsoluteTimeGetCurrent();
}

- (void)setForegroundPartnerID:(NSNumber *)foregroundPartnerID {
    _foregroundPartnerID = foregroundPartnerID;
    
    long idValue = [foregroundPartnerID longValue];
    if (idValue > 10L) {
        // A Private Conversation has been opened.
        // Cancel its Notifications and reset its unread message count.
        
        [_notificationCounters removeObjectForKey:foregroundPartnerID];
        if (_internalNotificationHandler) {
            dispatch_async(
                           dispatch_get_main_queue(),
                           ^{
                               [_internalNotificationHandler setPrivateMessagesBadgeNumber:[_privateMessageNotificationQuery count]];
                           });
        }
        [self updateBadges];
    } else if (idValue == ETRActionPublicUserID) {
        // The Public Conversation has been opened.
        // Cancel all other Notifications.
        
        [_notificationCounters removeObjectForKey:@(ETRActionPublicUserID)];
        [self updateBadges];
    }
}

#pragma mark -
#pragma mark Notifications

- (void)setInternalNotificationHandler:(id<ETRInternalNotificationHandler>)internalNotificationHandler {
    _internalNotificationHandler = internalNotificationHandler;
    [self updateBadges];
//    if (_internalNotificationHandler) {
//        dispatch_async(
//                       dispatch_get_main_queue(),
//                       ^{
//                           [_internalNotificationHandler setPrivateMessagesBadgeNumber:[self numberOfPrivateNotifs]];
//                       });
//    }
}

- (void)queryNotificationForAction:(ETRAction *)action {
    if (!action) {
        return;
    }
    
    BOOL isMessage = [action isValidMessage] || [action isPhotoMessage];
    if ([action isSentAction] || !isMessage) {
        return;
    }
    
    // Count the number of unread messages.
    // Even if actual Notifications are disabled,
    // this is needed for in-app counters.
    
    if (!_notificationCounters) {
        _notificationCounters = [NSMutableDictionary dictionary];
    }
    
    BOOL isPublicAction = [action isPublicAction];
    
    NSNumber * conversationID;
    if (isPublicAction) {
        conversationID = @(ETRActionPublicUserID);
    } else {
        conversationID = [[action sender] remoteID];
    }
    
    UIApplicationState applicationState = [[UIApplication sharedApplication] applicationState];
    if (applicationState == UIApplicationStateActive) {
        if ([_foregroundPartnerID isEqualToNumber:conversationID]) {
            // Do not create Notifications if the Conversation is in the foreground.
            return;
        }
    }
    
    // Place the Action in the appropriate Queue Array.
    if ([action isPrivateMessage]) {
        if (!_privateMessageNotificationQuery) {
            _privateMessageNotificationQuery = [NSMutableArray array];
        }
        [_privateMessageNotificationQuery addObject:action];
    } else if ([action isPublicMessage]) {
        // Only queue up Public Messages if the Settings say so.
        if (!_publicMessageNotificationQuery) {
            _publicMessageNotificationQuery = [NSMutableArray array];
        }
        [_publicMessageNotificationQuery addObject:action];
    }
}

- (void)presentQueuedNotifications {
    // Update the App Badge and in turn the Notification settings
    // before showing the desired and appropriate information.
    [self updateBadges];
    if (![[ETRNotificationManager sharedManager] didAllowAlerts]) {
        return;
    }
    
    // Private Messages Notification:
    
    NSInteger privateMessageCount = [_privateMessageNotificationQuery count];
    if (privateMessageCount) {
        if (_lastPrivateMessageNotification) {
            [[UIApplication sharedApplication] cancelLocalNotification:_lastPrivateMessageNotification];
        }
        
        UILocalNotification * privateMsgNotification = [[UILocalNotification alloc] init];
        NSString * title;
        NSString * body;
        if (privateMessageCount > 1) {
            title = [[[ETRSessionManager sharedManager] room] title];
            NSString * privateMessagesFormat = NSLocalizedString(@"private_messages", @"%d private msgs");
            body = [NSString stringWithFormat:privateMessagesFormat, privateMessageCount];
            
        } else {
            title = NSLocalizedString(@"Private_Message", @"Private Message");
            ETRAction * action = [_privateMessageNotificationQuery objectAtIndex:0];
            body = [NSString stringWithFormat:@"%@:\n%@", [[action sender] name], [action readableMessageContent]];
        }
        
        [privateMsgNotification setAlertTitle:title];
        [privateMsgNotification setAlertBody:body];

        [[ETRNotificationManager sharedManager] addSoundToNotification:privateMsgNotification];
        [[UIApplication sharedApplication] presentLocalNotificationNow:privateMsgNotification];
        _lastPrivateMessageNotification = privateMsgNotification;
    }
    
    // Public Messages Notification:
    if (![ETRDefaultsHelper doShowPublicNotifs]) {
        _publicMessageNotificationQuery = nil;
        return;
    }
    
    NSInteger publicMessageCount = [_publicMessageNotificationQuery count];
    if (publicMessageCount) {
        if (_lastPublicMessageNotification) {
            [[UIApplication sharedApplication] cancelLocalNotification:_lastPublicMessageNotification];
        }
        
        UILocalNotification * publicMsgNotification = [[UILocalNotification alloc] init];
        NSString * title;
        NSString * body;
        if (publicMessageCount > 1) {
            title = [[[ETRSessionManager sharedManager] room] title];
            NSString * publicMessagesFormat = NSLocalizedString(@"public_messages", @"%d public msgs");
            body = [NSString stringWithFormat:publicMessagesFormat, publicMessageCount];
        } else {
            title = NSLocalizedString(@"Public_Message", @"Public Message");
            ETRAction * action = [_publicMessageNotificationQuery objectAtIndex:0];
            body = [NSString stringWithFormat:@"%@:\n%@", [[action sender] name], [action readableMessageContent]];
        }
        
        [publicMsgNotification setAlertTitle:title];
        [publicMsgNotification setAlertBody:body];
        [[UIApplication sharedApplication] presentLocalNotificationNow:publicMsgNotification];
        _lastPublicMessageNotification = publicMsgNotification;
    }

}

- (void)updateBadges {
    if (_internalNotificationHandler) {
        dispatch_async(
                       dispatch_get_main_queue(),
                       ^{
                           [_internalNotificationHandler setPrivateMessagesBadgeNumber:[_privateMessageNotificationQuery count]];
                       });
    }
    
    [[ETRNotificationManager sharedManager] updateAllowedNotificationTypes];
    if ([[ETRNotificationManager sharedManager] didAllowBadges]) {
        NSInteger number = [_privateMessageNotificationQuery count] + [self numberOfOtherNotifs];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:number];
    }
}

- (NSInteger)numberOfOtherNotifs {
    // TODO: Implement "other" Actions.
    return 0;
}

- (void)cancelAllNotifications {
    _privateMessageNotificationQuery = nil;
    _publicMessageNotificationQuery = nil;
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
}

@end
