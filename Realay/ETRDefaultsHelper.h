//
//  ETRPreferenceHelper.h
//  Realay
//
//  Created by Michel on 15/03/15.
//  Copyright (c) 2015 Easy Target. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CLLocation;
@class ETRRoom;


@interface ETRDefaultsHelper : NSObject

#pragma mark -
#pragma mark General

+ (BOOL)didRunOnce;

+ (NSNumber *)localUserID;

+ (void)storeLocalUserID:(NSNumber *)remoteID;

+ (NSString *)authID;

#pragma mark -
#pragma mark Settings

+ (BOOL)doUseMetricSystem;

#pragma mark -
#pragma mark Location & Room Updates

+ (BOOL)doUpdateRoomListAtLocation:(CLLocation *)location;

+ (void)acknowledgeRoomListUpdateAtLocation:(CLLocation *)location;

+ (CLLocation *)lastUpdateLocation;

#pragma mark -
#pragma mark Session Persistence

+ (ETRRoom *)restoreSession;

+ (void)storeSession:(NSNumber *)sessionID;

+ (void)removeSession;

+ (NSString *)messageInputTextForConversationID:(NSNumber *)conversationID;

+ (void)storeMessageInputText:(NSString *)inputText forConversationID:(NSNumber *)conversationID;

+ (void)removePublicMessageInputTexts;

@end
