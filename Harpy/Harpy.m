//
//  Harpy.m
//  Harpy
//
//  Created by Arthur Ariel Sabintsev on 11/14/12.
//  Copyright (c) 2012 Arthur Ariel Sabintsev. All rights reserved.
//

#import "Harpy.h"

/// NSUserDefault macros to store user's preferences for HarpyAlertTypeSkip
#define HARPY_DEFAULT_SHOULD_SKIP_VERSION           @"Harpy Should Skip Version Boolean"
#define HARPY_DEFAULT_SKIPPED_VERSION               @"Harpy User Decided To Skip Version Update Boolean"
#define HARPY_DEFAULT_STORED_VERSION_CHECK_DATE     @"Harpy Stored Date From Last Version Check"

/// i18n/l10n macros
#define HARPY_CURRENT_VERSION                       [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
#define HARPY_BUNDLE_PATH                           [[NSBundle mainBundle] pathForResource:@"Harpy" ofType:@"bundle"]
#define HARPY_LOCALIZED_STRING(stringKey)           [[NSBundle bundleWithPath:HARPY_BUNDLE_PATH] localizedStringForKey:stringKey value:stringKey table:@"HarpyLocalizable"]
#define HARPY_FORCED_BUNDLE_PATH                    [[NSBundle bundleWithPath:HARPY_BUNDLE_PATH] pathForResource:[self forceLanguageLocalization] ofType:@"lproj"]
#define HARPY_FORCED_LOCALIZED_STRING(stringKey)    [[NSBundle bundleWithPath:HARPY_FORCED_BUNDLE_PATH] localizedStringForKey:stringKey value:stringKey table:@"HarpyLocalizable"]

/// App Store links
#define HARPY_APP_STORE_LINK_UNIVERSAL              @"http://itunes.apple.com/lookup?id=%@"
#define HARPY_APP_STORE_LINK_COUNTRY_SPECIFIC       @"http://itunes.apple.com/lookup?id=%@&country=%@"

/// JSON parsing
#define HARPY_APP_STORE_RESULTS                     [self.appData valueForKey:@"results"]

/// i18n/l10n constants
NSString * const HarpyLanguageBasque = @"eu";
NSString * const HarpyLanguageChineseSimplified = @"zh-Hans";
NSString * const HarpyLanguageChineseTraditional = @"zh-Hant";
NSString * const HarpyLanguageDanish = @"da";
NSString * const HarpyLanguageDutch = @"nl";
NSString * const HarpyLanguageEnglish = @"en";
NSString * const HarpyLanguageFrench = @"fr";
NSString * const HarpyLanguageGerman = @"de";
NSString * const HarpyLanguageItalian = @"it";
NSString * const HarpyLanguageJapanese = @"ja";
NSString * const HarpyLanguageKorean = @"ko";
NSString * const HarpyLanguagePortuguese = @"pt";
NSString * const HarpyLanguageRussian = @"ru";
NSString * const HarpyLanguageSlovenian = @"sl";
NSString * const HarpyLanguageSpanish = @"es";

@interface Harpy() <UIAlertViewDelegate>

@property (strong, nonatomic) NSDictionary *appData;
@property (strong, nonatomic) NSDate *lastVersionCheckPerformedOnDate;

@end

@implementation Harpy

#pragma mark - Initialization
+ (Harpy *)sharedInstance
{
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _alertType = HarpyAlertTypeOption;
        _lastVersionCheckPerformedOnDate = [[NSUserDefaults standardUserDefaults] objectForKey:HARPY_DEFAULT_STORED_VERSION_CHECK_DATE];
    }
    return self;
}

#pragma mark - Public
- (void)checkVersion
{
    // Asynchronously query iTunes AppStore for publically available version
    NSString *storeString = nil;
    if ([self countryCode]) {
        storeString = [NSString stringWithFormat:HARPY_APP_STORE_LINK_COUNTRY_SPECIFIC, _appID, _countryCode];
    } else {
        storeString = [NSString stringWithFormat:HARPY_APP_STORE_LINK_UNIVERSAL, _appID];
    }
    
    NSURL *storeURL = [NSURL URLWithString:storeString];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:storeURL];
    [request setHTTPMethod:@"GET"];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];

    if ([self isDebugEnabled]) {
        NSLog(@"[Harpy] storeURL: %@", storeURL);
    }
    
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        
        if ([data length] > 0 && !error) { // Success
            
            self.appData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];

            if ([self isDebugEnabled]) {
                NSLog(@"[Harpy] JSON Results: %@", _appData);
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // Store version comparison date
                self.lastVersionCheckPerformedOnDate = [NSDate date];
                [[NSUserDefaults standardUserDefaults] setObject:[self lastVersionCheckPerformedOnDate] forKey:HARPY_DEFAULT_STORED_VERSION_CHECK_DATE];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                // All versions that have been uploaded to the AppStore
                NSArray *versionsInAppStore = [HARPY_APP_STORE_RESULTS valueForKey:@"version"];
                
                if ([versionsInAppStore count]) {
                    NSString *currentAppStoreVersion = [versionsInAppStore objectAtIndex:0];
                    [self checkIfAppStoreVersionIsNewestVersion:currentAppStoreVersion];
                }
            });
        }
    }];
}

- (void)checkVersionDaily
{
    /*
     On app's first launch, lastVersionCheckPerformedOnDate isn't set.
     Avoid false-positive fulfilment of second condition in this method.
     Also, performs version check on first launch.
     */
    if (![self lastVersionCheckPerformedOnDate]) {
        
        // Set Initial Date
        self.lastVersionCheckPerformedOnDate = [NSDate date];
        
        // Perform First Launch Check
        [self checkVersion];
    }
    
    // If daily condition is satisfied, perform version check
    if ([self numberOfDaysElapsedBetweenLastVersionCheckDate] > 1) {
        [self checkVersion];
    }
}

- (void)checkVersionWeekly
{
    /*
     On app's first launch, lastVersionCheckPerformedOnDate isn't set.
     Avoid false-positive fulfilment of second condition in this method.
     Also, performs version check on first launch.
     */
    if (![self lastVersionCheckPerformedOnDate]) {
        
        // Set Initial Date
        self.lastVersionCheckPerformedOnDate = [NSDate date];
        
        // Perform First Launch Check
        [self checkVersion];
    }
    
    // If weekly condition is satisfied, perform version check 
    if ([self numberOfDaysElapsedBetweenLastVersionCheckDate] > 7) {
        [self checkVersion];
    }
}

#pragma mark - Private
- (NSUInteger)numberOfDaysElapsedBetweenLastVersionCheckDate
{
    NSCalendar *currentCalendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [currentCalendar components:NSCalendarUnitDay
                                                      fromDate:[self lastVersionCheckPerformedOnDate]
                                                        toDate:[NSDate date]
                                                       options:0];
    return [components day];
}

- (void)checkIfAppStoreVersionIsNewestVersion:(NSString *)currentAppStoreVersion
{
    // Current installed version is the newest public version or newer (e.g., dev version)
    if ([HARPY_CURRENT_VERSION compare:currentAppStoreVersion options:NSNumericSearch] == NSOrderedAscending) {
        [self alertTypeForVersion:currentAppStoreVersion];
        [self showAlertIfCurrentAppStoreVersionNotSkipped:currentAppStoreVersion];
    }
}

- (void)showAlertIfCurrentAppStoreVersionNotSkipped:(NSString *)currentAppStoreVersion
{
    // Check if user decided to skip this version in the past
    BOOL shouldSkipVersionUpdate = [[NSUserDefaults standardUserDefaults] boolForKey:HARPY_DEFAULT_SHOULD_SKIP_VERSION];
    NSString *storedSkippedVersion = [[NSUserDefaults standardUserDefaults] objectForKey:HARPY_DEFAULT_SKIPPED_VERSION];
    
    if (!shouldSkipVersionUpdate) {
        [self showAlertWithAppStoreVersion:currentAppStoreVersion];
    } else if (shouldSkipVersionUpdate && ![storedSkippedVersion isEqualToString:currentAppStoreVersion]) {
        [self showAlertWithAppStoreVersion:currentAppStoreVersion];
    } else {
        // Don't show alert.
        return;
    }
}

- (void)showAlertWithAppStoreVersion:(NSString *)currentAppStoreVersion
{
    // Reference App's name
    NSString *appName = ([self appName]) ? [self appName] : [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleNameKey];
    
    // Force localization if _forceLanguageLocalization is set
    NSString *updateAvailableMessage, *newVersionMessage, *updateButtonText, *nextTimeButtonText, *skipButtonText;
    if ([self forceLanguageLocalization]) {
        updateAvailableMessage = HARPY_FORCED_LOCALIZED_STRING(@"Update Available");
        newVersionMessage = [NSString stringWithFormat:HARPY_FORCED_LOCALIZED_STRING(@"A new version of %@ is available. Please update to version %@ now."), appName, currentAppStoreVersion];
        updateButtonText = HARPY_FORCED_LOCALIZED_STRING(@"Update");
        nextTimeButtonText = HARPY_FORCED_LOCALIZED_STRING(@"Next time");
        skipButtonText = HARPY_FORCED_LOCALIZED_STRING(@"Skip this version");
    } else {
        updateAvailableMessage = HARPY_LOCALIZED_STRING(@"Update Available");
        newVersionMessage = [NSString stringWithFormat:HARPY_LOCALIZED_STRING(@"A new version of %@ is available. Please update to version %@ now."), appName, currentAppStoreVersion];
        updateButtonText = HARPY_LOCALIZED_STRING(@"Update");
        nextTimeButtonText = HARPY_LOCALIZED_STRING(@"Next time");
        skipButtonText = HARPY_LOCALIZED_STRING(@"Skip this version");
    }

    // Initialize UIAlertView
    UIAlertView *alertView;
    
    // Show Appropriate UIAlertView
    switch ([self alertType]) {
            
        case HarpyAlertTypeForce: {
            
            alertView = [[UIAlertView alloc] initWithTitle:updateAvailableMessage
                                                   message:newVersionMessage
                                                  delegate:self
                                         cancelButtonTitle:updateAvailableMessage
                                         otherButtonTitles:nil, nil];
            
        } break;
            
        case HarpyAlertTypeOption: {
            
           alertView = [[UIAlertView alloc] initWithTitle:updateAvailableMessage
                                                  message:newVersionMessage
                                                 delegate:self
                                        cancelButtonTitle:nextTimeButtonText
                                        otherButtonTitles:updateButtonText, nil];
            
        } break;
            
        case HarpyAlertTypeSkip: {
            
            // Store currentAppStoreVersion in case user pushes skip
            [[NSUserDefaults standardUserDefaults] setObject:currentAppStoreVersion forKey:HARPY_DEFAULT_SKIPPED_VERSION];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            alertView = [[UIAlertView alloc] initWithTitle:updateAvailableMessage
                                                   message:newVersionMessage
                                                  delegate:self
                                         cancelButtonTitle:skipButtonText
                                         otherButtonTitles:updateButtonText, nextTimeButtonText, nil];
            
        } break;

        case HarpyAlertTypeNone: { // Do Nothing
        } break;
    }
    
    [alertView show];

    if([self.delegate respondsToSelector:@selector(harpyDidShowUpdateDialog)]){
        [self.delegate harpyDidShowUpdateDialog];
    }
}

- (void)launchAppStore
{
    NSString *iTunesString = [NSString stringWithFormat:@"https://itunes.apple.com/app/id%@", [self appID]];
    NSURL *iTunesURL = [NSURL URLWithString:iTunesString];
    [[UIApplication sharedApplication] openURL:iTunesURL];

    if([self.delegate respondsToSelector:@selector(harpyUserDidLaunchAppStore)]){
        [self.delegate harpyUserDidLaunchAppStore];
    }
}

- (void)alertTypeForVersion:(NSString *)currentAppStoreVersion
{
    
    // Check what version the update is, major, minor or a patch
    NSArray *oldVersionComponents = [HARPY_CURRENT_VERSION componentsSeparatedByString:@"."];
    NSArray *newVersionComponents = [currentAppStoreVersion componentsSeparatedByString: @"."];
    
    if ([oldVersionComponents count] == 3 && [newVersionComponents count] == 3) {
        if ([newVersionComponents[0] integerValue] > [oldVersionComponents[0] integerValue]) { // A.b.c
            if (_majorUpdateAlertType) _alertType = _majorUpdateAlertType;
        } else if ([newVersionComponents[1] integerValue] > [oldVersionComponents[1] integerValue]) { // a.B.c
            if (_minorUpdateAlertType) _alertType = _minorUpdateAlertType;
        } else if ([newVersionComponents[2] integerValue] > [oldVersionComponents[2] integerValue]) { // a.b.C
           if (_patchUpdateAlertType) _alertType = _patchUpdateAlertType;
        }
    }
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch ([self alertType]) {
            
        case HarpyAlertTypeForce: { // Launch App Store.app

            [self launchAppStore];

        } break;
            
        case HarpyAlertTypeOption: {
            
            if (buttonIndex == 1) { // Launch App Store.app
                [self launchAppStore];
            } else { // Ask user on next launch
                if([self.delegate respondsToSelector:@selector(harpyUserDidCancel)]){
                    [self.delegate harpyUserDidCancel];
                }
            }
            
        } break;
            
        case HarpyAlertTypeSkip: {
            
            if (buttonIndex == 0) { // Skip current version in AppStore
            
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:HARPY_DEFAULT_SHOULD_SKIP_VERSION];
                [[NSUserDefaults standardUserDefaults] synchronize];

                if([self.delegate respondsToSelector:@selector(harpyUserDidSkipVersion)]){
                    [self.delegate harpyUserDidSkipVersion];
                }
                
            } else if (buttonIndex == 1) { // Launch App Store.app
                [self launchAppStore];
            } else if (buttonIndex == 2) { // Ask user on next launch
                if([self.delegate respondsToSelector:@selector(harpyUserDidCancel)]){
                    [self.delegate harpyUserDidCancel];
                }
            }
        } break;

        case HarpyAlertTypeNone: {
            // Do nothing
        } break;
    }
}

@end
