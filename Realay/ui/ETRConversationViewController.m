//
//  ChatViewController.m
//  Realay
//
//  Created by Michel S on 01.12.13.
//  Copyright (c) 2013 Michel Sievers. All rights reserved.
//

#import "ETRConversationViewController.h"

#import "ETRAction.h"
#import "ETRActionManager.h"
#import "ETRAnimator.h"
#import "ETRAlertViewFactory.h"
#import "ETRBouncer.h"
#import "ETRConversation.h"
#import "ETRCoreDataHelper.h"
#import "ETRDefaultsHelper.h"
#import "ETRDetailsViewController.h"
#import "ETRImageEditor.h"
#import "ETRImageLoader.h"
#import "ETRImageView.h"
#import "ETRMediaViewController.h"
#import "ETRUser.h"
#import "ETRReceivedMediaCell.h"
#import "ETRReceivedMessageCell.h"
#import "ETRFormatter.h"
#import "ETRRoom.h"
#import "ETRSentMediaCell.h"
#import "ETRSentMessageCell.h"
#import "ETRSessionManager.h"
#import "ETRUIConstants.h"
#import "ETRUser.h"


static CGFloat const ETREstimatedMessageRowHeight = 90.0f;

static NSString *const ETRConversationToUserListSegue = @"PublicChatToSessionTabs";

static NSString *const ETRConversationToProfileSegue = @"ChatToProfile";

static NSString *const ETRReceivedMessageCellIdentifier = @"receivedMessageCell";

static NSString *const ETRReceivedMediaCellIdentifier = @"receivedMediaCell";

static NSString *const ETRSentMessageCellIdentifier = @"sentMessageCell";

static NSString *const ETRSentMediaCellIdentifier = @"sentMediaCell";

static int const ETRMessagesLimitStep = 20;


@interface ETRConversationViewController ()
<
ETRInternalNotificationHandler,
NSFetchedResultsControllerDelegate,
UIImagePickerControllerDelegate,
UINavigationControllerDelegate,
UITableViewDataSource,
UITableViewDelegate,
UITextViewDelegate
>

/*
 
 */
@property (strong, nonatomic) NSFetchedResultsController * fetchedResultsController;

/*
 
 */
@property (nonatomic,retain) UIRefreshControl * historyControl;

/*
 
 */
@property (nonatomic) BOOL didFirstScrolldown;

/*
 
 */
@property (nonatomic) NSUInteger messagesLimit;

/*
 
 */
@property (strong, nonatomic) NSDictionary * messageAttributes;

@end


@implementation ETRConversationViewController

# pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self verifySession];
     
    // Enable automatic scrolling.
    [self setAutomaticallyAdjustsScrollViewInsets:NO];
    
    _messageAttributes = @{NSFontAttributeName : [UIFont fontWithName:@"Helvetica Neue" size:15],
                           NSForegroundColorAttributeName : [UIColor whiteColor] };
    
    // Tapping anywhere but the keyboard, hides it.
    UITapGestureRecognizer * tap;
    tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                  action:@selector(dismissKeyboard)];
    [[self messagesTableView] addGestureRecognizer:tap];
    
    // Do not display empty cells at the end.
    [[self messagesTableView] setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];
    [[self messagesTableView] setRowHeight:UITableViewAutomaticDimension];
    [[self messagesTableView] setEstimatedRowHeight:ETREstimatedMessageRowHeight];
    
    // Add a long press Recognizer to the Table.
    UILongPressGestureRecognizer * recognizer;
    recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    [recognizer setMinimumPressDuration:0.8];
    [[self messagesTableView] addGestureRecognizer:recognizer];
    
    // Initialize the Fetched Results Controller
    // that is going to load and monitor message records.
    _messagesLimit = 30L;
    [self setUpFetchedResultsController];
    
    // Configure Views depending on purpose of this Conversation.
    if (_isPublic) {
        ETRRoom * sessionRoom;
        sessionRoom = [ETRSessionManager sessionRoom];
        [self setTitle:[sessionRoom title]];

        [[self navigationItem] setHidesBackButton:YES];
        UIBarButtonItem * exitButton;
        exitButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Leave", @"Exit Session")
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(exitButtonPressed:)];
        [[self navigationItem] setLeftBarButtonItem:exitButton];
        
        // Only Public Conversations have a badge in the Navigation Bar.
//        [[[self navigationController] navigationBar] addSubview:[self badgeLabel]];
        
        // Only public Conversations get a BackBarButton that has a title (in the _next_ ViewController).
        NSString * returnTitle = NSLocalizedString(@"Chat", @"(Public) Chat");
        [[[self navigationItem] backBarButtonItem] setTitle:returnTitle];
    } else if (_partner) {
        [self setTitle:[_partner name]];
        [[self moreButton] setTitle:NSLocalizedString(@"Profile", @"User Profile")];
        [[self messagesTableView] setBackgroundColor:[ETRUIConstants secondaryBackgroundColor]];
    }
    
    // Configure manual refresher.
    _historyControl = [[UIRefreshControl alloc] init];
    [_historyControl addTarget:self
                       action:@selector(extendHistory)
             forControlEvents:UIControlEventValueChanged];
    [_historyControl setTintColor:[ETRUIConstants accentColor]];
    NSString * pullDownText = NSLocalizedString(@"Pull_down_load_older", @"Load old messages");
    [_historyControl setAttributedTitle:[[NSAttributedString alloc] initWithString:pullDownText]];
    [[self messagesTableView] addSubview:_historyControl];
    
    _didFirstScrolldown = NO;
    [[self mediaButton] setTintColor:[UIColor whiteColor]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[self galleryButton] setHidden:YES];
    [[self cameraButton] setHidden:YES];
    
    // Listen for keyboard changes.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    // Reset Bar elements that might have been changed during navigation to other View Controllers.
    [[self navigationController] setToolbarHidden:YES];
    [[[self navigationController] navigationBar] setTranslucent:NO];
    
    NSNumber * conversationID;
    if (_isPublic) {
        ETRRoom * sessionRoom;
        sessionRoom = [ETRSessionManager sessionRoom];
        [[self navigationController] setTitle:[sessionRoom title]];
        conversationID = @(ETRActionPublicUserID);
    } else if (_partner) {
        [[self navigationController] setTitle:[_partner name]];
        conversationID = [_partner remoteID];
    } else {
        [[self navigationController] popToRootViewControllerAnimated:YES];
        return;
    }
    
    [[ETRActionManager sharedManager] setForegroundPartnerID:conversationID];
    
    // Restore any unsent message input.
    NSString * lastText = [ETRDefaultsHelper messageInputTextForConversationID:conversationID];
    [[self messageInputView] setText:lastText];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[self messagesTableView] reloadData];
    
    [self verifySession];
    [self updateConversationStatus];
    
    if (_isPublic) {
        // The first time a public Conversation is shown,
        // ask for Notification Permissions.
        
        UIUserNotificationType types;
        types = UIUserNotificationTypeBadge | UIUserNotificationTypeAlert | UIUserNotificationTypeSound;
        UIUserNotificationSettings * settings;
        settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        
        // Let the user know that everything posted here can be seen by everyone.
        [[self navigationItem] setPrompt:NSLocalizedString(@"Public_Chat", @"Public Group Conversation")];
        
        // Public Conversations have a Badge
        // that shows the number of unread private messages.
        [[ETRActionManager sharedManager] setInternalNotificationHandler:self];
    }
    
    if (!_didFirstScrolldown) {
        [self scrollDownTableViewAnimated];
        _didFirstScrolldown = YES;
    }
    
    // Load any remaining images after a while, if the table is calm.
    dispatch_after(
                   dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                   dispatch_get_main_queue(),
                   ^{
                       if (![[self messagesTableView] isDragging] && ![[self messagesTableView] isDecelerating]) {
                           [self loadImagesForOnScreenRows];
                       }
                   }
                   );
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self dismissKeyboard];
    [[self navigationItem] setPrompt:nil];
    
    // Disable delegates.
    [[self messageInputView] setDelegate:nil];
    
    // Show all notifications because no chat is visible.
    [[ETRActionManager sharedManager] setForegroundPartnerID:@(-100L)];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    
    // Store unset message input.
    NSNumber * conversationID;
    if (_isPublic) {
        conversationID = @(ETRActionPublicUserID);
    } else if (_partner && [[self messagesTableView] numberOfRowsInSection:0] > 0) {
        conversationID = [_partner remoteID];
        
        // Acknowledge that all messages have been read in this Private Conversation.
        ETRConversation * conversation;
        conversation = [ETRCoreDataHelper conversationWithPartner:_partner];
        [conversation setHasUnreadMessage:@(NO)];
    }
    [ETRDefaultsHelper storeMessageInputText:[[self messageInputView] text]
                           forConversationID:conversationID];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    _messagesLimit = 10;
    
    [self setUpFetchedResultsController];
    [[self messagesTableView] reloadData];
    [[self historyControl] endRefreshing];
}

#pragma mark -
#pragma mark Session Events

- (BOOL)verifySession {
    if (!_isPublic && !_partner) {
        NSLog(@"ERROR: No Conversation found.");
        [[ETRSessionManager sharedManager] endSessionWithNotificaton:NO];
        [[self navigationController] popToRootViewControllerAnimated:YES];
        return NO;
    }
    
    // Make sure the room manager meets the requirements for this view controller.
    if (![ETRSessionManager sessionRoom] || ![[ETRSessionManager sharedManager] didStartSession]) {
        NSLog(@"ERROR: No Room object in manager or user did not join.");
        [[ETRSessionManager sharedManager] endSessionWithNotificaton:NO];
        [[self navigationController] popToRootViewControllerAnimated:YES];
        return NO;
    }
    
    return YES;
}

- (BOOL)updateConversationStatus {
    if (_partner) {
        ETRRoom * sessionRoom = [ETRSessionManager sessionRoom];
        if (![sessionRoom isEqual:[_partner inRoom]]) {
            NSString * hasLeftFormat = NSLocalizedString(@"has_left", "%@ has left %@.");
            NSString * hasLeftText;
            hasLeftText = [NSString stringWithFormat:hasLeftFormat, [_partner name], [sessionRoom title]];
            [[self inputCover] setText:hasLeftText];
            [ETRAnimator fadeView:[self inputCover] doAppear:YES completion:nil];
            return NO;
        }
    }
    
    [ETRAnimator fadeView:[self inputCover] doAppear:NO completion:nil];
//    [[self inputCover] setHidden:YES];
    return YES;
}

- (void)setPrivateMessagesBadgeNumber:(NSInteger)number {
    if (_partner) {
        // Private Conversations do not display a badge.
        [[self badgeLabel] setHidden:YES];
        return;
    }
    
    [super setPrivateMessagesBadgeNumber:number
                                 inLabel:[self badgeLabel]
                          animateFromTop:YES];
}

#pragma mark -
#pragma mark Public/Private Conversation Definition

- (void)setIsPublic:(BOOL)isPublic {
    _partner = nil;
    _isPublic = isPublic;
}

- (void)setPartner:(ETRUser *)partner {
    _isPublic = NO;
    _partner = partner;
}

#pragma mark -
#pragma mark Fetched Results Controller

- (void)setUpFetchedResultsController {
    if (_isPublic) {
        _fetchedResultsController = [ETRCoreDataHelper publicMessagesResultsControllerWithDelegate:self
                                                                              numberOfLastMessages:_messagesLimit];
    } else if (_partner) {
        _fetchedResultsController = [ETRCoreDataHelper messagesResultsControllerForPartner:_partner
                                                                      numberOfLastMessages:_messagesLimit
                                                                                  delegate:self];
    }
    
    NSError * error = nil;
    [_fetchedResultsController performFetch:&error];
    if (error) {
        NSLog(@"ERROR: performFetch: %@", error);
    }
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [[self messagesTableView] beginUpdates];
    [[self historyControl] endRefreshing];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [[self messagesTableView] endUpdates];
    [self scrollDownTableViewAnimated];
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
        
    switch (type) {
        case NSFetchedResultsChangeInsert: {
            [[self messagesTableView] insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                                            withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
        case NSFetchedResultsChangeDelete: {
            [[self messagesTableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                            withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
        case NSFetchedResultsChangeUpdate: {
            [[self messagesTableView] cellForRowAtIndexPath:indexPath];
            break;
        }
        case NSFetchedResultsChangeMove: {
            [[self messagesTableView] deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                            withRowAnimation:UITableViewRowAnimationFade];
            [[self messagesTableView] insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                                            withRowAnimation:UITableViewRowAnimationFade];
        }
    }
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger numberOfRows = [[_fetchedResultsController fetchedObjects] count];
    
    if (!_partner && numberOfRows < 1 && [[self infoLabel] isHidden]) {
        [ETRAnimator fadeView:[self infoLabel] doAppear:YES completion:nil];
    } else if (![[self infoLabel] isHidden]){
        [ETRAnimator fadeView:[self infoLabel] doAppear:NO completion:nil];
    }
    
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ETRAction * action = [_fetchedResultsController objectAtIndexPath:indexPath];
    
    UITableViewCell * cell;
    ETRImageView * userIconView;
    ETRImageView * mediaView;
    
    if ([action isSentAction]) {
        if ([action isPhotoMessage]) {
            ETRSentMediaCell * sentMediaCell;
            sentMediaCell = [tableView dequeueReusableCellWithIdentifier:ETRSentMediaCellIdentifier];
            
            [[sentMediaCell timeLabel] setText:[action formattedDate]];
            
            cell = sentMediaCell;
            mediaView = [sentMediaCell iconView];

        } else {
            ETRSentMessageCell * sentMessageCell;
            sentMessageCell = [tableView dequeueReusableCellWithIdentifier:ETRSentMessageCellIdentifier
                                                   forIndexPath:indexPath];
            NSAttributedString * messageText;
            messageText = [action messageStringWithAttributes:_messageAttributes];
            [[sentMessageCell messageView] setAttributedText:messageText];
            
            [[sentMessageCell timeLabel] setText:[action formattedDate]];
            
            return sentMessageCell;
        }
    } else {
        ETRUser * sender = [action sender];
        NSString * senderName;
        if (_isPublic) {
            if (sender && [sender name]) {
                senderName = [sender name];
            } else {
                senderName = @"n/a";
            }
        }
        
        if ([action isPhotoMessage]) {
            ETRReceivedMediaCell * receivedMediaCell;
            receivedMediaCell = [tableView dequeueReusableCellWithIdentifier:ETRReceivedMediaCellIdentifier
                                                   forIndexPath:indexPath];
            if (_isPublic) {
                [[receivedMediaCell nameLabel] setText:senderName];
            } else {
                [[receivedMediaCell nameLabel] removeFromSuperview];
            }
            
            [[receivedMediaCell timeLabel] setText:[action formattedDate]];
            
            cell = receivedMediaCell;
            userIconView = [receivedMediaCell userIconView];
            mediaView = [receivedMediaCell iconView];
            
        } else {
            ETRReceivedMessageCell * receivedMsgCell;
            receivedMsgCell = [tableView dequeueReusableCellWithIdentifier:ETRReceivedMessageCellIdentifier
                                                   forIndexPath:indexPath];
            
            if (_isPublic) {
                [[receivedMsgCell nameLabel] setText:senderName];
            } else {
                [[receivedMsgCell nameLabel] removeFromSuperview];
            }
            
            [[receivedMsgCell nameLabel] setText:senderName];
            
            NSAttributedString * messageText;
            messageText = [action messageStringWithAttributes:_messageAttributes];
            [[receivedMsgCell messageView] setAttributedText:messageText];
            
            [[receivedMsgCell timeLabel] setText:[action formattedDate]];
            
            cell = receivedMsgCell;
            userIconView = [receivedMsgCell userIconView];
        }
    }
    
    BOOL doLoadImage = ![[self messagesTableView] isDragging] && ![[self messagesTableView] isDecelerating];
    
    if (userIconView) {
        if ([[action sender] lowResImage]) {
            [ETRImageEditor cropImage:[[action sender] lowResImage]
                            imageName:[[action sender] imageFileName:NO]
                          applyToView:userIconView];
        } else {
            UIImage * userIconPlaceHolder;
            userIconPlaceHolder = [UIImage imageNamed:ETRImageNameUserIcon];
            [userIconView setImage:[userIconPlaceHolder imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        }
        
        if (doLoadImage) {
            [ETRImageLoader loadImageForObject:[action sender]
                                      intoView:userIconView
                              placeHolderImage:nil doLoadHiRes:NO];
        }
    }
    
    if (mediaView) {
        if ([action lowResImage]) {
            [ETRImageEditor cropImage:[action lowResImage]
                            imageName:[action imageFileName:NO]
                          applyToView:mediaView];
        } else {
            UIImage * mediaPlaceHolder;
            mediaPlaceHolder = [UIImage imageNamed:ETRImageCamera];
            [mediaView setImage:[mediaPlaceHolder imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
        }
        
        if (doLoadImage) {
            [ETRImageLoader loadImageForObject:[action sender]
                                      intoView:userIconView
                              placeHolderImage:nil doLoadHiRes:NO];
        }
    }

    return cell;
}

/*
 Scrolls to the bottom of a table
 */
- (void)scrollDownTableViewAnimated {
    dispatch_block_t scrollBlock = ^{
                           NSInteger bottomRow;
                           bottomRow = [_messagesTableView numberOfRowsInSection:0] - 1;
                           if (bottomRow >= 0) {
                               NSIndexPath * indexPath;
                               indexPath = [NSIndexPath indexPathForRow:bottomRow inSection:0];
                               [[self messagesTableView] scrollToRowAtIndexPath:indexPath
                                                               atScrollPosition:UITableViewScrollPositionBottom
                                                                       animated:YES];
                           }
    };
    
    dispatch_after(
               dispatch_time(DISPATCH_TIME_NOW, 0.8 * NSEC_PER_SEC),
               dispatch_get_main_queue(),
               scrollBlock
               );
    dispatch_after(
                   dispatch_time(DISPATCH_TIME_NOW, 1.6 * NSEC_PER_SEC),
                   dispatch_get_main_queue(),
                   scrollBlock
                   );
}

#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self hideMediaMenuWithCompletion:nil];
}

// TODO: Background color in private Convs.

#pragma mark -
#pragma mark UIScrollViewDelegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self loadImagesForOnScreenRows];
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView
                 willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self loadImagesForOnScreenRows];
    }
}

- (void)loadImagesForOnScreenRows {
    if ([[self messagesTableView] numberOfRowsInSection:0] > 0) {
        
        NSArray * visiblePaths = [[self messagesTableView] indexPathsForVisibleRows];
        for (NSIndexPath * indexPath in visiblePaths) {
            ETRAction * action = [_fetchedResultsController objectAtIndexPath:indexPath];
            
            if ([action isSentAction]) {
                if ([action isPhotoMessage]) {
                    ETRSentMediaCell * cell;
                    cell = (ETRSentMediaCell *)[[self messagesTableView] cellForRowAtIndexPath:indexPath];
                    [ETRImageLoader loadImageForObject:action
                                              intoView:[cell iconView]
                                      placeHolderImage:nil
                                           doLoadHiRes:NO];
                }
            } else {
                if ([action isPhotoMessage]) {
                    ETRReceivedMediaCell * cell;
                    cell = (ETRReceivedMediaCell *)[[self messagesTableView] cellForRowAtIndexPath:indexPath];
                    
                    [ETRImageLoader loadImageForObject:[action sender]
                                              intoView:[cell userIconView]
                                      placeHolderImage:nil
                                           doLoadHiRes:NO];
                    [ETRImageLoader loadImageForObject:action
                                              intoView:[cell iconView]
                                      placeHolderImage:nil
                                           doLoadHiRes:NO];
                } else {
                    ETRReceivedMessageCell * cell;
                    cell = (ETRReceivedMessageCell *)[[self messagesTableView] cellForRowAtIndexPath:indexPath];
                    [ETRImageLoader loadImageForObject:[action sender]
                                              intoView:[cell userIconView]
                                      placeHolderImage:nil
                                           doLoadHiRes:NO];
                }
            }

        }
    }
}

#pragma mark -
#pragma mark Additional Table Input

-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan) {
        CGPoint point = [gestureRecognizer locationInView:[self messagesTableView]];
        NSIndexPath * indexPath = [[self messagesTableView] indexPathForRowAtPoint:point];
        
        ETRAction * record = [_fetchedResultsController objectAtIndexPath:indexPath];
        [[self alertHelper] showMenuForMessage:record calledByViewController:self];
    }
}

- (void)extendHistory {
    // Increase the message limit and request a new Results Controller.
    _messagesLimit += ETRMessagesLimitStep;
    
    [self setUpFetchedResultsController];
    [[self messagesTableView] reloadData];
    [[self historyControl] endRefreshing];
}

#pragma mark -
#pragma mark Buttons

- (IBAction)sendButtonPressed:(id)sender {
    [self dismissKeyboard];
    
    if (![self updateConversationStatus]) {
        return;
    }
    
    // Get the message from the text field.
    NSString * typedString = [[[self messageInputView] text]
                             stringByTrimmingCharactersInSet:
                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([typedString length] > 0) {
        if (_isPublic) {
            if (![[ETRBouncer sharedManager] isSpam:typedString]) {
                [ETRCoreDataHelper dispatchPublicMessage:typedString];
            } else {
                [[self messageInputView] setText:@""];
            }
        } else {
            [ETRCoreDataHelper dispatchMessage:typedString toRecipient:_partner];
        }
    }
    
    [[self messageInputView] setText:@""];
}

- (IBAction)mediaButtonPressed:(id)sender {
    // If the lower button, the camera button, is hidden, open the menu.
    
    if ([[self cameraButton] isHidden]) {
        if (![self updateConversationStatus]) {
            return;
        }
        
        // Expand the menu from the bottom.
        [ETRAnimator toggleBounceInView:[self cameraButton]
                         animateFromTop:NO
                               duration:ETRTimeIntervalAnimationFast
                             completion:^{
                                 [ETRAnimator toggleBounceInView:[self galleryButton]
                                                  animateFromTop:NO
                                                        duration:ETRTimeIntervalAnimationFast
                                                      completion:nil];
                             }];
        
        // Replace the icon with an arrow and rotate it.
        [[self mediaButton] setImage:[UIImage imageNamed:ETRImageNameArrowRight]];
        [UIView animateWithDuration:0.2
                         animations:^{
                             CGAffineTransform transform;
                             transform = CGAffineTransformMakeRotation(-90.0f * M_PI_4);
                             [[self mediaButton] setTransform:transform];
                         }];
    } else {
        [self hideMediaMenuWithCompletion:nil];
    }
}

/*
 Closes the menu, if the upper button, the gallery button, is visible
 */
- (void)hideMediaMenuWithCompletion:(void(^)(void))completion {
    if(![[self galleryButton] isHidden]) {
        // Collapse the menu from the top.
        [ETRAnimator toggleBounceInView:[self galleryButton]
                         animateFromTop:NO
                               duration:ETRTimeIntervalAnimationFast
                             completion:^{
                                 [ETRAnimator toggleBounceInView:[self cameraButton]
                                                  animateFromTop:NO
                                                        duration:ETRTimeIntervalAnimationFast
                                                      completion:^{
                                                          if (completion) {
                                                              completion();
                                                          }
                                                      }];
                             }];
        
        // Rotate the arrow back and show the default icon when finished.
        [UIView animateWithDuration:0.2
                         animations:^{
                             CGAffineTransform transform;
                             transform = CGAffineTransformMakeRotation(0.0f);
                             [[self mediaButton] setTransform:transform];
                         }
                         completion:^(BOOL finished) {
                             [[self mediaButton] setImage:[UIImage imageNamed:ETRImageNameAttachFile]];
                         }];
    }
}

- (IBAction)galleryButtonPressed:(id)sender {
    [ETRAnimator flashFadeView:[self galleryButton] completion:nil];
    
    [self hideMediaMenuWithCompletion:^{
        UIImagePickerController * picker = [[UIImagePickerController alloc] init];
        [picker setDelegate:self];
        [picker setSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
        [picker setAllowsEditing:YES];
        
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (IBAction)cameraButtonPressed:(id)sender {
    [ETRAnimator flashFadeView:[self cameraButton] completion:nil];
    
    [self hideMediaMenuWithCompletion:^{
        UIImagePickerController * picker = [[UIImagePickerController alloc] init];
        [picker setDelegate:self];
        [picker setSourceType:UIImagePickerControllerSourceTypeCamera];
        [picker setAllowsEditing:YES];
        
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if (_isPublic) {
        [ETRCoreDataHelper dispatchPublicImageMessage:[ETRImageEditor imageFromPickerInfo:info]];
    } else if (_partner) {
        [ETRCoreDataHelper dispatchImageMessage:[ETRImageEditor imageFromPickerInfo:info]
                                    toRecipient:_partner];
    }
}

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
    [[navigationController navigationBar] setBarStyle:UIBarStyleBlack];
}

#pragma mark - Keyboard Notifications

- (void)dismissKeyboard {
    [[self messageInputView] resignFirstResponder];
    [self hideMediaMenuWithCompletion:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    [self resizeViewWithOptions:[notification userInfo]];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self resizeViewWithOptions:[notification userInfo]];
}

- (void)resizeViewWithOptions:(NSDictionary *)options {

    // Get the animation values.
    NSTimeInterval animationDuration;
    UIViewAnimationCurve animationCurve;
    CGRect keyboardEndFrame;
    [[options objectForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&animationCurve];
    [[options objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    [[options objectForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardEndFrame];
    
    // Apply the animation values.
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:)];
    [UIView setAnimationCurve:animationCurve];
    [UIView setAnimationDuration:animationDuration];
    
    // Shrink the height of the view.
    CGRect viewFrame = [[self view] frame];
    CGRect keyboardEndFrameRelative = [[self view] convertRect:keyboardEndFrame fromView:nil];
    viewFrame.size.height = keyboardEndFrameRelative.origin.y;
    [[self view] setFrame:viewFrame];

    [UIView commitAnimations];
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    [self scrollDownTableViewAnimated];
}

#pragma mark -
#pragma mark UITextViewDelegate

- (BOOL)textView:(nonnull UITextView *)textView
shouldChangeTextInRange:(NSRange)range
 replacementText:(nonnull NSString *)text {
    
    NSString * newText = [[textView text] stringByReplacingCharactersInRange:range withString:text];
    
    if([newText length] <= 4000){
        return YES;
    } else {
        [textView setText:[newText substringToIndex:4000]];
        return NO;
    }
}

#pragma mark -
#pragma mark Navigation

- (IBAction)moreButtonPressed:(id)sender {
    // The More button is a Profile button in private chats.
    if (_isPublic) {
        
        if (![[self badgeLabel] isHidden]) {
            [ETRAnimator moveView:[self badgeLabel]
                   toDisappearAtY:(self.view.frame.size.height + 100.0f)
                       completion:^{
                           [self performSegueWithIdentifier:ETRConversationToUserListSegue
                                                     sender:nil];
                       }];
        } else {
            [self performSegueWithIdentifier:ETRConversationToUserListSegue
                                      sender:nil];
        }
        
        
    } else {
        [self performSegueWithIdentifier:ETRConversationToProfileSegue
                                  sender:_partner];
    }
}

- (IBAction)receivedMediaPressed:(id)sender {
    [self mediaPressed:sender];
}

- (IBAction)sentMediaPressed:(id)sender {
    [self mediaPressed:sender];
}

- (void)mediaPressed:(id)sender {
    CGPoint buttonPosition = [sender convertPoint:CGPointZero toView:[self messagesTableView]];
    NSIndexPath * indexPath = [[self messagesTableView] indexPathForRowAtPoint:buttonPosition];
    
    if (indexPath) {
        ETRAction * message = [_fetchedResultsController objectAtIndexPath:indexPath];

        UIView * activityIndicatorContainer;
        UITableViewCell * cell = [[self messagesTableView] cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:[ETRReceivedMediaCell class]]) {
            activityIndicatorContainer = [(ETRReceivedMediaCell *) cell iconView];
        } else if ([cell isKindOfClass:[ETRSentMediaCell class]]) {
            activityIndicatorContainer = [(ETRSentMediaCell *) cell iconView];
        }
        
        [ETRImageLoader loadImageForObject:message
                               doLoadHiRes:YES
                activityIndicatorContainer:activityIndicatorContainer
                      navigationController:[self navigationController]];
    }
}

- (void)exitButtonPressed:(id)sender {
    [[self alertHelper] showLeaveConfirmView];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    id destination = [segue destinationViewController];
    
    if ([destination isKindOfClass:[ETRDetailsViewController class]]) {
        ETRDetailsViewController *detailsViewController;
        detailsViewController = (ETRDetailsViewController *)destination;
        if ([sender isMemberOfClass:[ETRUser class]]) {
            [detailsViewController setUser:(ETRUser *)sender];
        }
    }
}


@end
