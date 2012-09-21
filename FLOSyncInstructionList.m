//
//  FLOSyncInstructionList.m
//
//  Created by Ricky Kirkendall on 9/12/12.
//  Copyright (c) 2012 FloCo Apps LLC. All rights reserved.
//

#import "FLOSyncInstructionList.h"
@interface FLOSyncInstructionList()
{
    NSMutableArray *flosyncinstructionlist;
}
@end

@implementation FLOSyncInstructionList
-(NSMutableArray *)flosyncinstructionlist
{
    if(!flosyncinstructionlist)
        flosyncinstructionlist = [[NSMutableArray alloc] init];
    return flosyncinstructionlist;
}

-(FLOSyncInstruction *)nextInstruction
{
    if([flosyncinstructionlist count]>0)
        return [flosyncinstructionlist objectAtIndex:0];
    
    return nil;    
}

-(void)addInstruction:(FLOSyncInstruction *)instruction
{
    [[self flosyncinstructionlist] addObject:instruction];
}

-(void)removeInstruction:(FLOSyncInstruction *)instruction
{
    [[self flosyncinstructionlist] removeObject:instruction];
}

@end
