//
//  FLOSyncInstruction.h
//
//  Created by Ricky Kirkendall on 9/11/12.
//  Copyright (c) 2012 FloCo Apps LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLOSyncObject.h"
enum FLOSyncOperation {
    FLOSyncOperationDownloadFile = 0,
    FLOSyncOperationUploadFile = 1,
    FLOSyncOperationDeleteLocalFile = 2,
    FLOSyncOperationDeleteRemoteFile = 3
    };

enum FLOSyncOperationResult {
    FLOSyncOperationResultSuccess = 4,
    FLOSyncOperationResultFailed = 5
};


@interface FLOSyncInstruction : NSObject
{}

@property (nonatomic, assign) enum FLOSyncOperation operation;
@property (nonatomic, assign) enum FLOSyncOperationResult result;

@property (nonatomic, strong) FLOSyncObject *syncObject;
@end
