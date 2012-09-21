//
//  FLOSync.h
//
//  Created by Ricky Kirkendall on 9/12/12.
//  Copyright (c) 2012 FloCo Apps LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DropboxSDK/DropboxSDK.h>
#import "ConciseKit.h"
#import "FLOSyncObject.h"
#import "FLOSyncCopyData.h"
#import "FLOSyncInstruction.h"
#import "FLOSyncInstructionList.h"

#import "ANDataStoreController.h"
@interface FLOSync : NSObject<DBRestClientDelegate>
@property (nonatomic, strong) DBRestClient* client;
+(FLOSync*)i;
+ (void)Sync;

@end
