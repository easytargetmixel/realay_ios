//
//  ETRDbHandler.h
//  Realay
//
//  Created by Michel S on 18.02.14.
//  Copyright (c) 2014 Michel Sievers. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ETRAction;
@class ETRRoom;
@class ETRUser;
@class ETRImageLoader;

@interface ETRServerAPIHelper : NSObject

// Queries the list of rooms that are inside a given distance radius.
+ (void)updateRoomListWithCompletionHandler:(void(^)(BOOL didReceive))completionHandler;

+ (void)getImageForLoader:(ETRImageLoader *)imageLoader doLoadHiRes:(BOOL)doLoadHiRes;

/*
 Registers a new User at the database or retrieves the data
 that matches the combination of the given name and device ID;
 stores the new User object through the Local User Manager when finished
 */
+ (void)loginUserWithName:(NSString *)name completionHandler:(void(^)(ETRUser *))onSuccessBlock;

- (void)joinRoom:(ETRRoom *)room
showProgressInLabel:(UILabel *)label
    progressView:(UIProgressView *)progressView
completionHandler:(void(^)(BOOL didSucceed))completionHandler;

+ (void)getUserListInRoom:(ETRRoom *)room;

+ (void)getUserWithID:(long)remoteID;

+ (void)sendLocalUserUpdate;

+ (void)getActionsWithMinID:(long)lastActionID
          completionHandler:(void (^)(id<NSObject> receivedObject))completionHandler;

+ (void)putAction:(ETRAction *)outgoingAction;

+ (void)putImageWithHiResData:(NSData *)hiResData
                    loResData:(NSData *)loResData
            completionHandler:(void (^)(NSNumber * imageID))completionHandler;
@end
