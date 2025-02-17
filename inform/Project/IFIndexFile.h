//
//  IFIndexFile.h
//  Inform
//
//  Created by Andrew Hunter on Sun Jun 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface IFIndexFile : NSObject<NSOutlineViewDataSource>

- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithContentsOfFile: (NSString*) filename;
- (instancetype) initWithData: (NSData*) data NS_SWIFT_UNAVAILABLE("");
- (instancetype) initWithContentsOfURL: (NSURL*) filename error: (NSError**) outError;
- (instancetype) initWithData: (NSData*) data error: (NSError**) outError NS_DESIGNATED_INITIALIZER; // Designated initialiser

// Getting info about a particular item
- (NSString*) filenameForItem: (id) item;
- (NSURL*)    fileURLForItem: (id) item;
- (int)       lineForItem: (id) item;
- (NSString*) titleForItem: (id) item;

@end
