//
//  IFAppDelegate.h
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Application delegate class

#import <Cocoa/Cocoa.h>

@interface IFAppDelegate : NSObject<NSOpenSavePanelDelegate>

/// Retrieves the runloop used by the main thread (Cocoa sometimes calls our callbacks
/// from a sooper-sekrit bonus thread, causing pain if we don't use this)
+ (NSRunLoop*) mainRunLoop;
- (void) doCopyProject: (NSURL*) source
                    to: (NSURL*) destination;

/// Displays/hides the inspector window
- (IBAction) showInspectors: (id) sender;
/// Shows the preferences window
- (IBAction) showPreferences: (id) sender;
/// Displays an error about not being able to show help yet
- (IBAction) docIndex: (id) sender;

/// Shows the Find dialog
- (IBAction) showFind2: (id) sender;
/// 'Find next'
- (IBAction) findNext: (id) sender;
/// 'Find previous'
- (IBAction) findPrevious: (id) sender;
/// 'Use selection for find'
- (IBAction) useSelectionForFind: (id) sender;

- (IBAction) newProject: (id) sender;
- (IBAction) newExtension: (id) sender;
- (IBAction) newInform6Project: (id) sender;

- (IBAction) visitWebsite: (id) sender;
- (IBAction) showWelcome: (id) sender;
- (IBAction) exportToEPub: (id) sender;

/// Updates extensions menu
- (void) updateExtensionsMenu;
- (void) createNewProject: (NSString*) title
                    story: (NSString*) story;

/// The Debug menu
@property (atomic, readonly, copy) NSMenuItem *debugMenu;

// Spell checking
@property (atomic, readonly) BOOL sourceSpellChecking;
- (IBAction) toggleSourceSpellChecking: (id) sender;

@end
