//
//  Magic.m
//  Mailboxer
//
//  Created by  Sven on 24.03.06.
//  Copyright 2006 earthlingsoft. All rights reserved.
//
//

#import "Magic.h"
#define UDC [NSUserDefaultsController sharedUserDefaultsController]

@implementation Magic


- (id) init {
	[super init];
	[self buildGroupList];
	
	// handle defaults
	[self setValue: [NSArray arrayWithObjects: 
		[NSDictionary dictionaryWithObjectsAndKeys:	
			NSLocalizedString(@"Date Received", @"Date Received"), MENUNAME,
			@"received-date", MENUOBJECT, nil], 
//		[NSDictionary dictionaryWithObjectsAndKeys:
//			NSLocalizedString(@"Sender", @"Sender"), MENUNAME, 
//			@"sender", MENUOBJECT, nil], 
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Mailbox", @"Mailbox"), MENUNAME,
			@"location", MENUOBJECT, nil],
		[NSDictionary dictionaryWithObjectsAndKeys:
			NSLocalizedString(@"Subject", @"Subject"), MENUNAME, 
			@"subject", MENUOBJECT, nil],
		nil] 
			forKey:@"sortCriteria"];
					
	NSDictionary * standardDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES], @"includeCCs", 
		ALLDICTIONARY, @"selectedGroup", 		 
		@"Mailboxer", @"folderName",   
		[NSDictionary dictionaryWithObjectsAndKeys:	
			NSLocalizedString(@"Date Received", @"Date Received"), MENUNAME,
			@"received-date", MENUOBJECT, nil], @"sortOrder",
		[NSNumber numberWithInt:1], @"sortDirection",
		[NSNumber numberWithBool:YES], @"threadedDisplay",
		[NSNumber numberWithBool:YES], @"includeSentMessages",
		[NSNumber numberWithBool:YES], @"includeTrashedMessages",
		nil];
	
	[UDC setInitialValues:standardDefaults];	
	[UDC addObserver:self forKeyPath:@"values.selectedGroup" options:NSKeyValueObservingOptionNew context:nil];
	[UDC addObserver:self forKeyPath:@"values.folderName" options:NSKeyValueObservingOptionNew context:nil];
	[UDC addObserver:self forKeyPath:@"values.includeCCs" options:NSKeyValueObservingOptionNew context:nil];
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addressBookChanged:) name:kABDatabaseChangedExternallyNotification  object:nil];
	NSNotificationCenter * NC = [[NSWorkspace sharedWorkspace] notificationCenter];	
	[NC addObserver:self selector:@selector(MailChanged:) name:NSWorkspaceDidLaunchApplicationNotification  object:nil];
	[NC addObserver:self selector:@selector(MailChanged:) name:NSWorkspaceDidTerminateApplicationNotification  object:nil];
		
	// Read AB Prefs for name order and use them
	firstNameFirst = YES;
	NSDictionary * ABPrefs = [NSDictionary dictionaryWithContentsOfFile:[@"~/Library/Preferences/com.apple.AddressBook.plist" stringByExpandingTildeInPath]];
	if (ABPrefs) {
		NSNumber * myNum = [ABPrefs objectForKey:@"ABNameDisplay"];
		if (myNum) {
			firstNameFirst = ([myNum intValue] == 0);
		}
	}	
	
	// setup paragraph style for info text
	
	NSFont *stringFont = [NSFont fontWithName:@"Lucida Grande" size:11.0];
	NSMutableParagraphStyle * myParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[myParagraphStyle setHeadIndent:20.0];
	[myParagraphStyle setFirstLineHeadIndent:0.0];
	NSTextTab * myTab = [[[NSTextTab alloc] initWithType:NSLeftTabStopType location:11.0] autorelease];
	[myParagraphStyle setTabStops:[NSArray arrayWithObject: myTab]];
	NSDictionary * theStringAttributes = [NSDictionary dictionaryWithObjectsAndKeys:stringFont, NSFontAttributeName, myParagraphStyle, NSParagraphStyleAttributeName, nil];
	[self setValue:theStringAttributes  forKey:@"myStringAttributes"];
	
	[self updateInfoText];
	
	// look whether there are updates if necessary
	if ( [[UDC valueForKeyPath:@"values.lookForUpdate"] boolValue] ) {
		[VersionChecker checkVersionForURLString:@"http://www.earthlingsoft.net/Mailboxer/Mailboxer.xml" silent:YES];
	}
	
	return self;
}



- (void) dealloc {
	[infoText2 release];
	[groups release];
	[sortCriteria release];
	[mailboxUserInfo release];
	[myStringAttributes release];
	
	[super dealloc];
}




/*
	Rebuilds the Group list from the Address Book and re-sets the selection in case the selected object ceased existing after the rebuild.
*/
- (void) buildGroupList {
	// rebuild the group list
	ABAddressBook * ab = [ABAddressBook sharedAddressBook];
	NSMutableArray * a = [NSMutableArray arrayWithCapacity:[groups count] +1 ]; 
	
	NSArray * ABGroups = [ab groups];
	ABGroups = [ABGroups sortedArrayUsingSelector:@selector(groupByNameCompare:)];
	
	[a addObject:ALLDICTIONARY];
	NSEnumerator * myEnum = [ABGroups objectEnumerator];
	ABGroup * group;
	while (group = [myEnum nextObject]) {
		[a addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[group uniqueId], MENUOBJECT, 
			[group valueForProperty:kABGroupNameProperty], MENUNAME, 
			nil]
		];
	}
	[self setValue:a forKey:@"groups"];
	
	// look whether the selected item still exists. If it doesn't reset to ALL group
	NSString * selectedGroup = (NSString*) [[UDC valueForKeyPath:@"values.selectedGroup"] objectForKey:MENUOBJECT];
	if ([selectedGroup hasSuffix:@":ABGroup"] || [selectedGroup hasSuffix:@":ABSmartGroup"]) {
		ABGroup * myGroup = (ABGroup*) [ab recordForUniqueId:selectedGroup];
		if (!myGroup) {
			// the group doesn't exist anymore => switch to all
			[UDC setValue:ALLDICTIONARY forKeyPath:@"values.selectedGroup"];
		}
	}
}


- (IBAction) do:(id) sender{
	[self setValue:[NSNumber numberWithBool:YES] forKey:@"running"];
	// First off, quit Mail if it is running
	[sender setTitle:NSLocalizedString(@"Quitting Mail",@"Quitting Mail") ];
	[sender setEnabled:NO];
	[sender display];
	BOOL didQuitMail = NO;
	if ([[self valueForKey:@"mailIsRunning"] boolValue]) {
		NSAppleScript * myScript = [[NSAppleScript alloc] initWithSource:@"tell application \"Mail\" to quit\n"];
		[myScript executeAndReturnError:nil];
		[myScript release];
		didQuitMail = YES;
	}
	
	// Collect data from address book
	[sender setTitle:NSLocalizedString(@"Processing Address Book", @"Processing AddressBook")];
	[sender display];
	ABAddressBook * ab = [ABAddressBook sharedAddressBook];
	NSArray * people = nil ;	
	NSString * selectedGroup = [[UDC valueForKeyPath:@"values.selectedGroup"] objectForKey:MENUOBJECT];
	if ([selectedGroup isEqualToString:MENUITEMALL]) {
		people = [ab people];
	}
	else if ([selectedGroup hasSuffix:@":ABGroup"] || [selectedGroup hasSuffix:@":ABSmartGroup"]) {
		ABGroup * myGroup = (ABGroup*) [ab recordForUniqueId:selectedGroup];
		people = [myGroup members];
	}
	else {
		[self error:NSLocalizedString(@"Selected group wasn't recognisable.",@"Selected group couldn't be recognised.")];
		return;
	}

	
	
#pragma mark do: main loop
	//
	// Run through all the records and create the necessary dictionary entry for each
	NSUserDefaults * UD = [NSUserDefaults standardUserDefaults];
	[self setValue: [NSDictionary dictionaryWithObjectsAndKeys:
		(([[UD valueForKey:@"sortDirection"] intValue] == 1 )? @"YES" : @"NO") , @"SortedDescending",
		[UD valueForKeyPath:@"sortOrder.OBJECT"], @"SortOrder",
		([[UD valueForKey:@"threadedDisplay"] boolValue] ? @"yes": @"no") , @"DisplayInThreadedMode", 
		nil]
			forKey:@"mailboxUserInfo"];
	NSEnumerator * myEnum = [people objectEnumerator];
	ABPerson * person;
	NSMutableArray * rules = [NSMutableArray arrayWithCapacity:[people count]];
	NSDictionary * ruleDict;
	while (person = [myEnum nextObject]) {
		ruleDict = [self ruleDictionaryForPerson:person];
		if (ruleDict) {
			[rules  addObject:ruleDict];
		}
	}

	NSString * myMailboxName = [UDC valueForKeyPath:@"values.folderName"];
				
	NSDictionary * myMailbox = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:18], @"IMAPMailboxAttributes", 
		[self uuid], @"MailboxID", 
		myMailboxName, @"MailboxName", 
		[NSNumber numberWithInt:7], @"MailboxType", 
		mailboxUserInfo, @"MailboxUserInfo", 
		rules, @"MailboxChildren", 
		nil ];

	NSString * myPath =[@"~/Library/Mail/V2/MailData/SyncedSmartMailboxes.plist" stringByExpandingTildeInPath];
    BOOL X7OrAbove = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:myPath]) {
        // file does not exist at X.7+ path: use old path
        myPath = [@"~/Library/Mail/SmartMailboxes.plist" stringByExpandingTildeInPath];
        X7OrAbove = NO;
    }

    id oldDict;
    if (X7OrAbove) {
        oldDict = [NSArray arrayWithContentsOfFile:myPath];
    }
    else {
        oldDict = [NSDictionary dictionaryWithContentsOfFile:myPath];
    }
    
	NSMutableArray * mailboxArray;
	NSNumber * version;
	if (oldDict) {
		// remove old backup file and make existing plist file the backup file
		// if you read up to here you might as well enjoy the lack of error handling
		NSString * myBackupPath = [[myPath stringByDeletingPathExtension] stringByAppendingFormat:@" %@.plist", NSLocalizedString(@"Pre Mailboxer", @"Suffix for Backup file name")];
		[[NSFileManager defaultManager] removeFileAtPath:myBackupPath handler:nil]; 
		[[NSFileManager defaultManager] movePath:myPath toPath:myBackupPath handler:nil];
		
        if (X7OrAbove) {
            mailboxArray = [[oldDict mutableCopy] autorelease];
        }
        else {
            mailboxArray = [[[oldDict objectForKey:@"mailboxes"] mutableCopy] autorelease];
            version = [oldDict objectForKey:@"version"];
        }
        
		NSDictionary * dict1;
		NSString * name;
		NSEnumerator * myEnum = [mailboxArray objectEnumerator];
		while (dict1 = [myEnum nextObject]) {
			name = [dict1 objectForKey:@"MailboxName"];
			if ([name isEqualToString:myMailboxName]) {
				[mailboxArray removeObject:dict1];
			}
		}
		[mailboxArray addObject:myMailbox];
	}
	else {
		mailboxArray = [NSMutableArray arrayWithObject:myMailbox];
		version = [NSNumber numberWithInt:1];
	}
	
	// write smart mailboxes file
    if (X7OrAbove) {
        [mailboxArray writeToFile:myPath atomically:YES];
    }
    else {
        NSDictionary * finalDict = [NSDictionary dictionaryWithObjectsAndKeys:mailboxArray, @"mailboxes", version, @"version", nil];
        [finalDict writeToFile:myPath atomically:YES];
    }
	
	

	// Finally, relaunch Mail
	if (didQuitMail) {
		[sender setTitle:NSLocalizedString(@"Relaunching Mail",@"Relaunching Mail")];	
		[sender display];
		// [[NSWorkspace sharedWorkspace] launchApplication:@"Mail"]; // somewhat unreliable (gives LSOpenFromURLSpec() retruned -609 for application mail path (null) message about 1/3 of the runs
		NSAppleScript * myScript = [[NSAppleScript alloc] initWithSource:@"delay 0.5\ntell application \"Mail\" to run\n"];
		[myScript executeAndReturnError:nil];
		[myScript release];		
	}
		
	[sender setTitle:NSLocalizedString(@"Create Smart Mailboxes", @"Create Smart Mailboxes")];
	[sender setEnabled:YES];
	[sender display];
	[self setValue:[NSNumber numberWithBool:NO] forKey:@"running"];
	[self updateInfoText]; // just to make really sure the display is up to date 
}



- (NSDictionary *) ruleDictionaryForPerson:(ABPerson*) person {
	NSMutableDictionary * myDict = [NSMutableDictionary dictionaryWithCapacity:7];
	[myDict setObject:[NSNumber numberWithInt:1] forKey:@"IMAPMailboxAttributes"];
	[myDict setObject:@"YES" forKey:@"MailboxAllCriteriaMustBeSatisfied"];
	[myDict setObject:[self uuid] forKey:@"MailboxID"];
	[myDict setObject:[NSNumber numberWithInt:0] forKey:@"MailboxType"];
	[myDict setObject:mailboxUserInfo forKey:@"MailboxUserInfo"];
	
	int flags = [[person valueForProperty:kABPersonFlags] intValue];
	NSString * name;
	NSString * vorname;
	NSString * nachname;
	if (!(flags & kABShowAsCompany)) {
		vorname = [person valueForProperty:kABFirstNameProperty];
		if (!vorname) { vorname = @"";}
		nachname = [person valueForProperty:kABLastNameProperty];
		if (!nachname) {nachname = @"";}
		if (firstNameFirst || [nachname isEqualToString:@""]) {
			name = [vorname stringByAppendingFormat:@" %@", nachname];
		}
		else {
			
			name = [nachname stringByAppendingFormat:@", %@", vorname];
		}
	}
	else {
		name = [person valueForProperty:kABOrganizationProperty];
		if (!name) {name = @"???";}
	}
	 
	[myDict setObject:[name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] forKey:@"MailboxName"];
	
	ABMultiValue * emails = [person valueForProperty:kABEmailProperty];
	NSInteger n = [emails count];
	if (n==0) {
		return nil;
	}
	NSString * address;
	NSMutableArray * addressArray = [NSMutableArray arrayWithCapacity:2*n];
	NSInteger i = 0;
	while (i< n) {
		address = [emails valueAtIndex:i];		
		
		[addressArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:[self uuid], @"CriterionUniqueId", address, @"Expression",  @"From", @"Header", nil]];
		
		if ([[UDC valueForKeyPath:@"values.includeSentMessages"] boolValue]) {
			[addressArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:[self uuid], @"CriterionUniqueId", address, @"Expression", @"AnyRecipient", @"Header", nil]];
		}
		i++;
	}
	
	
	NSMutableArray * criteria = [NSMutableArray arrayWithCapacity:2];
	if ([[UDC valueForKeyPath:@"values.includeTrashedMessages"] boolValue]) {
		[criteria addObject: [NSDictionary dictionaryWithObjectsAndKeys:
			[self uuid], @"CriterionUniqueId", 
			@"NotInJunkMailbox", @"Header", 
			@"omit Junk", @"Name", 
			nil]
		];
	}

	[criteria addObject: [NSDictionary dictionaryWithObjectsAndKeys:
		[self uuid], @"CriterionUniqueId", 
		@"user criteria", @"Name", 
		@"Compound", @"Header", 
		@"NO", @"AllCriteriaMustBeSatisfied", 
		addressArray, @"Criteria", 
		nil]
	];
	
	[myDict setObject:criteria forKey:@"MailboxCriteria"];
	
	return myDict;
}


- (NSString*) updateInfoText {
	NSString * tempText = NSLocalizedString(@"Info Text. Command name: %@, Smart Mailbox name: %@, AddressBook Group name: %@, CCstatus: %@, Quitting Mail: %@ , Restarting Mail:%@", @"Info text at the bottom of the window, six strings are inserted. The Address Book group name can also be the complete address book.");

	NSDictionary * theSelection = [UDC valueForKeyPath:@"values.selectedGroup"];
	NSString * selectedGroup = (NSString*) [theSelection objectForKey:MENUOBJECT];
	NSString * groupName =nil;
	
	if ([selectedGroup isEqualToString:MENUITEMALL]) {
		groupName = NSLocalizedString(@"your address book", @"your address book");
	}
	else  {
		groupName = [theSelection objectForKey:MENUNAME];
		groupName = [NSString stringWithFormat:NSLocalizedString(@"the group '%@' of your address book", @"the group '%@' of your address book"), groupName];
	}
	
	NSString * ccInfo = NSLocalizedString(@"sender or recipient", @"sender or recipient");
	/* Mail can't actually do this...
	if ([[UDC valueForKeyPath:@"values.includeCCs"] boolValue]) {
		ccInfo = NSLocalizedString(@"sender, recipient or carbon copy recipient", @"sender, recipient or carbon copy recipient");		
	}
	else {
		ccInfo = ;				
	}
	*/
	
	NSString * mailtext1 = @"";
	NSString * mailtext2 = @"";
	if ([self mailIsRunning]) {
	//	tempText = [tempText stringByAppendingFormat:@"\n%@", NSLocalizedString(@"Mail will be quit and re-launched.", @"Mail will be quit and re-launched.")];
		mailtext1 = NSLocalizedString(@". Quit Mail" , @"bullet point that Mail will be quit");
		mailtext2 = NSLocalizedString(@". Relaunch Mail", @"bullet point that Mail will be relaunched");
	}
			
	tempText = [NSString stringWithFormat:tempText, 
		NSLocalizedString(@"Create Smart Mailboxes", @"Create Smart Mailboxes"),
		[UDC valueForKeyPath:@"values.folderName"],
		groupName,
		ccInfo,
		mailtext1,
		mailtext2];

	NSAttributedString *displayString = [[[NSAttributedString alloc] 
							initWithString:tempText
						        attributes:myStringAttributes] autorelease];
	
	
	[self setValue:displayString forKey:@"infoText2"];
	return tempText;
	
	// @"The “%@” command will replace your settings for Mail's smart mailboxes by adding or replacing the Smart Mailbox folder “%@” which contains a Smart Mailbox for each contact in @%@”. These Smart Mailboxes will contain all messages in which any of the contact's e-mail addresses occurs as a %@.	%@"
}



- (NSString*) uuid {
	unsigned char _uuid[16];
	char _out[40];
	uuid_generate(_uuid);
	uuid_unparse(_uuid, _out);
	return [NSString stringWithUTF8String:_out];
}


- (BOOL) mailIsRunning {
	BOOL r = NO;
	
	if (!running) {
		NSArray * appArray = [[NSWorkspace sharedWorkspace] launchedApplications];
		NSEnumerator * myEnum = [appArray objectEnumerator];
		NSDictionary * appDict;
		while (appDict = [myEnum nextObject]) {
			if ([[appDict objectForKey:@"NSApplicationBundleIdentifier"] isEqualToString:@"com.apple.mail"]) {
				r = YES;
			}
		}
		mailIsRunningCache = r;
	}
	else {
		// while we are processing stuff do not change the display when Mail is quit and relaunched.
		r = mailIsRunningCache;
	}
	// NSLog([NSString stringWithFormat:@"mailIsRunning: %@ (running: %i)", [NSNumber numberWithBool:r], running]);
	return r;
}

- (void) MailChanged: (NSNotification*) theNotification {
	NSString * appCode = [[theNotification userInfo] objectForKey:@"NSApplicationBundleIdentifier"];
	if ([appCode isEqualToString:@"com.apple.mail"]) {
		[self updateInfoText];
	}
}


- (NSData*) AddressBookIcon {
	NSImage * im = [[NSWorkspace sharedWorkspace] iconForFile:[[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.addressbook"]];
	[im setSize:NSMakeSize(128.0,128.0)];
	return [im TIFFRepresentation];
}

- (NSData*) vcardIcon {
	NSImage * im = [[NSWorkspace sharedWorkspace] iconForFileType:@"vcf"];
	[im setSize:NSMakeSize(128.0,128.0)];
	return [im TIFFRepresentation];
}


- (NSData*) smartFolderIcon {
	NSImage * im = [[NSWorkspace sharedWorkspace] iconForFileType:@"savedSearch"];
	[im setSize:NSMakeSize(128.0,128.0)];
	return [im TIFFRepresentation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	[self updateInfoText];
}

- (void)addressBookChanged:(NSNotification *)notification {
	[self buildGroupList];
}

- (void) error: (NSString*) error {
	NSLog(@"%@", error);
	NSBeep();
	[self setValue:[NSNumber numberWithBool:NO] forKey:@"running"];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
	return YES;
}


// for the various actions in the help menu
- (void) readme:(id) sender {
	NSWorkspace * WORKSPACE = [NSWorkspace sharedWorkspace];
	NSInteger tag = [sender tag];
	switch (tag) {
		case 1: // earthlingsoft
			[WORKSPACE openURL:[NSURL URLWithString:@"http://earthlingsoft.net/"]];
			break;
		case 2: // Website
			[WORKSPACE openURL:[NSURL URLWithString:@"http://earthlingsoft.net/Mailboxer"]];
			break;
		case 3: // Send Mail
			[WORKSPACE openURL:[NSURL URLWithString:[NSString stringWithFormat:@"mailto:earthlingsoft%%40earthlingsoft.net?subject=Mailboxer%%20%@", [self myVersionString]]]];
			break;
		case 4: // Paypal
			[WORKSPACE openURL: [NSURL URLWithString:@"https://www.paypal.com/xclick/business=earthlingsoft%40earthlingsoft.net&item_name=Mailboxer&no_shipping=1&cn=Comments&tax=0&currency_code=EUR"]];
			break;
		case 5: // Readme
			[WORKSPACE openFile:[[NSBundle mainBundle] pathForResource:@"readme" ofType:@"html"]];
			break;
	}
}


// return version string
- (NSString*) myVersionString {
	return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}


- (IBAction)menuCheckVersion:(id)sender {
    if([[NSApp currentEvent] modifierFlags] == (NSAlphaShiftKeyMask|NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) {
		//        [VersionChecker writeVersionFileWithDownloadURLString:@"http://www.earthlingsoft.net/GeburtstagsChecker/GeburtstagsChecker.sit"];
    } else {
		   [VersionChecker checkVersionForURLString:@"http://www.earthlingsoft.net/Mailboxer/Mailboxer.xml" silent:NO];
    }
}


@end


@implementation ABGroup (ESSortExtension) 

- (NSComparisonResult) groupByNameCompare:(ABGroup *)aGroup {
	NSString * myName = [self valueForProperty:kABGroupNameProperty];
	NSString * theirName = [aGroup valueForProperty:kABGroupNameProperty];
	return [myName caseInsensitiveCompare:theirName];
}

@end
