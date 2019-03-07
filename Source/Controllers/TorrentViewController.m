//
//  TorrentViewController.m
//  iTransmission
//
//  Created by Mike Chen on 10/3/10.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import "TorrentViewController.h"
#import "Controller.h"
#import "TorrentCell.h"
#import "Torrent.h"
#import "ALAlertBanner.h"
#import "SVWebViewController.h"
#import "PrefViewController.h"
#import "UIAlertViewPrivate.h"
#import "TDBadgedCell.h"
#import "NSString+Additions.h"
#import "DetailViewController.h"
#import "ControlButton.h"
#import "BandwidthController.h"
#import "InfoViewController.h"

#define ADD_TAG 1000
#define ADD_FROM_URL_TAG 1001
#define ADD_FROM_MAGNET_TAG 1002
#define REMOVE_COMFIRM_TAG 1003

@implementation TorrentViewController

@synthesize tableView;
@synthesize activityIndicator;
@synthesize activityItemView;
@synthesize activityCounterBadge;
@synthesize normalToolbarItems;
@synthesize editToolbarItems;
@synthesize doneButton;
@synthesize infoButton;
@synthesize selectedIndexPaths;
@synthesize activityItem;
@synthesize pref;
@dynamic UIUpdateTimer;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonClicked:)];
        UIBarButtonItem *flexSpaceOne = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(updateUI)];
		UIBarButtonItem *flexSpaceTwo = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		UIBarButtonItem *prefButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear-icon"] style:UIBarButtonItemStylePlain target:self action:@selector(prefButtonClicked:)];
		UIBarButtonItem *flexSpaceThree = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		UIBarButtonItem *bandwidthButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"bandwidth-icon"] style:UIBarButtonItemStylePlain target:self action:@selector(bandwidthButtonClicked:)];
		
        self.normalToolbarItems = [NSArray arrayWithObjects:addButton, flexSpaceOne, refreshButton, flexSpaceTwo, bandwidthButton, flexSpaceThree, prefButton, nil];
        self.toolbarItems = self.normalToolbarItems;
        
		UIBarButtonItem *pauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action:@selector(resumeButtonClicked:)];
		UIBarButtonItem *resumeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause target:self action:@selector(pauseButtonClicked:)];
		UIBarButtonItem *removeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(removeButtonClicked:)];
		UIBarButtonItem *_flexSpaceOne = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		UIBarButtonItem *_flexSpaceTwo = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		
		self.editToolbarItems = [NSArray arrayWithObjects:resumeButton, _flexSpaceOne, pauseButton, _flexSpaceTwo, removeButton, nil];
        
		self.title = LocalizedString(@"Transfers");
    }

    return self;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return [self.controller torrentsCount];
    }

    return 0;
}

- (void)tableView:(UITableView *)ftableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (self.tableView.editing == NO) {
		DetailViewController *detailController = [[DetailViewController alloc] initWithTorrent:[self.controller torrentAtIndex:indexPath.row] controller:self.controller];
		[self.navigationController pushViewController:detailController animated:YES];
		[ftableView deselectRowAtIndexPath:indexPath animated:YES];
	}
	else {
		if ([self.selectedIndexPaths count] == 0) {
			for (UIBarButtonItem *item in self.editToolbarItems) {
				[item setEnabled:YES];
			}
		}
		[self.selectedIndexPaths addObject:indexPath];
		TorrentCell *cell = (TorrentCell*)[self.tableView cellForRowAtIndexPath:indexPath];
		[cell.controlButton setEnabled:NO];
	}
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (self.tableView.editing) {
		[self.selectedIndexPaths removeObject:indexPath];

		if ([self.selectedIndexPaths count] == 0) {
			for (UIBarButtonItem *item in self.editToolbarItems) {
				[item setEnabled:NO];
			}
		}

		TorrentCell *cell = (TorrentCell*)[self.tableView cellForRowAtIndexPath:indexPath];
		[cell.controlButton setEnabled:YES];
	}
}

- (UITableViewCell *)tableView:(UITableView *)ftableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger index = indexPath.row;
    
    TorrentCell *cell = (TorrentCell*)[ftableView dequeueReusableCellWithIdentifier:TorrentCellIdentifier];
    
    if (!cell) {
        cell = [TorrentCell cellFromNib];
		[cell.controlButton addTarget:self action:@selector(controlButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
	}
    
    Torrent *t = [self.controller torrentAtIndex:index];
    [self setupCell:cell forTorrent:t];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80.0f; 
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath { 
	return UITableViewCellEditingStyleDelete;
}
       
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	Torrent * torrent = [self.controller torrentAtIndex:indexPath.row];
    self.selectedIndexPaths = [NSMutableArray array];
    [self.selectedIndexPaths addObject:indexPath];
    NSString *msg;
    msg = [NSString stringWithFormat:LocalizedString(@"Are you sure to remove %@ torrent?"), [torrent name]];
    
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:msg delegate:self cancelButtonTitle:LocalizedString(@"Cancel") destructiveButtonTitle:LocalizedString(@"Yes and remove data") otherButtonTitles:LocalizedString(@"Yes but keep data"), nil];
	actionSheet.tag = REMOVE_COMFIRM_TAG;
	[actionSheet showFromToolbar:self.navigationController.toolbar];
}

- (void)addButtonClicked:(id)sender
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:LocalizedString(@"Add from...") delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    [sheet addButtonWithTitle:LocalizedString(@"Web")];
    [sheet addButtonWithTitle:LocalizedString(@"Magnet")];
    [sheet addButtonWithTitle:LocalizedString(@"URL")];
    [sheet addButtonWithTitle:LocalizedString(@"Cancel")];
    [sheet setCancelButtonIndex:3];
    [sheet setTag:ADD_TAG];
    [sheet showFromToolbar:self.navigationController.toolbar];
}

- (void)bandwidthButtonClicked:(id)sender
{
    BandwidthController *c = [[BandwidthController alloc] initWithNibName:@"BandwidthController" bundle:nil];
    c.torrent = nil;
    c.controller = self.controller;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:c];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)infoButtonClicked:(id)sender
{
    InfoViewController *viewController = [InfoViewController infoWithPageName:@"about"];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (void)prefButtonClicked:(id)sender
{
    PrefViewController *prefViewController = [[PrefViewController alloc] initWithNibName:@"PrefViewController" bundle:nil];
    prefViewController.controller = self.controller;
    UINavigationController *prefNav = [[UINavigationController alloc] initWithRootViewController:prefViewController];
    [self presentViewController:prefNav animated:YES completion:nil];
}

- (void)controlButtonClicked:(id)sender
{
    CGPoint pos = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:pos];
	
	Torrent *torrent = [self.controller torrentAtIndex:indexPath.row];
	if ([torrent isActive])
		[torrent stopTransfer];
	else 
		[torrent startTransfer];
	
	[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)setupCell:(TorrentCell*)cell forTorrent:(Torrent*)t
{
	[t update];

	cell.nameLabel.text = [t name];
	cell.upperDetailLabel.text = [t progressString];

	if (![t isChecking]) {
        [cell.progressView setProgress:[t progress]];
    }
    
	if ([t isSeeding])
		[cell useGreenColor];
	else if ([t isChecking]) {
		[cell useGreenColor];
        [cell.progressView setProgress:[t checkingProgress]];
    }
	else if ([t isActive] && ![t isComplete])
		[cell useBlueColor];
	else if (![t isActive])
		[cell useBlueColor];
	else if (![t isChecking])
		[cell useGreenColor];

	if ([t isActive])
		[cell.controlButton setPauseStyle];
	else 
		[cell.controlButton setResumeStyle];

	if (![self.controller isStartingTransferAllowed]) {
		[cell.controlButton setEnabled:NO];
	}
	else {
		[cell.controlButton setEnabled:YES];
	}

	cell.lowerDetailLabel.text = [t statusString];	
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removedTorrents:) name:NotificationTorrentsRemoved object:self.controller];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activityCounterDidChange:) name:NotificationActivityCounterChanged object:self.controller];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newTorrentAdded:) name:NotificationNewTorrentAdded object:self.controller];

    self.activityItemView.backgroundColor = [UIColor clearColor];
    self.activityItem = [[UIBarButtonItem alloc] initWithCustomView:self.activityItemView];
		
	UIButton *_infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
	[_infoButton addTarget:self action:@selector(infoButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
	self.infoButton = [[UIBarButtonItem alloc] initWithCustomView:_infoButton];
	self.navigationItem.rightBarButtonItem = self.infoButton;
	
	self.doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonClicked:)];
	
    [self.activityCounterBadge setBadgeColor:[UIColor colorWithRed:0.82 green:0.0 blue:0.082 alpha:1.000]];
}

- (void)resumeButtonClicked:(id)sender
{
	for (NSIndexPath *indexPath in self.selectedIndexPaths) {
		Torrent *torrent = [self.controller torrentAtIndex:indexPath.row];
		[torrent startTransfer];
	}

	[self.tableView reloadData];

	self.selectedIndexPaths = nil;	
}

- (void)pauseButtonClicked:(id)sender
{
	for (NSIndexPath *indexPath in self.selectedIndexPaths) {
		Torrent *torrent = [self.controller torrentAtIndex:indexPath.row];
		[torrent stopTransfer];
	}

	[self.tableView reloadData];

	self.selectedIndexPaths = nil;
}

- (void)removeButtonClicked:(id)sender
{
	NSString *msg;
	if ([self.selectedIndexPaths count] == 1)
		msg = LocalizedString(@"Are you sure to remove one torrent?");
	else 
		msg = [NSString stringWithFormat:LocalizedString(@"Are you sure to remove %lu torrents?"), (unsigned long)[self.selectedIndexPaths count]];

	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:msg delegate:self cancelButtonTitle:LocalizedString(@"Cancel") destructiveButtonTitle:LocalizedString(@"Yes and remove data") otherButtonTitles:LocalizedString(@"Yes but keep data"), nil];
	actionSheet.tag = REMOVE_COMFIRM_TAG;
	[actionSheet showFromToolbar:self.navigationController.toolbar];
}

- (void)editButtonClicked:(id)sender
{
	for (UIBarButtonItem *item in self.editToolbarItems) {
		[item setEnabled:NO];
	}

	[self.tableView setEditing:YES animated:YES];
	[self.navigationItem setLeftBarButtonItem:self.doneButton animated:YES];
	[self setToolbarItems:self.editToolbarItems animated:YES];
	self.selectedIndexPaths = [NSMutableArray array];
}

- (void)doneButtonClicked:(id)sender
{
	[self.tableView setEditing:NO animated:YES];
	[self.navigationItem setLeftBarButtonItem:self.editButton animated:YES];
	[self setToolbarItems:self.normalToolbarItems animated:YES];
	
	for (NSIndexPath *indexPath in self.selectedIndexPaths) {
		[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
	}
	self.selectedIndexPaths = nil;
}

- (void)updateUI
{
    [super updateUI];

	NSArray *visibleCells = [self.tableView visibleCells];
	
	for (TorrentCell *cell in visibleCells) {
		[self performSelector:@selector(updateCell:) withObject:cell afterDelay:0.0f];
	}
}

- (void)updateCell:(TorrentCell*)c
{
	NSIndexPath *indexPath = [self.tableView indexPathForCell:c];
	if (indexPath) {
		Torrent *torrent = [self.controller torrentAtIndex:indexPath.row];
		[self setupCell:c forTorrent:torrent];
	}
}

- (void)addFromURLClicked
{
    [self addFromURLWithExistingURL:@"" message:LocalizedString(@"Please enter the existing torrent's URL")];
}

- (void)addFromURLWithExistingURL:(NSString*)url message:(NSString*)msg
{
    UIAlertView *dialog = [[UIAlertView alloc] initWithTitle:LocalizedString(@"Add from URL") message:msg delegate:self cancelButtonTitle:LocalizedString(@"Cancel") otherButtonTitles:LocalizedString(@"OK"), nil];
    dialog.delegate = self;
    dialog.tag = ADD_FROM_URL_TAG;
    [dialog addTextFieldWithValue:url label:@"http://"];
    UITextField *textField = [dialog textField];
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.enablesReturnKeyAutomatically = YES;
    textField.keyboardAppearance = UIKeyboardAppearanceDefault;
    textField.keyboardType = UIKeyboardTypeURL;
    textField.returnKeyType = UIReturnKeyDone;
    textField.secureTextEntry = NO;
    [dialog show];
}

- (void)addFromMagnetWithExistingMagnet:(NSString*)magnet message:(NSString*)msg
{
    UIAlertView *dialog = [[UIAlertView alloc] initWithTitle:LocalizedString(@"Add from magnet") message:msg delegate:self cancelButtonTitle:LocalizedString(@"Cancel") otherButtonTitles:LocalizedString(@"OK"), nil];
    dialog.delegate = self;
    dialog.tag = ADD_FROM_MAGNET_TAG;
    [dialog addTextFieldWithValue:magnet label:@"magnet:"];
    UITextField *textField = [dialog textField];
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.enablesReturnKeyAutomatically = YES;
    textField.keyboardAppearance = UIKeyboardAppearanceDefault;
    textField.keyboardType = UIKeyboardTypeURL;
    textField.returnKeyType = UIReturnKeyDone;
    textField.secureTextEntry = NO;
    [dialog show];
}

- (void)activityCounterDidChange:(NSNotification*)notif
{
    NSInteger num = self.controller.activityCounter;
    if (num > 0) {
		self.navigationItem.rightBarButtonItem = self.activityItem;
        self.activityIndicator.hidden = NO;
        [self.activityIndicator startAnimating];
        [self.activityCounterBadge setHidden:NO];
        [self.activityCounterBadge setBadgeNumber:[NSString stringWithFormat:@"%li", (long)num]];
        [self.activityCounterBadge setNeedsDisplay];
    }
    else if (num == 0) {
        [self.activityIndicator stopAnimating];
        self.activityIndicator.hidden = YES;
        [self.activityCounterBadge setHidden:YES];
		self.navigationItem.rightBarButtonItem = self.infoButton;
    }
}

- (void)newTorrentAdded:(NSNotification*)notif
{
    [self.tableView reloadData];
}

- (void)removedTorrents:(NSNotification*)notif
{
	[self.tableView reloadData];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == ADD_FROM_URL_TAG) {
        if (buttonIndex == 0)
            return;
        if (buttonIndex == 1) {
            NSString *url = [[alertView textField] text];
            if (![url hasPrefix:@"http://"] || [url hasPrefix:@"https://"])
                [self addFromURLWithExistingURL:url message:LocalizedString(@"Error: The URL provided is malformed!")];
            else {
                [self.controller addTorrentFromURL:url];
            }
        }
    }
    if (alertView.tag == ADD_FROM_MAGNET_TAG) {
        if (buttonIndex == 0)
            return;
        if (buttonIndex == 1) {
            NSString *magnet = [[alertView textField] text];
            NSError *error = [self.controller addTorrentFromMagnet:magnet];
            if (error)
                [self addFromMagnetWithExistingMagnet:magnet message:[error localizedDescription]];
        }
    }
}

- (void)addFromMagnetClicked
{
    [self addFromMagnetWithExistingMagnet:@"" message:LocalizedString(@"Please enter the magnet link below.")];
}

- (void)addFromWebClicked
{
    NSString *URL = @"https://google.com";
    SVWebViewController *webViewController = [[SVWebViewController alloc] initWithAddress:URL :self.controller :self.navigationController];
	[self.navigationController pushViewController:webViewController animated:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self.navigationController setToolbarHidden:NO animated:animated];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (actionSheet.tag) {
        case ADD_TAG: {
            switch (buttonIndex) {
                case 0:
                {
                    [self addFromWebClicked];
                    break;
                }
                case 1: {
                    [self addFromMagnetClicked];
                    break;
                }
                case 2: {
                    [self addFromURLClicked];
                }
                default: 
                    return;
            }
			break;
        }
		case REMOVE_COMFIRM_TAG: {
			if (buttonIndex == actionSheet.cancelButtonIndex) {
				self.selectedIndexPaths = [NSMutableArray array];
			}
			else {
                [self.tableView setUserInteractionEnabled:NO];
                [self.UIUpdateTimer invalidate];

                __weak __typeof(self) weakSealf = self;

				[self performBlockOnMainQueue:^{
                    NSMutableArray *torrents = [NSMutableArray arrayWithCapacity:[weakSealf.selectedIndexPaths count]];
                    for (NSIndexPath *indexPath in weakSealf.selectedIndexPaths) {
                        Torrent *t = [weakSealf.controller torrentAtIndex:indexPath.row];
                        [torrents addObject:t];
                    }
                    [weakSealf.controller removeTorrents:torrents trashData:(buttonIndex == [actionSheet destructiveButtonIndex])];
                    torrents = nil;

                    weakSealf.selectedIndexPaths = [NSMutableArray array];

                    [weakSealf performBlockOnMainQueue:^{
                        [weakSealf.tableView reloadData];
                        weakSealf.UIUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:weakSealf selector:@selector(updateUI) userInfo:nil repeats:YES];
                        [weakSealf updateUI];
                        [weakSealf.tableView setUserInteractionEnabled:YES];
                    } afterDelay:0.25f];
                } afterDelay:0.25f];
			}
		}
    }
}

@end
