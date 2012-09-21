//
//  FLOSyncCopyData.h
//
//  Created by Ricky Kirkendall on 9/12/12.
//  Copyright (c) 2012 FloCo Apps LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FLOSyncCopyData : NSObject
@property(nonatomic, strong) NSString *fileLocation;
@property(nonatomic, strong) NSString *fileName;
@property(nonatomic, strong) NSString *rev;
@property(nonatomic, strong) NSDate *modified;
@end
