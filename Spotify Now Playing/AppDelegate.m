//
//  AppDelegate.m
//  Spotify Now Playing
//
//  Created by Abel John on 5/14/19.
//  Copyright © 2019 Abel John. All rights reserved.
//

#import "AppDelegate.h"
#import "PFMoveApplication.h"

static NSString * const SNPPlayerStatePreferenceKey = @"SNPPlayerState";
static NSString * const SNPNotificationStatePreferenceKey = @"SNPNotificationState";
static NSString * const SNPMenuIconPreferenceKey = @"SNPMenuIcon";
static NSString * const SNPStartAtLoginPreferenceKey = @"SNPStartAtLogin";
static NSString * const SNPStartupInformationPreferenceKey = @"SNPStartupInformation";
static NSString * const SNPFirstLoginKey = @"SNPFirstLogin";

@interface AppDelegate ()

@property (nonatomic, strong) NSImage *currentAlbumArt;
@property (nonatomic, strong) NSImage *menubarImage;
@property (nonatomic, strong) NSString *currentSongName;
@property (nonatomic, strong) NSString *trackID;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMenuItem *artworkMenuItem;
@property (nonatomic, strong) NSMenuItem *songMenuItem;
@property (nonatomic, strong) NSMenuItem *artistMenuItem;
@property (nonatomic, strong) NSMenuItem *albumMenuItem;
@property (nonatomic, strong) NSMenuItem *playerStateMenuItem;
@property (nonatomic, strong) NSMenuItem *notificationStateMenuItem;
@property (nonatomic, strong) NSMenuItem *menuIconMenuItem;
@property (nonatomic, strong) NSMenuItem *startAtLoginMenuItem;
@property (nonatomic) float panX;
@property (nonatomic) BOOL playing;


@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    PFMoveToApplicationsFolderIfNecessary();
    
    // show welcome screen
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SNPStartupInformationPreferenceKey]) {
        [self helpDialog];
    }
    
    // enable notifications by default on first startup
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SNPFirstLoginKey]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SNPFirstLoginKey];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SNPNotificationStatePreferenceKey];
    }
    
    // load menubar image
    self.menubarImage = [NSImage imageNamed:@"StatusBarIcon"];
    [self.menubarImage setTemplate:YES];
    
    // get app version
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *appVersion = [infoDict objectForKey:@"CFBundleShortVersionString"];
    NSString *appBuild = [infoDict objectForKey:@"CFBundleVersion"];
    
    // initialize status item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    
    // initialize gesture recognizer
    NSPressGestureRecognizer *press = [[NSPressGestureRecognizer alloc] init];
    press.minimumPressDuration = .75;
    press.target = self;
    press.delaysPrimaryMouseButtonEvents = true;
    press.allowableMovement = 50;
    press.action = @selector(longPressHandler:);
    NSPanGestureRecognizer *pan = [[NSPanGestureRecognizer alloc] init];
    pan.action = @selector(panHandler:);
    pan.target = self;
    [self.statusItem.button addGestureRecognizer:press];
    [self.statusItem.button addGestureRecognizer:pan];
    
    // initialize menu containers
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Spotify Now Playing"];
    NSMenu *optionsSubmenu = [[NSMenu alloc] initWithTitle:@"Options"];
    NSMenuItem *optionsMenu = [[NSMenuItem alloc] initWithTitle:@"Options" action:nil keyEquivalent:@""];
    
    // initialize main menu items
    self.artworkMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    self.songMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    self.artistMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    self.albumMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(launchSpotify) keyEquivalent:@""];
    
    // initialize options menu items
    self.playerStateMenuItem = [[NSMenuItem alloc] initWithTitle:@"View play icon in menubar" action:[[NSUserDefaults standardUserDefaults] boolForKey:SNPMenuIconPreferenceKey]?nil:@selector(togglePlayerState) keyEquivalent:@""];
    self.playerStateMenuItem.toolTip = @"Show a play icon in the menu bar when song is playing";
    self.playerStateMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPPlayerStatePreferenceKey];
    self.notificationStateMenuItem = [[NSMenuItem alloc] initWithTitle:@"Song notifications" action:@selector(toggleNotifications) keyEquivalent:@""];
    self.notificationStateMenuItem.toolTip = @"Get a notification when a new song comes on";
    self.notificationStateMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPNotificationStatePreferenceKey];
    self.menuIconMenuItem = [[NSMenuItem alloc] initWithTitle:@"Hide text in menubar" action:@selector(toggleMenuIcon) keyEquivalent:@""];
    self.menuIconMenuItem.toolTip = @"Replaces song title with an icon to save space in the menu bar";
    self.menuIconMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPMenuIconPreferenceKey];
    self.startAtLoginMenuItem = [[NSMenuItem alloc] initWithTitle:@"Start at login" action:@selector(toggleStartAtLogin) keyEquivalent:@""];
    self.startAtLoginMenuItem.toolTip = @"Automatically launch SNP when starting up your computer";
    self.startAtLoginMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPStartAtLoginPreferenceKey];
    
    // set up menus
    [mainMenu addItem:self.artworkMenuItem];
    [mainMenu addItem:self.songMenuItem];
    [mainMenu addItem:self.artistMenuItem];
    [mainMenu addItem:self.albumMenuItem];
    [mainMenu addItem:[NSMenuItem separatorItem]];
    [optionsMenu setSubmenu:optionsSubmenu];
    [optionsSubmenu addItem:self.playerStateMenuItem];
    [optionsSubmenu addItem:self.notificationStateMenuItem];
    [optionsSubmenu addItem:self.menuIconMenuItem];
    [optionsSubmenu addItem:self.startAtLoginMenuItem];
    [mainMenu addItem:optionsMenu];
    [mainMenu addItemWithTitle:@"Help" action:@selector(helpDialog) keyEquivalent:@""];
    [mainMenu addItemWithTitle:@"Quit" action:@selector(quit) keyEquivalent:@"q"];
    [mainMenu addItem:[NSMenuItem separatorItem]];
    [mainMenu addItemWithTitle:@"Spotify Now Playing" action:nil keyEquivalent:@""];
    NSMenuItem *versionMenuItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"v%@ by Abel John", appVersion] action:nil keyEquivalent:@""];
    versionMenuItem.toolTip = [NSString stringWithFormat:@"Build %@", appBuild];
    [mainMenu addItem:versionMenuItem];
    [self.statusItem setMenu:mainMenu];
    // initialize song
    @try {
        self.trackID = [[NSString alloc] initWithString:[[self executeAppleScript:@"get id of current track"] stringValue]];
        self.playing = [[[self executeAppleScript:@"get player state"] stringValue] isEqualToString:@"kPSP"];
        self.currentSongName = [[NSString alloc] initWithString:[[self executeAppleScript:@"get name of current track"] stringValue]];
        // TODO: if Spotify hasn't yet loaded the song name, this will be blank. we could wait a couple seconds and fetch name using applescript
        if (![[NSUserDefaults standardUserDefaults] boolForKey:SNPMenuIconPreferenceKey]) {
            self.statusItem.button.title = ([[NSUserDefaults standardUserDefaults] boolForKey:SNPPlayerStatePreferenceKey] && self.playing)?[NSString stringWithFormat:@"%@ ►",[self shortenedSongName]]:[self shortenedSongName];
            [self preventBlankTitle];
        }
        else {
            self.statusItem.button.title = @"";
            self.statusItem.button.image = self.menubarImage;
        }
        self.songMenuItem.title = self.currentSongName;
        self.artistMenuItem.title = [[self executeAppleScript:@"get artist of current track"] stringValue];
        self.albumMenuItem.title =[[self executeAppleScript:@"get album of current track"] stringValue];
        self.statusItem.button.toolTip = [NSString stringWithFormat:@"%@\n%@\n%@",self.currentSongName,self.artistMenuItem.title,self.albumMenuItem.title];
        [self setImage];
        [self showNotification];
        
    }
    @catch (NSException *e) {
        self.statusItem.button.title = @"";
        self.statusItem.button.image = self.menubarImage;
        self.trackID = @"";
        self.currentSongName = @"";
        self.currentAlbumArt = nil;
        self.artworkMenuItem.image = nil;
        self.artworkMenuItem.title = @"";
        self.artworkMenuItem.action = @selector(launchSpotify);
        self.songMenuItem.title = @"Spotify is not running.";
        self.artistMenuItem.title = @"Click here to open Spotify.";
        self.albumMenuItem.title = @"";
        self.playing = NO;
        self.statusItem.button.toolTip = @"Spotify Now Playing";
    }
    
    // set up notification center
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged:) name:@"com.spotify.client.PlaybackStateChanged" object:nil];
    
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    [self quit];
}

#pragma mark - helper functions

- (void)helpDialog
{
    NSAlert *alert = [[NSAlert alloc] init];
    {
        [alert setMessageText:@"Welcome to Spotify Now Playing!"];
        [alert setInformativeText:@"Spotify Now Playing gives you easy access to see what song is playing in Spotify!\n\nHelp:\nClick on SNP up in the menu bar to see information about the song that's currently playing.\nClick and hold to play/pause, and click and drag right/left to skip/go back.\n\nOptions:\nView play icon in menubar: show a play icon in the menu bar when song is playing.\nSong notifications: get a notification when a new song comes on.\nHide text in menu bar: replaces song title with an icon to save space in the menu bar.\nStart at login: automatically launch SNP when starting up your computer.\n\nEnjoy!\n-Abel John"];
        [alert addButtonWithTitle:@"Okay!"];
        [alert setShowsSuppressionButton:YES];
        NSCell *cell = [[alert suppressionButton] cell];
        [cell setControlSize:NSControlSizeSmall];
        [cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
        [cell setState:[[NSUserDefaults standardUserDefaults] boolForKey:SNPStartupInformationPreferenceKey]];
        [alert runModal];
        if ([[alert suppressionButton] state] == NSControlStateValueOn)
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SNPStartupInformationPreferenceKey];
        else
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SNPStartupInformationPreferenceKey];
    }
}

- (void)playbackStateChanged:(NSNotification *)aNotification
{
    if ([[[aNotification userInfo] objectForKey:@"Player State"] isEqualToString:@"Stopped"]) {
        self.statusItem.button.title = @"";
        self.statusItem.button.image = self.menubarImage;
        self.trackID = @"";
        self.currentSongName = @"";
        self.currentAlbumArt = nil;
        self.artworkMenuItem.image = nil;
        self.artworkMenuItem.title = @"";
        self.artworkMenuItem.action = @selector(launchSpotify);
        self.songMenuItem.title = @"Spotify is not running.";
        self.artistMenuItem.title = @"Click here to open Spotify.";
        self.albumMenuItem.title = @"";
        self.playing = NO;
        self.statusItem.button.toolTip = @"Spotify Now Playing";
    }
    else {
        self.playing = [[[aNotification userInfo] objectForKey:@"Player State"] isEqualToString:@"Playing"];
        if (![[[aNotification userInfo] objectForKey:@"Track ID"] isEqualToString:self.trackID]
            || ![[[aNotification userInfo] objectForKey:@"Name"] isEqualToString:self.currentSongName]) {
            self.trackID = [[aNotification userInfo] objectForKey:@"Track ID"];
            [self setImage];
            self.currentSongName = [[aNotification userInfo] objectForKey:@"Name"];
            if (![[NSUserDefaults standardUserDefaults] boolForKey:SNPMenuIconPreferenceKey]) {
                self.statusItem.button.title = ([[NSUserDefaults standardUserDefaults] boolForKey:SNPPlayerStatePreferenceKey] && self.playing)?[NSString stringWithFormat:@"%@ ►",[self shortenedSongName]]:[self shortenedSongName];
                [self preventBlankTitle];
            }
            self.songMenuItem.title = self.currentSongName;
            self.artistMenuItem.title = [[aNotification userInfo] objectForKey:@"Artist"];
            self.albumMenuItem.title = [[aNotification userInfo] objectForKey:@"Album"];
            self.statusItem.button.toolTip = [NSString stringWithFormat:@"%@\n%@\n%@",self.currentSongName,self.artistMenuItem.title,self.albumMenuItem.title];
            [self showNotification];
        }
        else {
            if (![[NSUserDefaults standardUserDefaults] boolForKey:SNPMenuIconPreferenceKey]) {
                self.statusItem.button.title = ([[NSUserDefaults standardUserDefaults] boolForKey:SNPPlayerStatePreferenceKey] && self.playing)?[NSString stringWithFormat:@"%@ ►",[self shortenedSongName]]:[self shortenedSongName];
                [self preventBlankTitle];
            }
        }
    }
}

- (void)togglePlayerState
{
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:SNPPlayerStatePreferenceKey] forKey:SNPPlayerStatePreferenceKey];
    self.playerStateMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPPlayerStatePreferenceKey];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SNPPlayerStatePreferenceKey] && self.playing) {
        self.statusItem.button.title = [NSString stringWithFormat:@"%@ ►", self.statusItem.button.title];
        self.statusItem.button.image = nil;
    } else if (![[NSUserDefaults standardUserDefaults] boolForKey:SNPPlayerStatePreferenceKey] && self.playing) {
        self.statusItem.button.title = [self shortenedSongName];
        [self preventBlankTitle];
    }
}

- (void)toggleNotifications
{
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:SNPNotificationStatePreferenceKey] forKey:SNPNotificationStatePreferenceKey];
    self.notificationStateMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPNotificationStatePreferenceKey];
}

- (void)toggleMenuIcon
{
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:SNPMenuIconPreferenceKey] forKey:SNPMenuIconPreferenceKey];
    self.menuIconMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPMenuIconPreferenceKey];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SNPMenuIconPreferenceKey]) {
        self.playerStateMenuItem.action = nil;
        self.statusItem.button.title = @"";
        self.statusItem.button.image = self.menubarImage;
    }
    else {
        self.playerStateMenuItem.action = @selector(togglePlayerState);
        self.statusItem.button.title = ([[NSUserDefaults standardUserDefaults] boolForKey:SNPPlayerStatePreferenceKey] && self.playing)?[NSString stringWithFormat:@"%@ ►",[self shortenedSongName]]:[self shortenedSongName];
        [self preventBlankTitle];
    }
}

- (void)toggleStartAtLogin
{
    [[NSUserDefaults standardUserDefaults] setBool:![[NSUserDefaults standardUserDefaults] boolForKey:SNPStartAtLoginPreferenceKey] forKey:SNPStartAtLoginPreferenceKey];
    self.startAtLoginMenuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:SNPStartAtLoginPreferenceKey];
    [self setLoginItem];
}

- (void) setLoginItem
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:SNPStartAtLoginPreferenceKey]) {
        [self enableLoginItem];
    } else {
        [self disableLoginItem];
    }
}

- (NSAppleEventDescriptor *)enableLoginItem
{
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"tell application \"System Events\" to make login item at end with properties {path:\"%@\", hidden:false}", [[NSBundle mainBundle] bundlePath]]];
    return [script executeAndReturnError:NULL];
}

- (NSAppleEventDescriptor *)disableLoginItem
{
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:@"tell application \"System Events\" to delete login item \"Spotify Now Playing\""];
    return [script executeAndReturnError:NULL];
}

- (void)showNotification
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SNPNotificationStatePreferenceKey]) {
        return;
    }
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    if ([self.currentSongName length] == 0) {
        // don't fire notification if we don't know the song name yet
        return;
    }
    
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    
    notification.title = self.currentSongName;
    notification.subtitle = self.artistMenuItem.title;
    notification.informativeText = self.albumMenuItem.title;
    notification.soundName = nil;
    
    [notification setValue:@YES forKey:@"_showsButtons"];
    [notification setValue:@YES forKey:@"_ignoresDoNotDisturb"];
    
    notification.hasActionButton = true;
    notification.actionButtonTitle = @"Skip";
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    center = nil;
    notification = nil;
    return true;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    center = nil;

    NSUserNotificationActivationType num = notification.activationType;
    
    
    if(num == NSUserNotificationActivationTypeActionButtonClicked) {
        [self executeAppleScript:@"next track"];
    }
    else if (num == NSUserNotificationActivationTypeContentsClicked) {
        [[NSWorkspace sharedWorkspace] launchApplication:@"Spotify.app"];
    }
    
}

- (NSString *)shortenedSongName
{
    NSString *nameText = [NSString stringWithString:self.currentSongName];
    for (NSUInteger i = 1; i<[nameText length]; i++) {
        unichar letter = [nameText characterAtIndex:i];
        if ((letter == '-' || letter == '(' || letter == '[' || letter == '/') && [nameText characterAtIndex:(i-1)] == ' ') {
            nameText = [nameText substringToIndex:i];
            break;
        }
    }
    return nameText;
}

- (void)launchSpotify
{
    [[NSWorkspace sharedWorkspace] launchApplication:@"Spotify.app"];
}

- (void)longPressHandler:(NSGestureRecognizer*)sender
{
    if(sender.state == NSGestureRecognizerStateBegan) {
        [self executeAppleScript:@"playpause"];
    }
}

- (void)panHandler:(NSPanGestureRecognizer*)sender
{
    if(sender.state == NSGestureRecognizerStateBegan) {
        self.panX = 0.0;
    }
    self.panX += [sender velocityInView:sender.view].x;
    if(sender.state == NSGestureRecognizerStateEnded) {
        if(self.panX > 3000) {
            [self executeAppleScript:@"next track"];
        }
        else if (self.panX < -3000) {
            [self executeAppleScript:@"previous track"];
        }
    }
}

- (void)setImage
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://embed.spotify.com/oembed/?url=%@", self.trackID]];
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            //NSLog(@"Error,%@", [error localizedDescription]);
            self.artworkMenuItem.image = nil;
            self.artworkMenuItem.title = @"Could not load album artwork";
            self.artworkMenuItem.action = @selector(setImage);
            self.artworkMenuItem.toolTip = @"Click to try again";
        }
        else {
            //NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]);
            NSMutableDictionary *parsedData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            NSURL *imageUrl = [NSURL URLWithString:parsedData[@"thumbnail_url"]];
            NSURLRequest *imageUrlRequest = [NSURLRequest requestWithURL:imageUrl];
            NSURLSession *imageSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
            NSURLSessionDataTask *imageTask = [imageSession dataTaskWithRequest:imageUrlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    //NSLog(@"Error,%@", [error localizedDescription]);
                    self.artworkMenuItem.image = nil;
                    self.artworkMenuItem.title = @"Could not load album artwork";
                    self.artworkMenuItem.action = @selector(setImage);
                    self.artworkMenuItem.toolTip = @"Click to try again";

                }
                else {
                    self.currentAlbumArt = [[NSImage alloc] initWithData:data];
                    self.currentAlbumArt.size = CGSizeMake(200, 200);
                    self.artworkMenuItem.image = self.currentAlbumArt;
                    self.artworkMenuItem.title = @"";
                    self.artworkMenuItem.action = @selector(launchSpotify);
                    self.artworkMenuItem.toolTip = nil;

                }
            }];
            [imageTask resume];
        }
    }];
    [task resume];
}

- (void)preventBlankTitle
{
    if ([self.statusItem.button.title length] != 0) {
        self.statusItem.button.image = nil;
    } else {
        // if the menubar has no text then display the icon so the user can see where the app is
        self.statusItem.button.image = self.menubarImage;
    }
}

- (NSAppleEventDescriptor *)executeAppleScript:(NSString *)command
{
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"if application \"Spotify\" is running then tell application \"Spotify\" to %@", command]];
    return [script executeAndReturnError:NULL];
}

- (void)quit
{
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeAllDeliveredNotifications];
    [[NSApplication sharedApplication] terminate:self];
}
@end
