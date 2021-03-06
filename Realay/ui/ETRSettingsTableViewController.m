//
//  ETRSettingsTableViewController.m
//  Realay
//
//  Created by Michel on 10/06/15.
//  Copyright © 2015 Easy Target. All rights reserved.
//

#import "ETRSettingsTableViewController.h"

#import "ETRDetailsViewController.h"
#import "ETRLocalUserManager.h"
//#import "ETRLocationManager.h"
//#import "ETRUIConstants.h"


static NSString *const ETRSegueSettingsToBlockedUsers = @"SettingsToBlockedUsers";

static NSString *const ETRSegueSettingsToLogin = @"SettingsToLogin";

static NSString *const ETRSegueSettingsToProfile = @"SettingsToProfile";


@interface ETRSettingsTableViewController () <UITableViewDelegate>

@end


@implementation ETRSettingsTableViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Reset Bar elements that might have been changed during navigation to other View Controllers.
    [[[self navigationController] navigationBar] setTranslucent:NO];
    [[self navigationController] setToolbarHidden:YES animated:YES];
}

#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(nonnull UITableView *)tableView didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch ([indexPath row]) {
        case 0:
            if ([ETRLocalUserManager userID] > 10) {
                [self performSegueWithIdentifier:ETRSegueSettingsToProfile sender:nil];
            } else {
                [self performSegueWithIdentifier:ETRSegueSettingsToLogin sender:nil];
            }
            break;
            
        case 2:
            [self performSegueWithIdentifier:ETRSegueSettingsToBlockedUsers sender:nil];
            break;
            
        default: {
            NSString * settingsURL = UIApplicationOpenSettingsURLString;
            if (settingsURL) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:settingsURL]];
            }
        }
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    UIViewController * destination = [segue destinationViewController];
    if ([destination isKindOfClass:[ETRDetailsViewController class]]) {
        ETRDetailsViewController * profileViewController;
        profileViewController = (ETRDetailsViewController *)destination;
        [profileViewController setUser:[[ETRLocalUserManager sharedManager] user]];
    }
}

@end
