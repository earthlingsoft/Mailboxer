/* VersionChecker */

#import <Cocoa/Cocoa.h>

@interface VersionChecker : NSObject {
    NSURL *url;
    NSMutableDictionary *infoDict;
    NSMutableData *_data;

    BOOL silentCheck;
}

+ (id)versionChecker;
+ (id)versionCheckerWithURL:(NSURL *)inURL;
+ (id)versionCheckerWithURLString:(NSString *)inString;

+ (void)checkVersionForURL:(NSURL *)inURL silent:(BOOL)silent;
+ (void)checkVersionForURLString:(NSString *)inString silent:(BOOL)silent;

- (id)initWithURL:(NSURL *)inURL; // designated initialiser - the current app version is taken to be either the CFBundleVersion or CFBundleShortVersionString entry in the main bundle's Info.plist file. if both are nil version is assumed to be "0". You can also use -setCurrentVersion: if you need custom behaviour.
- (id)initWithURLString:(NSString *)inString;

- (IBAction)checkVersion:(id)sender; // does the lookup, asks the user to download if necessary and reports errors
- (IBAction)checkVersionSilent:(id)sender;

     // use -setURL: or -setURLString if you instantiated VersionChecker with -init rather than -initWithURL: or -initWithString:
- (void)setURL:(NSURL *)inURL;
- (void)setURLString:(NSString *)inStr;
- (NSURL *)url;

// these methods should not be used in the final application they help you creating the version info files for putting on the web
+ (void)writeVersionFileWithDownloadURL:(NSURL *)inURL;
+ (void)writeVersionFileWithDownloadURLString:(NSString *)inString;
- (void)setDownloadURLString:(NSString *)string; // set url of the latest version
- (void)setDownloadURL:(NSURL *)inURL; // set url of the latest version
- (void)setCurrentVersion:(NSString *)string; // set latest version
- (NSString *)currentVersion; // the current version as determined when the receiver was instantiated or set by -setCurrentVersion:
- (NSString *)fileDescription; // shows the contents of the version check file to put on the web
- (BOOL)writeToFile; // opens a NSSavePanel and saves the version check file to put on the web
@end
