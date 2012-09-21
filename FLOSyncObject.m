//
//  FLOSyncObject.m
//
//  Created by Ricky Kirkendall on 9/12/12.
//  Copyright (c) 2012 FloCo Apps LLC. All rights reserved.
//

#import "FLOSyncObject.h"

@implementation FLOSyncObject
@synthesize local,remote;

-(NSString *)mostRecentCopy
{
    if ([local.modified compare:remote.modified] == NSOrderedDescending) 
        return @"local";
        
    else if ([local.modified compare:remote.modified] == NSOrderedAscending)
        return @"remote";
    
    else
        return @"same";
}
@end
