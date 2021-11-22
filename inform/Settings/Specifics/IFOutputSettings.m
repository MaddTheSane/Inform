//
//  IFOutputSettings.m
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import "IFOutputSettings.h"
#import "IFUtility.h"
#import "IFCompilerSettings.h"

static NSString* const IFSettingCreateBlorb = @"IFSettingCreateBlorb";

@implementation IFOutputSettings {
    IBOutlet NSMatrix* zmachineVersion;
    IBOutlet NSButton* releaseBlorb;
}

- (instancetype) init {
	return [self initWithNibName: @"OutputSettings"];
}

- (NSString*) title {
	return [IFUtility localizedString: @"Output Settings"];
}

// = Setting up =

- (BOOL) createBlorbForRelease {
    IFCompilerSettings* settings = [self compilerSettings];
	NSNumber* value = [settings dictionaryForClass: [self class]][IFSettingCreateBlorb];
	
	if (value)
		return [value boolValue];
	else
		return YES;
}

- (void) setCreateBlorbForRelease: (BOOL) setting {
    IFCompilerSettings* settings = [self compilerSettings];
	
	[settings dictionaryForClass: [self class]][IFSettingCreateBlorb] = @(setting);
	[settings settingsHaveChanged];
}

- (void) updateFromCompilerSettings {
    IFCompilerSettings* settings = [self compilerSettings];

	// Supported Z-Machine versions
	NSArray* supportedZMachines = [settings supportedZMachines];
	
	for( NSCell* cell in [zmachineVersion cells] ) {
		if (supportedZMachines == nil) {
			[cell setEnabled: YES];
		} else {
			if ([supportedZMachines containsObject: @((int) [cell tag])]) {
				[cell setEnabled: YES];
			} else {
				[cell setEnabled: NO];
			}
		}
	}
	
	// Selected Z-Machine version
    if ([zmachineVersion cellWithTag: [settings zcodeVersion]] != nil) {
        [zmachineVersion selectCellWithTag: [settings zcodeVersion]];
    } else {
        [zmachineVersion deselectAllCells];
    }
	
	// Whether or not we should generate a blorb file on release
	[releaseBlorb setState: [self createBlorbForRelease]?NSControlStateValueOn:NSControlStateValueOff];
}

- (void) setSettings {
	BOOL willCreateBlorb = [releaseBlorb state]==NSControlStateValueOn;
    IFCompilerSettings* settings = [self compilerSettings];

	[settings setZCodeVersion: (int) [[zmachineVersion selectedCell] tag]];
	[self setCreateBlorbForRelease: willCreateBlorb];
}

- (BOOL) enableForCompiler: (NSString*) compiler {
	// These settings are unsafe to change while using Natural Inform
	if ([compiler isEqualToString: IFCompilerNaturalInform])
		return NO;
	else
		return YES;
}

@end
