//
//  ETRJSONCoreDataConnection.m
//  Realay
//
//  Created by Michel on 02/03/15.
//  Copyright (c) 2015 Easy Target. All rights reserved.
//

#import "ETRCoreDataHelper.h"

#import "ETRAction.h"
#import "ETRAppDelegate.h"
#import "ETRLocalUserManager.h"
#import "ETRRoom.h"
#import "ETRServerAPIHelper.h"
#import "ETRSessionManager.h"
#import "ETRUser.h"

long const ETRActionPublicUserID = -10;

static NSString *const ETRRemoteIDKey = @"remoteID";

static NSString *const ETRRoomDistanceKey = @"queryDistance";

static NSString *const ETRActionCodeKey = @"code";

static NSString *const ETRActionSenderKey = @"sender";

static NSString *const ETRActionRecipientKey = @"recipient";

static NSString *const ETRActionDateKey = @"sentDate";

static NSString *const ETRActionRoomKey = @"room";

static NSManagedObjectContext *ManagedObjectContext;

static NSEntityDescription *ActionEntity;

static NSString *ActionEntityName;

static NSEntityDescription *RoomEntity;

static NSString *RoomEntityName;

static NSEntityDescription *UserEntity;

static NSString *UserEntityName;

@implementation ETRCoreDataHelper

#pragma mark -
#pragma mark Accessories

+ (NSManagedObjectContext *)context {
    if (!ManagedObjectContext) {
        ETRAppDelegate *app = (ETRAppDelegate *) [[UIApplication sharedApplication] delegate];
        ManagedObjectContext = [app managedObjectContext];
    }
    return ManagedObjectContext;
}

+ (NSEntityDescription *)actionEntity {
    if (!ActionEntity) {
        ActionEntity = [NSEntityDescription entityForName:[ETRCoreDataHelper actionEntityName]
                                   inManagedObjectContext:[ETRCoreDataHelper context]];
    }
    return ActionEntity;
}

+ (NSString *)actionEntityName {
    if (!ActionEntityName) {
        ActionEntityName = NSStringFromClass([ETRAction class]);
    }
    return ActionEntityName;
}

+ (NSEntityDescription *)roomEntity {
    if (!RoomEntity) {
        RoomEntity = [NSEntityDescription entityForName:[ETRCoreDataHelper roomEntityName]
                                 inManagedObjectContext:[ETRCoreDataHelper context]];
    }
    return RoomEntity;
}

+ (NSString *)roomEntityName {
    if (!RoomEntityName) {
        RoomEntityName = NSStringFromClass([ETRRoom class]);
    }
    return RoomEntityName;
}

+ (NSEntityDescription *)userEntity {
    if (!UserEntity) {
        UserEntity = [NSEntityDescription entityForName:[ETRCoreDataHelper userEntityName]
                                 inManagedObjectContext:[ETRCoreDataHelper context]];
    }
    return UserEntity;
}

+ (NSString *)userEntityName {
    if (!UserEntityName) {
        UserEntityName = NSStringFromClass([ETRUser class]);
    }
    return UserEntityName;
}

+ (BOOL)saveContext {
    // Save Record.
    NSError *error;
    if (![[ETRCoreDataHelper context] save:&error] || error) {
        NSLog(@"ERROR: Could not save context: %@", error);
        return true;
    } else {
        return false;
    }
}

#pragma mark -
#pragma mark Rooms

+ (void)insertRoomFromDictionary:(NSDictionary *)JSONDict {
    
    // Get the remote DB ID from the JSON data.
    long remoteID = (long) [[JSONDict objectForKey:@"r"] longLongValue];
    
    // Check the context CoreData, if an object with this remote ID already exists.
    ETRRoom *room = [ETRCoreDataHelper roomWithRemoteID:remoteID];
    if (!room) {
        room = [[ETRRoom alloc] initWithEntity:[ETRCoreDataHelper roomEntity]
                insertIntoManagedObjectContext:[ETRCoreDataHelper context]];
        [room setRemoteID:@(remoteID)];
    }

    [room setImageID:@((long) [[JSONDict objectForKey:@"i"] longLongValue])];
    NSString *radius = (NSString *)[JSONDict objectForKey:@"rd"];
    [room setRadius:@((short) [radius integerValue])];
    NSString *userCount = (NSString *)[JSONDict objectForKey:@"ucn"];
    [room setQueryUserCount:@((short) [userCount integerValue])];
    
    [room setTitle:(NSString *)[JSONDict objectForKey:@"tt"]];
    [room setSummary:(NSString *)[JSONDict objectForKey:@"ds"]];
    [room setPassword:(NSString *)[JSONDict objectForKey:@"pw"]];
    if ([[JSONDict objectForKey:@"ad"] isMemberOfClass:[NSString class]]) {
        [room setAddress:(NSString *)[JSONDict objectForKey:@"ad"]];
    }
    
    NSInteger startTimestamp = [(NSString *)[JSONDict objectForKey:@"st"] integerValue];
    if (startTimestamp > 1000000000) {
        [room setStartTime:[NSDate dateWithTimeIntervalSince1970:startTimestamp]];
    }
    
    NSInteger endTimestamp = [(NSString *)[JSONDict objectForKey:@"et"] integerValue];
    if (endTimestamp > 1000000000) {
        [room setEndDate:[NSDate dateWithTimeIntervalSince1970:startTimestamp]];
    }
    
    // We query the database with km values and only use metre integer precision.
    NSString *distance = (NSString *)[JSONDict objectForKey:@"dst"];
    [room setQueryDistance:@([distance integerValue] * 1000)];
    NSString *latitude = (NSString *)[JSONDict objectForKey:@"lat"];
    [room setLatitude:@([latitude floatValue])];
    NSString *longitude = (NSString *)[JSONDict objectForKey:@"lng"];
    [room setLongitude:@([longitude floatValue])];
    
    NSLog(@"Inserting Room: %@", [room description]);
    [ETRCoreDataHelper saveContext];
}

+ (ETRRoom *)roomWithRemoteID:(long)remoteID {
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:[ETRCoreDataHelper roomEntityName]];
    NSString *where = [NSString stringWithFormat:@"%@ == %ld", ETRRemoteIDKey, remoteID];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:where];
    [fetch setPredicate:predicate];
    NSArray *existingRooms = [[ETRCoreDataHelper context] executeFetchRequest:fetch error:nil];
    
    ETRRoom *room;
    if (existingRooms && [existingRooms count]) {
        if ([existingRooms[0] isKindOfClass:[ETRRoom class]]) {
            room = (ETRRoom *)existingRooms[0];
        }
    }
    
    return room;
}

+ (NSFetchedResultsController *)roomListResultsController {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[ETRCoreDataHelper roomEntityName]];
    
    // Add Sort Descriptors
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:ETRRoomDistanceKey ascending:YES]]];
    
    // Initialize Fetched Results Controller
    NSFetchedResultsController *resultsController;
    resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                   managedObjectContext:[ETRCoreDataHelper context]
                                                                     sectionNameKeyPath:nil
                                                                              cacheName:nil];
    
    // Configure Fetched Results Controller
//    [resultsController setDelegate:delegate];
    return resultsController;
}

#pragma mark -
#pragma mark Actions

+ (ETRAction *)actionWithRemoteID:(long)remoteID {
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:[ETRCoreDataHelper actionEntityName]];
    NSString *where = [NSString stringWithFormat:@"%@ == %ld", ETRRemoteIDKey, remoteID];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:where];
    [fetch setPredicate:predicate];
    NSArray *storedActions = [[ETRCoreDataHelper context] executeFetchRequest:fetch error:nil];
    
    ETRAction *action;
    if (storedActions && [storedActions count]) {
        if ([storedActions[0] isKindOfClass:[ETRAction class]]) {
            action = (ETRAction *)storedActions[0];
        }
    }
    
    return action;
}

+ (void)handleActionFromDictionary:(NSDictionary *)jsonDictionary {
    long remoteID = [jsonDictionary longValueForKey:@"a" withFallbackValue:-102];
    if (remoteID < 10) {
        NSLog(@"WARNING: Ignoring incoming Action with Remote ID %ld." , remoteID);
        return;
    }
    
    // Skip this Action, if an Object with this remote ID has already been stored locally.
    // Actions should not change, so they will not be updated.
    ETRAction *existingAction = [ETRCoreDataHelper actionWithRemoteID:remoteID];
    if (existingAction) {
        return;
    }
    
    // Incoming Actions are always unique. Just initialse a new one.
    ETRAction *receivedAction;
    receivedAction = [[ETRAction alloc] initWithEntity:[ETRCoreDataHelper actionEntity]
                        insertIntoManagedObjectContext:[ETRCoreDataHelper context]];
    
    [receivedAction setRemoteID:@(remoteID)];
    
    long roomID = [jsonDictionary longValueForKey:@"r" withFallbackValue:-103];
    if (roomID < 10) {
        NSLog(@"ERROR: Received Action with Room ID %ld.", roomID);
        return;
    }
    ETRRoom *room = [ETRCoreDataHelper roomWithRemoteID:roomID];
    [receivedAction setRoom:room];
    
    // Sender and recipient IDs may be a valid User ID, i.e. positive long,
    // or -10, the pre-defined ID for public (as recipient ID) and admin (as sender ID) messages.
    
    long senderID = [jsonDictionary longValueForKey:@"sn" withFallbackValue:-104];
    if (senderID > 10) {
        ETRUser *sender = [ETRCoreDataHelper userWithRemoteID:senderID
                                        downloadIfUnavailable:YES];
        [receivedAction setSender:sender];
    } else if (senderID == ETRActionPublicUserID) {
        // TODO: Handle Server messages.
    } else {
        NSLog(@"WARNING: Received Action with sender ID %ld", senderID);
    }
    
    long recipientID = [jsonDictionary longValueForKey:@"rc" withFallbackValue:-105];
    if (recipientID > 10) {
        ETRUser *recipient = [ETRCoreDataHelper userWithRemoteID:recipientID
                                          downloadIfUnavailable:YES];
        [receivedAction setRecipient:recipient];
    } else if (recipientID != ETRActionPublicUserID) {
        NSLog(@"WARNING: Received Action with recipient ID %ld", recipientID);
    }
    
    long timestamp = [jsonDictionary longValueForKey:@"t" withFallbackValue:1426439266];
    [receivedAction setSentDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
    
    [receivedAction setCode:@([jsonDictionary shortValueForKey:@"cd" withFallbackValue:-1])];
    
    [receivedAction setMessageContent:[jsonDictionary stringForKey:@"m"]];
    
    NSLog(@"DEBUG: Inserting Action into CoreData: %@ %@", [[receivedAction sender] remoteID], [receivedAction messageContent]);
    
    [ETRCoreDataHelper saveContext];
}

+ (void)dispatchPublicMessage:(NSString *)messageContent {
    ETRAction *message = [ETRCoreDataHelper blankOutgoingAction];
    if (!message) {
        return;
    }
    
    [message setCode:@(ETRActionCodePublicMessage)];
    [message setMessageContent:messageContent];
    
    // Immediately store them in the Context, so that they appear in the Conversation.
    [ETRCoreDataHelper saveContext];
    
    [ETRServerAPIHelper putAction:message];
}

+ (void)dispatchMessage:(NSString *)messageContent toRecipient:(ETRUser *)recipient {
    ETRAction *message = [ETRCoreDataHelper blankOutgoingAction];
    if (!message) {
        return;
    }
    
    [message setRecipient:recipient];
    [message setCode:@(ETRActionCodePrivateMessage)];
    [message setMessageContent:messageContent];
    [message setSentDate:[NSDate date]];
    
    // Immediately store them in the Context, so that they appear in the Conversation.
    [ETRCoreDataHelper saveContext];
    
    [ETRServerAPIHelper putAction:message];
}

+ (ETRAction *)blankOutgoingAction {
    // Outgoing messages are always unique. Just initalise a new one.
    ETRAction *message = [[ETRAction alloc] initWithEntity:[ETRCoreDataHelper actionEntity]
                            insertIntoManagedObjectContext:[ETRCoreDataHelper context]];
    
    ETRRoom *sessionRoom = [ETRSessionManager sessionRoom];
    ETRUser *localUser = [[ETRLocalUserManager sharedManager] user];
    if (!sessionRoom || !localUser) {
        NSLog(@"ERROR: Cannot build blank outgoing Action.");
        return nil;
    }
    
    [message setRoom:sessionRoom];
    [message setSender:localUser];
    [message setSentDate:[NSDate date]];
    [message setIsInQueue:@(NO)];

    return message;
}

+ (void)addActionToQueue:(ETRAction *)unsentAction {
    if (!unsentAction) {
        return;
    }
    
#ifndef DEBUG
    if ([[unsentAction isInQueue] boolValue]) {
        NSLog(@"DEBUG: Action \"%@\" is already in the queue.", unsentAction);
        return;
    }
#endif
    
    [unsentAction setIsInQueue:@(YES)];
    [ETRCoreDataHelper saveContext];
}

+ (void)removeActionFromQueue:(ETRAction *)sentAction {
    if (!sentAction) {
        return;
    }
    
    [sentAction setIsInQueue:@(NO)];
    [ETRCoreDataHelper saveContext];
}

+ (NSFetchedResultsController *)publicMessagesResultsControllerWithDelegage:(id<NSFetchedResultsControllerDelegate>)delegate {
    ETRRoom *sessionRoom = [[ETRSessionManager sharedManager] room];
    if (!sessionRoom || ![[ETRSessionManager sharedManager] didBeginSession]) {
        NSLog(@"ERROR: Session is not prepared.");
        return nil;
    }

    NSFetchRequest *fetchRequest;
    fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[ETRCoreDataHelper actionEntityName]];
    
    NSString *where = [NSString stringWithFormat:@"%@ == %i OR %@ == %i",
//                       ETRActionRoomKey,
//                       ETRRemoteIDKey,
//                       [[sessionRoom remoteID] longValue],
                       ETRActionCodeKey,
                       ETRActionCodePublicMessage,
                       ETRActionCodeKey,
                       ETRActionCodePublicMedia];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:where];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:ETRActionDateKey ascending:YES]]];
    
    NSFetchedResultsController *resultsController;
    resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                            managedObjectContext:[ETRCoreDataHelper context]
                                                              sectionNameKeyPath:nil
                                                                       cacheName:nil];
    
    // Configure Fetched Results Controller
    [resultsController setDelegate:delegate];
    return resultsController;
}

+ (NSFetchedResultsController *)messagesResultsControllerForPartner:(ETRUser *)partner
                                                       withDelegate:(id<NSFetchedResultsControllerDelegate>)delegate {
    NSFetchedResultsController *resultsController;

    
    // Configure Fetched Results Controller
    [resultsController setDelegate:delegate];
    return resultsController;
}

+ (void)clearPublicActions {
    NSFetchRequest * allPublicActions;
    allPublicActions = [[NSFetchRequest alloc] initWithEntityName:[ETRCoreDataHelper actionEntityName]];
    
    NSString *where = [NSString stringWithFormat:@"%@ == %i OR %@ == %i",
                       ETRActionCodeKey,
                       ETRActionCodePublicMessage,
                       ETRActionCodeKey,
                       ETRActionCodePublicMedia];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:where];
    [allPublicActions setPredicate:predicate];
    // Only fetch the ManagedObjectID.
    [allPublicActions setIncludesPropertyValues:NO];
    
    NSError * error = nil;
    NSArray * actions = [[ETRCoreDataHelper context] executeFetchRequest:allPublicActions
                                                                   error:&error];
    //error handling goes here
    for (NSManagedObject * action in actions) {
        [[ETRCoreDataHelper context] deleteObject:action];
    }
    
    [ETRCoreDataHelper saveContext];
}

#pragma mark -
#pragma mark User Objects

+ (ETRUser *)insertUserFromDictionary:(NSDictionary *)jsonDictionary {
    // Get the remote DB ID from the JSON data.
    long remoteID = [jsonDictionary longValueForKey:@"u" withFallbackValue:-55];
    
    if (remoteID < 10) {
        NSLog(@"ERROR: Could not insert User because remote ID is invalid: %ld", remoteID);
        return nil;
    }
    
    // Get the existing Object or an empty one to fill.
    ETRUser *user = [ETRCoreDataHelper userWithRemoteID:remoteID downloadIfUnavailable:NO];
    
    [user setImageID:@([jsonDictionary longValueForKey:@"i" withFallbackValue:-5])];
    [user setName:[jsonDictionary stringForKey:@"n"]];
    [user setStatus:[jsonDictionary stringForKey:@"s"]];
    [user setMail:[jsonDictionary stringForKey:@"em"]];
    [user setPhone:[jsonDictionary stringForKey:@"ph"]];
    [user setWebsite:[jsonDictionary stringForKey:@"ws"]];
    [user setFacebook:[jsonDictionary stringForKey:@"fb"]];
    [user setInstagram:[jsonDictionary stringForKey:@"ig"]];
    [user setTwitter:[jsonDictionary stringForKey:@"tw"]];
    
    NSLog(@"Inserting User: %@", [user description]);
    [ETRCoreDataHelper saveContext];
    return user;
}

+ (ETRUser *)copyUser:(ETRUser *)user {
    ETRUser *copiedUser = [[ETRUser alloc] initWithEntity:[ETRCoreDataHelper userEntity]
                           insertIntoManagedObjectContext:[ETRCoreDataHelper context]];
    
    // Copy all the attributes.
    [copiedUser setRemoteID:[user remoteID]];
    [copiedUser setImageID:[user imageID]];
    [copiedUser setName:[user name]];
    [copiedUser setStatus:[user status]];
    [copiedUser setPhone:[user phone]];
    [copiedUser setMail:[user mail]];
    [copiedUser setWebsite:[user website]];
    [copiedUser setFacebook:[user facebook]];
    [copiedUser setInstagram:[user instagram]];
    [copiedUser setTwitter:[user twitter]];
    
    // This user will not be stored.
    return copiedUser;
}

+ (ETRUser *)userWithRemoteID:(long)remoteID downloadIfUnavailable:(BOOL)doDownload {
    // Check the context CoreData, if an object with this remote ID exists.
    NSFetchRequest *fetch;
    fetch = [NSFetchRequest fetchRequestWithEntityName:[ETRCoreDataHelper userEntityName]];
    NSString *where = [NSString stringWithFormat:@"%@ == %ld", ETRRemoteIDKey, remoteID];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:where];
    [fetch setPredicate:predicate];
    NSArray *existingUsers = [[ETRCoreDataHelper context] executeFetchRequest:fetch error:nil];
    
    if (existingUsers && [existingUsers count]) {
        if ([existingUsers[0] isKindOfClass:[ETRUser class]]) {
            return (ETRUser *)existingUsers[0];
        }
    }
    
    if (doDownload) {
        [ETRServerAPIHelper getUserWithID:remoteID];
    }
    
    ETRUser *newUser = [[ETRUser alloc] initWithEntity:[ETRCoreDataHelper userEntity]
                        insertIntoManagedObjectContext:[ETRCoreDataHelper context]];
    [newUser setRemoteID:@(remoteID)];
    [newUser setName:NSLocalizedString(@"Unknown_User", @"Name placeholder")];
    [newUser setStatus:@"..."];
    
    return newUser;
}

@end

@implementation NSDictionary (TypesafeJSON)

- (NSString *)stringForKey:(id)key {
    id object = [self objectForKey:key];
    
    if (object && [object isKindOfClass:[NSString class]]) {
        return (NSString *)object;
    } else {
        return nil;
    }
}

- (long)longValueForKey:(id)key withFallbackValue:(long)fallbackValue {
    NSString *value = [self stringForKey:key];
    if (value) {
        return (long) [value longLongValue];
    } else {
        return fallbackValue;
    }
}

- (short)shortValueForKey:(id)key withFallbackValue:(short)fallbackValue {
    NSString *value = [self stringForKey:key];
    if (value) {
        return [value integerValue];
    } else {
        return fallbackValue;
    }
}

@end