//
//  IFHeaderView.h
//  Inform
//
//  Created by Andrew Hunter on 02/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFHeader.h"
#import "IFHeaderNode.h"
#import "IFHeaderController.h"

@protocol IFHeaderViewDelegate;

//
// View used to allow the user to restrict the section of the source file that they are
// browsing
//
@interface IFHeaderView : NSView<NSTextViewDelegate, IFHeaderView>

/// Retrieves the root header node
@property (atomic, readonly, strong) IFHeaderNode *rootHeaderNode;
/// Sets/retrieves the display depth for this view
@property (nonatomic) int displayDepth;

/// Sets the background colour for this view
@property (atomic, copy) NSColor *backgroundColour;
/// Sets the delegate for this view
@property (atomic, weak) id<IFHeaderViewDelegate> delegate;
/// Sets the message to use in this view
- (void) setMessage: (NSString*) message;

@end

@protocol IFHeaderViewDelegate <NSObject>

@optional
/// Indicates that a header node has been clicked on
- (void) headerView: (IFHeaderView*) view
	  clickedOnNode: (IFHeaderNode*) node;
/// Indicates that the controller should try to update the specified header node
- (void) headerView: (IFHeaderView*) view
 		 updateNode: (IFHeaderNode*) node
 	   withNewTitle: (NSString*) newTitle;
/// Request to refresh all of the headers being managed by a view
- (void) refreshHeaders: (IFHeaderController*) controller;

@end
