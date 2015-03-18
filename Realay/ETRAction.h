//
//  Action.h
//  Realay
//
//  Created by Michel on 01/03/15.
//  Copyright (c) 2015 Easy Target. All rights reserved.
//

#import "ETRChatObject.h"

@class ETRConversation, ETRRoom, ETRUser;


typedef NS_ENUM(short, ETRActionCode) {
    ETRActionCodePublicMessage  = 10,
    ETRActionCodePrivateMessage = 11,
    ETRActionCodePublicMedia    = 40,
    ETRActionCodePrivateMedia   = 41
};


@interface ETRAction : ETRChatObject

@property (nonatomic, retain) NSNumber * code;
@property (nonatomic, retain) NSNumber * isInQueue;
@property (nonatomic, retain) NSString * messageContent;
@property (nonatomic, retain) NSNumber * remoteID;
@property (nonatomic, retain) NSDate * sentDate;
@property (nonatomic, retain) ETRUser *recipient;
@property (nonatomic, retain) ETRRoom *room;
@property (nonatomic, retain) ETRUser *sender;
@property (nonatomic, retain) ETRConversation *conversation;

//- (CGSize)frameSizeForWidth:(CGFloat)width hasNameLabel:(BOOL)hasNameLabel;
//- (CGFloat)rowHeightForWidth:(CGFloat)width hasNameLabel:(BOOL)hasNameLabel;

- (BOOL)isPublicMessage;

- (BOOL)isValidMessage;

- (BOOL)isPhotoMessage;

- (BOOL)isSentAction;

@end
