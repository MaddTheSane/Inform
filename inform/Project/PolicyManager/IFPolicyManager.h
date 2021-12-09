//
//  IFPolicyManager.h
//  Inform
//
//  Created by Toby Nelson 2015
//

#import <Cocoa/Cocoa.h>

@class IFProjectPolicy;
@class IFProjectController;

@interface IFPolicyManager : NSObject {
}

@property (atomic) IFProjectPolicy* generalPolicy;
@property (atomic) IFProjectPolicy* docPolicy;
@property (atomic) IFProjectPolicy* extensionsPolicy;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithProjectController:(IFProjectController *) projectController NS_DESIGNATED_INITIALIZER;

@end
