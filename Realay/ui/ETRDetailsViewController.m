//
//  ETRProfileViewControllerTableViewController.m
//  Realay
//
//  Created by Michel on 06/03/15.
//  Copyright (c) 2015 Easy Target. All rights reserved.
//

#import "ETRDetailsViewController.h"

#import "ETRAlertViewFactory.h"
#import "ETRHeaderCell.h"
#import "ETRImageLoader.h"
#import "ETRKeyValueCell.h"
#import "ETRLocalUserManager.h"
#import "ETRLocationManager.h"
#import "ETRProfileButtonCell.h"
#import "ETRProfileSocialCell.h"
#import "ETRReadabilityHelper.h"
#import "ETRRoom.h"
#import "ETRSessionManager.h"
#import "ETRUser.h"

#define kHeaderCellIdentifier           @"profileHeaderCell"
#define kValueCellIdentifier            @"profileValueCell"
#define kSocialMediaCellIdentifier      @"socialMediaCell"
#define kButtonCellIdentifier           @"profileButtonCell"

#define kEditorSegue                    @"profileToEditorSegue"
#define kPasswordSegue                  @"detailsToPasswordSegue"

#define kProfilePlaceholderImageName    @"PlaceholderProfileW"

//#define NSLocalizedString(key, comment) [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]

@interface ETRDetailsViewController ()

@property (nonatomic) NSInteger phoneRow;

@property (nonatomic) NSInteger mailRow;

@property (nonatomic) NSInteger websiteRow;

@property (nonatomic) NSInteger socialMediaRow;

@end

@implementation ETRDetailsViewController

@synthesize room = _room;
@synthesize user = _user;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[[self navigationController] navigationBar] setTranslucent:YES];
    
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new]
                                                  forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
//    self.navigationController.navigationBar.translucent = YES;
//    self.navigationController.view.backgroundColor = [UIColor kPrimaryColorTransparent];
//    [[[self navigationController] navigationBar] setBackgroundColor:[UIColor kPrimaryColorTransparent]];
//    UIToolbar* blurredView = [[UIToolbar alloc] initWithFrame:self.navigationController.navigationBar.bounds];
//    [blurredView setBarStyle:UIBarStyleBlack];
//    [blurredView setBarTintColor:[UIColor redColor]];
//    [self.navigationController.navigationBar insertSubview:blurredView atIndex:0];
    
    [[self tableView] setRowHeight:UITableViewAutomaticDimension];
    [[self tableView] setEstimatedRowHeight:128.0f];
    [[self tableView] setTableFooterView:[[UIView alloc] initWithFrame:CGRectZero]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // Just in case there is a toolbar wanting to be displayed:
    [[self navigationController] setToolbarHidden:YES];
    
    if ((!_user && !_room) || (_user && _room)) {
        NSLog(@"ERROR: No Room or User object to show in this Detail View Controller.");
        [[self navigationController] popViewControllerAnimated:NO];
        return;
    }
    
    if (_room) {
        if ([[ETRSessionManager sharedManager] didBeginSession]) {
            [self setBarButton:nil];
        } else {
            [[self barButton] setTitle:NSLocalizedString(@"Join", @"Join")];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[self tableView] reloadData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGRect rect = self.navigationController.navigationBar.frame;
    
    float y = -rect.origin.y;
    
    self.tableView.contentInset = UIEdgeInsetsMake(y ,0,0,0);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section != 0) {
        return 0;
    }
    
    if (_room) {
        // This instance displays Room Details.
        // Rows: header, address, size, hours, number of people, description:
        return 6;
        
    } else if (_user) {
        // This instance displays User Details.
        // Rows: header, status,
        // (phone number, email address, website URL, Facebook ID, Instagram name, Twitter name)
        
        NSInteger numberOfRows = 2;
        if ([_user phone] && [[_user phone] length]) {
            numberOfRows++;
            _phoneRow = numberOfRows - 1;
        } else {
            _phoneRow = -1;
        }
        
        if ([_user mail] && [[_user mail] length]) {
            numberOfRows++;
            _mailRow = numberOfRows - 1;
        } else {
            _mailRow = -1;
        }
        
        if ([_user website] && [[_user website] length]) {
            numberOfRows++;
            _websiteRow = numberOfRows - 1;
        } else {
            _websiteRow = -1;
        }
        
        if ([self doShowSocialMediaRow]) {
            numberOfRows++;
            _socialMediaRow = numberOfRows - 1;
        } else {
            _socialMediaRow = -1;
        }
        
        if (![[ETRLocalUserManager sharedManager] isLocalUser:_user]) {
            // If this is not the local User, add a row for the block button.
            numberOfRows ++;
        }
        
        return numberOfRows;
    }
    
    return 0;
}

- (BOOL)doShowSocialMediaRow {
    if ([_user facebook] && [[_user facebook] length]) {
        return YES;
    }
    
    if ([_user instagram] && [[_user instagram] length]) {
        return YES;
    }
    
    if ([_user twitter] && [[_user twitter] length]) {
        return YES;
    }
    
    return NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ([indexPath row] == 0) {     // Configure the header cell.
        ETRHeaderCell *headerCell;
        headerCell = [tableView dequeueReusableCellWithIdentifier:kHeaderCellIdentifier
                                                     forIndexPath:indexPath];
        if (_room) {
            [[headerCell nameLabel] setText:[_room title]];
            [ETRImageLoader loadImageForObject:_room
                                      intoView:[headerCell headerImageView]
                                   doLoadHiRes:YES];
        } else if (_user) {
            [[headerCell nameLabel] setText:[_user name]];
            [[headerCell imageView] setImage:[UIImage imageNamed:kProfilePlaceholderImageName]];
            [ETRImageLoader loadImageForObject:_user
                                      intoView:[headerCell headerImageView]
                                   doLoadHiRes:YES];
        }
        return headerCell;
    }
    
    if (_room) {
        return [self roomCellInTableView:tableView forIndexPath:indexPath];
    } else if (_user) {
        return [self userCellInTableView:tableView forIndexPath:indexPath];
    }
    
    // Empty fallback cell:
    return [tableView dequeueReusableCellWithIdentifier:kValueCellIdentifier
                                           forIndexPath:indexPath];
}

- (ETRKeyValueCell  *)roomCellInTableView:(UITableView *)tableView
                                forIndexPath:indexPath {
    
    ETRKeyValueCell *cell;
    cell = [tableView dequeueReusableCellWithIdentifier:kValueCellIdentifier
                                           forIndexPath:indexPath];
    
    switch ([indexPath row]) {
        case 1: {
            [[cell keyLabel] setText:NSLocalizedString(@"location", @"Room address")];
            NSString *address = [_room address];
            if (!address) {
                address = [_room formattedCoordinates];
            }
            [[cell valueLabel] setText:address];
            break;
        }
            
        case 2: {
            [[cell keyLabel] setText:NSLocalizedString(@"size", @"Room Size")];
            NSString *size;
            size = [ETRReadabilityHelper formattedLength:[_room radius]];
            [[cell valueLabel] setText:size];
            break;
        }
            
        case 3: {
            [[cell keyLabel] setText:@""];
            NSString *timeSpan = [ETRReadabilityHelper timeSpanForStartDate:[_room startTime]
                                                                    endDate:[_room endDate]];
            [[cell valueLabel] setText:timeSpan];
            break;
        }
            
        case 4: {
            NSString *labelText;
            labelText = NSLocalizedString(@"users_online", @"Number of Users");
            [[cell keyLabel] setText:labelText];
            [[cell valueLabel] setText:[_room userCount]];
            break;
        }
            
        case 5: {
            [[cell keyLabel] setText:@""];
            [[cell valueLabel] setText:[_room summary]];
            break;
        }
        
    }
    
    return cell;
}

- (UITableViewCell *)userCellInTableView:(UITableView *)tableView
                                forIndexPath:indexPath {
    
    NSInteger row = [indexPath row];
    
    if (![[ETRLocalUserManager sharedManager] isLocalUser:_user]) {
        // The last row contains the block button, if this is not the local User.
        if (row == ([tableView numberOfRowsInSection:0] - 1)) {
            ETRProfileButtonCell *blockButtonCell;
            blockButtonCell = [tableView dequeueReusableCellWithIdentifier:kButtonCellIdentifier
                                                              forIndexPath:indexPath];
            
            NSString *blockUser = NSLocalizedString(@"Block_User", @"Block User");
            [[blockButtonCell buttonLabel] setText:blockUser];
            
            return blockButtonCell;
        }
    }
    
    if (row == _socialMediaRow) {
        // The cell for this row displays the social network buttons.
        ETRProfileSocialCell *socialMediaCell;
        socialMediaCell = [tableView dequeueReusableCellWithIdentifier:kSocialMediaCellIdentifier
                                                          forIndexPath:indexPath];
        return socialMediaCell;
    }
    
    // The cell for this row displays one specific attribute.
    
    ETRKeyValueCell *valueCell;
    valueCell = [tableView dequeueReusableCellWithIdentifier:kValueCellIdentifier
                                                forIndexPath:indexPath];
    
    if (row == 1) {     // Configure the status cell.
        NSString *statusKey;
        statusKey = NSLocalizedString(@"status", @"Status message");
        [[valueCell keyLabel] setText:statusKey];
        [[valueCell valueLabel] setText:[_user status]];
        return valueCell;
    }
    
    if (row == _phoneRow && [_user phone] && [[_user phone] length]) {
        NSString *phoneKey = NSLocalizedString(@"phone", @"Phone number");
        [[valueCell keyLabel] setText:phoneKey];
        [[valueCell valueLabel] setText:[_user phone]];
        return valueCell;
    }
    
    if (row == _mailRow && [_user mail] && [[_user mail] length]) {
        NSString *emailKey = NSLocalizedString(@"email", @"Email address");
        [[valueCell keyLabel] setText:emailKey];
        [[valueCell valueLabel] setText:[_user mail]];
        return valueCell;
    }
    
    if (row == _mailRow && [_user website] && [[_user website] length]) {
        NSString *websiteKey = NSLocalizedString(@"website", "Website URL");
        [[valueCell keyLabel] setText:websiteKey];
        [[valueCell valueLabel] setText:[_user website]];
        return valueCell;
    }
    
    return valueCell;
}

#pragma mark - Navigation

- (IBAction)barButtonPressed:(id)sender {
    if (_room) {
        if (![[ETRSessionManager sharedManager] didBeginSession]) {
            if ([ETRLocationManager isInSessionRegion]) {
                [self performSegueWithIdentifier:kPasswordSegue sender:nil];
            } else {
                [ETRAlertViewFactory showDistanceLeftAlertView];
            }
        }
    } else if (_user) {
        if ([[ETRLocalUserManager sharedManager] isLocalUser:_user]) {
            [self performSegueWithIdentifier:kEditorSegue sender:nil];
        } else {
            // TODO: Implement adding contacts.
        }
    }
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

@end