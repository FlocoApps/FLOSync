//
//  FLOSyncInstructionList.h
//
//  Created by Ricky Kirkendall on 9/12/12.
//  Copyright (c) 2012 FloCo Apps LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FLOSyncInstruction.h"
@interface FLOSyncInstructionList : NSObject
 
-(void)addInstruction:(FLOSyncInstruction *)instruction;

-(void)removeInstruction:(FLOSyncInstruction *)instruction;

-(FLOSyncInstruction *)nextInstruction;
@end
