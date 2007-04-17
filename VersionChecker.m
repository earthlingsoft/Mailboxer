#import "VersionChecker.h"
#include <unistd.h>

static NSString *EVCVersionKey = @"Version";
static NSString *EVCURLKey = @"URL";

@interface VersionChecker (PrivateMethods)
- (BOOL)newerVersionInDictionary:(NSDictionary *)newDict;
- (void)internalCheckVersionSilent:(BOOL)silent;
@end

@implementation VersionChecker

+ (id)versionChecker {
    return [self versionCheckerWithURL:nil];
}

+ (id)versionCheckerWithURL:(NSURL *)inURL {
    return [[[self alloc] initWithURL:inURL] autorelease];
}
+ (id)versionCheckerWithURLString:(NSString *)inString {
    return [[[self alloc] initWithURLString:inString] autorelease];
}

+ (void)checkVersionForURL:(NSURL *)inURL silent:(BOOL)silent {
    VersionChecker *vc = [self versionCheckerWithURL:inURL];
    [vc internalCheckVersionSilent:silent];
}
+ (void)checkVersionForURLString:(NSString *)inString silent:(BOOL)silent {
    VersionChecker *vc = [self versionCheckerWithURLString:inString];
    [vc internalCheckVersionSilent:silent];
}

+ (void)writeVersionFileWithDownloadURL:(NSURL *)inURL {
    [self writeVersionFileWithDownloadURLString:[inURL absoluteString]];
}
+ (void)writeVersionFileWithDownloadURLString:(NSString *)inString {
    VersionChecker *vc = [self versionChecker];
    [vc setDownloadURLString:inString];
    [vc writeToFile];
}

- (id)init {
    return [self initWithURL:nil];
}
- (id)initWithURLString:(NSString *)inString {
    return [self initWithURL:[NSURL URLWithString:inString]];
}
- (id)initWithURL:(NSURL *)inURL {
    self = [super init];
    if(self) {
        NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        if(!version)
            version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        if(!version)
            version = @"0";
        infoDict = [[NSMutableDictionary alloc] initWithCapacity:5];
        [self setCurrentVersion:version];
        [self setURL:inURL];
        _data = [[NSMutableData alloc] init];
    }
    return self;
}

- (void)dealloc {
    [url autorelease];
    [infoDict release];
    [_data release];
    [super dealloc];
}

- (IBAction)checkVersion:(id)sender {
    [self internalCheckVersionSilent:NO];
}
- (IBAction)checkVersionSilent:(id)sender {
    [self internalCheckVersionSilent:YES];
}

- (void)internalCheckVersionSilent:(BOOL)silent {
    [self retain]; // if the user autoreleased us, make sure we are still there when the resource is loaded
    silentCheck = silent;
    [url loadResourceDataNotifyingClient:self usingCache:NO];
}

- (void)setURL:(NSURL *)inURL {
    [url autorelease];
    url = [inURL copy];
}
- (void)setURLString:(NSString *)inStr {
    [self setURL:[NSURL URLWithString:inStr]];
}
- (NSURL *)url {
    return url;
}

- (void)URL:(NSURL *)sender resourceDataDidBecomeAvailable:(NSData *)newBytes {
    [_data appendData:newBytes];
}

- (void)URLResourceDidFinishLoading:(NSURL *)sender {
    int result;
    //NSDictionary *newDict = [NSDictionary dictionaryWithContentsOfURL:sender];
    NSDictionary *newDict = [[[[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding] autorelease] propertyList];

    [self autorelease];

    if([self newerVersionInDictionary:newDict]) {
        BOOL downloadAvailable = NO;
        NSString *defaultButton, *alternateButton, *newVersionMsg;
        NSString *downloadURL = [newDict objectForKey:EVCURLKey];

        if(downloadURL != nil) {
            downloadAvailable = YES;
            newVersionMsg = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ %@ is available. Do you want to download this version now?", @"VersionChecker", @"New Version Dialog Text With Download Option (1st escape is CFBundleName 2nd is CFBundleVersion)"),
                [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"], [newDict objectForKey:EVCVersionKey]];
            defaultButton = NSLocalizedStringFromTable(@"Download", @"VersionChecker", @"New Version Dialog Download Button");
            alternateButton = NSLocalizedStringFromTable(@"Cancel", @"VersionChecker", @"New Version Dialog Cancel Button");
        } else {
            downloadAvailable = NO;
            newVersionMsg = [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ %@ is available.", @"VersionChecker", @"New Version Dialog Text Without Download Option (1st escape is CFBundleName 2nd is CFBundleVersion)"),
                [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"], [newDict objectForKey:EVCVersionKey]];
            defaultButton = NSLocalizedStringFromTable(@"OK", @"VersionChecker", @"No New Version Dialog OK Button");
            alternateButton = @"";
        }
        
        result = NSRunAlertPanel(NSLocalizedStringFromTable(@"New Version Available", @"VersionChecker", @"New Version Dialog Title"),
                                 newVersionMsg,
                        defaultButton, alternateButton, @"");
        if(downloadAvailable && result == NSAlertDefaultReturn) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:downloadURL]];
        }
    } else {
        if(!silentCheck) {
            NSRunAlertPanel(NSLocalizedStringFromTable(@"No New Version Available", @"VersionChecker", @"No New Version Dialog Title"),
                            [NSString stringWithFormat:NSLocalizedStringFromTable(@"You are running the latest version of %@.", @"VersionChecker", @"No New Version Dialog Text (1st escape is CFBundleName)"),
                                [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]],
                            NSLocalizedStringFromTable(@"OK", @"VersionChecker", @"No New Version Dialog Default Button"),
                            @"", @"");
        }
    }
}
- (void)URLResourceDidCancelLoading:(NSURL *)sender {
    // should not be called
    [self autorelease];
}
- (void)URL:(NSURL *)sender resourceDidFailLoadingWithReason:(NSString *)reason {
    [self autorelease];
    NSLog(@"fail: %i", self);
    if(!silentCheck) {
        NSRunAlertPanel(NSLocalizedStringFromTable(@"Version Check Failed", @"VersionChecker", @"Version Check Failed Dialog Title"),
                        [NSString stringWithFormat:NSLocalizedStringFromTable(@"Reason: %@", @"VersionChecker", @"Version Check Failed Dialog Title (1st escape is the reason which is localized in AppKit)"),
                            reason],
                        NSLocalizedStringFromTable(@"OK", @"VersionChecker", @"Version Check Failed Dialog Default Button")
                        , @"", @"");
    }
}

- (void)setDownloadURL:(NSURL *)inURL {
    [self setDownloadURLString:[inURL absoluteString]];
}
- (void)setDownloadURLString:(NSString *)string {
    [infoDict setObject:string forKey:EVCURLKey];
}
- (void)setCurrentVersion:(NSString *)string {
    [infoDict setObject:string forKey:EVCVersionKey];
}
- (NSString *)currentVersion {
    return [infoDict objectForKey:EVCVersionKey];
}
- (NSString *)downloadURLString {
    return [infoDict objectForKey:EVCURLKey];
}
- (NSURL *)downloadURL {
    return [NSURL URLWithString:[self downloadURLString]];
}

- (NSString *)fileDescription {
    NSString *tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"VersionChecker PList.tmp"];
    NSString *contentsOfTempFile;
    if([infoDict writeToFile:tempFile atomically:YES]) {
        contentsOfTempFile = [NSString stringWithContentsOfFile:tempFile];
        unlink([tempFile UTF8String]);
        return contentsOfTempFile;
    }
    return @"--- An Error Occured: Could not write temporary file ---";
    //return [[NSArchiver archivedDataWithRootObject:infoDict] description];
    //return [[NSSerializer serializePropertyList:infoDict] description];
    //return [[[NSString alloc] initWithData:[NSArchiver archivedDataWithRootObject:infoDict] encoding:NSUTF8StringEncoding] autorelease];
}

- (BOOL)writeToFile {
    NSSavePanel *s = [NSSavePanel savePanel];
    int result = [s runModal];

    if(result == NSOKButton) {
        return [infoDict writeToFile:[s filename] atomically:YES];
    }
    return YES;
}

- (BOOL)newerVersionInDictionary:(NSDictionary *)newDict {
    NSString *oldVersion = [infoDict objectForKey:EVCVersionKey];
    NSString *newVersion = [newDict objectForKey:EVCVersionKey];

    if(![oldVersion isEqualToString:newVersion])
        return YES;

    return NO;
}
@end
