//
//  Room.h
//  Realay
//
//  Created by Michel on 01/03/15.
//  Copyright (c) 2015 Easy Target. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

#import "ETRChatObject.h"

@class ETRUser;

@interface ETRRoom : ETRChatObject

@property (nonatomic, retain) NSString * address;

@property (nonatomic, retain) NSString * createdBy;

@property (nonatomic, retain) NSDate * endDate;

@property (nonatomic, retain) NSNumber * latitude;

@property (nonatomic, retain) NSNumber * longitude;

@property (nonatomic, retain, readonly) CLLocation * location;

@property (nonatomic, retain) NSString * password;

@property (nonatomic, retain) NSNumber * queryDistance;

@property (nonatomic, retain) NSNumber * radius;

@property (nonatomic, retain) NSDate * startTime;

@property (nonatomic, retain) NSString * summary;

@property (nonatomic, retain) NSString * title;

@property (nonatomic, retain) NSNumber * queryUserCount;

@property (nonatomic, retain) NSSet *users;

@property (nonatomic, retain) NSManagedObject *actions;

- (NSString *)description;

- (NSString *)timeSpan;

- (NSString *)formattedCoordinates;

- (NSString *)formattedSize;

- (NSString *)userCount;

/*
 Distance in _metres_ between the outer _radius_ of a given Room, not the central point,
 and the current device location;
 Takes current device location from the LocationManager;
 Uses the server API / query distance value, if the device location is unknown;
 Values below 10 are handled as 0 to avoid unnecessary precision
 */
- (NSInteger)distance;

- (NSString *)formattedDistance;

@end

@interface ETRRoom (CoreDataGeneratedAccessors)

- (void)addUsersObject:(ETRUser *)value;
- (void)removeUsersObject:(ETRUser *)value;
- (void)addUsers:(NSSet *)values;
- (void)removeUsers:(NSSet *)values;

@end
