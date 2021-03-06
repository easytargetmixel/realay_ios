//
//  ETRLocationManager.h
//  Realay
//
//  Created by Michel S on 05.05.14.
//  Copyright (c) 2014 Easy Target. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>


@class ETRRoom;


@interface ETRLocationManager : CLLocationManager <CLLocationManagerDelegate>

+ (ETRLocationManager *)sharedManager;

- (void)launch:(NSTimer *)timer;

+ (CLLocation *)location;

+ (BOOL)isInSessionRegionWithIntervalCheck:(BOOL)doCheckInterval;

- (int)distanceToRoom:(ETRRoom *)room;

+ (BOOL)didAuthorizeAlways;

+ (BOOL)didAuthorizeWhenInUse;

@end
