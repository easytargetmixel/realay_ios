//
//  ETRInsideRoomHandler.m
//  Realay
//
//  Created by Michel S on 02.03.14.
//  Copyright (c) 2014 Michel Sievers. All rights reserved.
//

#import "ETRSessionManager.h"

#import "ETRAction.h"
#import "ETRActionManager.h"
#import "ETRAlertViewFactory.h"
#import "ETRCoreDataHelper.h"
#import "ETRLocalUserManager.h"
#import "ETRLocationManager.h"
#import "ETRRoom.h"
#import "ETRServerAPIHelper.h"

#define kTickInterval           3

#define kFontSizeMsgSender      15
#define kFontSizeMsgText        15

#define kTimeReturnKick         10
#define kTimeReturnWarning1     5
#define kTimeReturnWarning2     8

#define kUserDefNotifPrivate    @"userDefaultsNotifcationPrivate"
#define kUserDefNotifPublic     @"userDefaultsNotificationPublic"
#define kUserDefNotifOther      @"userDefaultsNotificationOther"

static ETRSessionManager *sharedInstance = nil;

@implementation ETRSessionManager {
    UINavigationController  *_navCon;               // Navigation Controller for quit-pops
}

#pragma mark - Singleton Sharing

+ (void)initialize {
    static BOOL initialized = NO;
    if (!initialized) {
        initialized = YES;
        sharedInstance = [[ETRSessionManager alloc] init];
    }
}

+ (ETRSessionManager *)sharedManager {
    return sharedInstance;
}

+ (ETRRoom *)sessionRoom {
    return [sharedInstance room];
}

- (void)didReceiveMemoryWarning {
    //TODO: Implementation
}

#pragma mark - Session State

- (BOOL)startSession {
    //TODO: Handle errors
    if (![self room]) {
        NSLog(@"ERROR: No room object given before starting a session.");
        return NO;
    }
    
    if ([_room endDate]) {
        if ([[_room endDate] compare:[NSDate date]] != 1) {
            NSLog(@"ERROR: Room was already closed.");
            //TODO: Display error message.
            return NO;
        }
    }
    
    // Consider the join successful so far and start the Action Manager.
    [[ETRActionManager sharedManager] startSession];
    _didBeginSession = YES;
    return YES;
}

- (void)endSession {
    _didBeginSession = NO;
    [[self navigationController] popToRootViewControllerAnimated:YES];
    
    //TODO: update_user_in_room.php

    // Remove all public Actions from the local DB.
    [ETRCoreDataHelper clearPublicActions];
}

- (void)prepareSessionInRoom:(ETRRoom *)room
        navigationController:(UINavigationController *)navigationController {
    
    [self setNavigationController:navigationController];
    
    if ([self didBeginSession]) {
        [self endSession];
        NSLog(@"ERROR: Room set during running session.");
        return;
    }
    
    // TODO: Only query user ID here?
    _room = room;
    
    // Adjust the location manager for a higher accuracy.
    // TODO: Increase location update speed?
}

@end
