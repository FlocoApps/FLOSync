//
//  FLOSyncObject.h
//
//  Created by Ricky Kirkendall on 9/12/12.
//  Copyright (c) 2012 FloCo Apps LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLOSyncCopyData.h"
@interface FLOSyncObject : NSObject

@property(nonatomic, strong)FLOSyncCopyData *local;
@property(nonatomic, strong)FLOSyncCopyData *remote;

-(NSString *)mostRecentCopy;

@end
