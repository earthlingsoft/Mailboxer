//
//  Magic.h
//  Mailboxer
//
//  Created by  Sven on 24.03.06.
//  Copyright 2006 earthlingsoft. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#include <uuid/uuid.h>
#include "VersionChecker.h"

#define MENUNAME @"NAME"
#define MENUOBJECT @"OBJECT"
#define MENUITEMALL @"ALL"
#define ALLDICTIONARY [NSDictionary dictionaryWithObjectsAndKeys:MENUITEMALL, MENUOBJECT, NSLocalizedString(@"All Contacts", @"All Contacts"), MENUNAME, nil]

@interface Magic : NSObject {
	NSAttributedString * infoText2;
	NSArray * groups;
	BOOL running;
	BOOL mailIsRunningCache;
	BOOL firstNameFirst;
	NSArray * sortCriteria;
	NSDictionary * mailboxUserInfo;
	NSDictionary * myStringAttributes;
}

@property (readonly) NSImage * vcardIcon;
@property (readonly) NSImage * AddressBookIcon;
@property (readonly) NSImage * smartFolderIcon;
@property (readonly) BOOL mailIsRunning;

- (id) init;
- (void) buildGroupList;
- (IBAction) do:(id) sender;
- (NSDictionary *) ruleDictionaryForPerson:(ABPerson*) person;
- (NSString *) updateInfoText;
- (NSString*) uuid;
- (IBAction) readme:(id) sender;
- (NSString*) myVersionString;
- (void) error: (NSString*) error;
- (IBAction) menuCheckVersion:(id)sender;
@end

@interface ABGroup (ESSortExtension)
- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup ;
@end