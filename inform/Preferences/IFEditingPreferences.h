//
//  IFEditingPreferences.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

#import "IFEditingPreferencesSet.h"
#import "IFPreferencePane.h"

///
/// Preference pane that allows the user to select the styles she wants to see
///
@interface IFEditingPreferences : IFPreferencePane

// Receiving data from/updating the interface
- (IBAction) styleSetHasChanged: (id) sender;
- (void) reflectCurrentPreferences;
- (IBAction) restoreDefaultSettings: (id) sender;

@end
