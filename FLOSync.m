//
//  FLOSync.m
//
//  Created by Ricky Kirkendall on 9/12/12.
//  Copyright (c) 2012 FloCo Apps LLC. All rights reserved.
//

#import "FLOSync.h"

#define LastSyncUserDefaultsKey @"lasySyncSnapshot"

#define NOTIFICATION_START @"startDropboxSync"
#define NOTIFICATION_STOP @"endDropboxSync"
@interface FLOSync()
{
    FLOSyncInstructionList *syncingInstructions;
    FLOSyncInstruction *currentInstruction;
    
    BOOL isSyncing;
}

-(void)startSync;
-(void)abortSync;
-(BOOL)canSync;

-(void)getMetadata;
-(NSArray *)buildSyncObjectsWithRemoteMetadata:(NSArray *)metadata;
-(void)processSyncObjects:(NSArray *)objects;

-(void)executeInstructions;
-(void)downloadFile:(FLOSyncObject *)file;
-(void)uploadFile:(FLOSyncObject *)file;
-(void)deleteLocalFile:(FLOSyncObject *)file;
-(void)deleteRemoteFile:(FLOSyncObject *)file;
-(void)syncFinished;
@end

FLOSync* selfinstance=nil;

@implementation FLOSync

#pragma mark - Create Self and Start

+ (FLOSync*)i
{
    if (!selfinstance) {
        selfinstance = [[FLOSync alloc] init];
    }
    return selfinstance;
}
+ (void)Sync
{
    [[self i] startSync];
}
-(void)startDBClient
{
    if (self.client &&[[DBSession sharedSession] isLinked] ) return; // Already started
    
    if (![[DBSession sharedSession] isLinked])
    {
        [[DBSession sharedSession] link];
        self.client = nil;
    }
    
    self.client = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    self.client.delegate = self;
}

-(void)startSync
{
    //If this is the first sync, there won't be a file list.
    //Create it.
    
    if([self canSync])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_START object:@""];
        isSyncing = YES;
        [self startDBClient];
        [self getMetadata];
    }
    else
    {
        NSLog(@"Cannot initiate sync. Could be disabled.");
        [self abortSync];
    }
}

-(void)abortSync
{
    isSyncing = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_STOP object:@""];
    NSLog(@"Sync aborted");
}

-(void)syncFinished
{
    [self WriteFileList];
    
    isSyncing = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_STOP object:@""];

    NSLog(@"done!");
}

-(BOOL)canSync
{
    if(!isSyncing)
        return YES;
    return NO;
}

#pragma mark - Load Metadata

-(void)getMetadata
{
    [self.client loadMetadata:@"/"];
}
-(void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata
{
    if (metadata.isDirectory)
    {
        NSArray *files = metadata.contents;
        NSMutableArray *textfiles = [[NSMutableArray alloc] init];
        for(DBMetadata *m in files)
        {
            // This specific implementation only syncs text files.
            if([[m.filename substringFromIndex:[m.filename length]-4] isEqualToString:@".txt"])
            {
                [textfiles addObject:m];
            }
        }
        
        NSArray *syncObjects = [self buildSyncObjectsWithRemoteMetadata:textfiles];
        
        [self processSyncObjects:syncObjects];
    }
}
-(void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error
{
    [self abortSync];
}

#pragma mark - Build Sync Objects

-(NSArray *)buildSyncObjectsWithRemoteMetadata:(NSArray *)metadata
{
    //This will return an array on FLOSyncObjects
    
    //First we take the remote metadata and create sync objects out of those
    NSMutableArray *syncObjects = [[NSMutableArray alloc] init];
    for(DBMetadata *m in metadata)
    {
        FLOSyncCopyData *remote = [[FLOSyncCopyData alloc]init];
        remote.rev = m.rev;
        remote.fileName = m.filename;
        remote.fileLocation = m.path;
        remote.modified = m.lastModifiedDate;
        
        FLOSyncObject *o = [[FLOSyncObject alloc] init];
        [o setRemote:remote];
        
        [syncObjects addObject:o];
    }
    
    //Now we take our local files and create sync objects out of those.
    
    //Note that there is only one sync object per file. If the file exists both locally and remotely,
    //then it is contained in a single sync object with FLOSyncCopyData for both the local and remote copies.
    
    syncObjects = [self addLocalFilesToSyncObjectsWithRemote:syncObjects];
    
    return syncObjects;
}

-(NSMutableArray *)addLocalFilesToSyncObjectsWithRemote:(NSMutableArray *)objectsWithRemoteCopies
{
    NSString *root = $.documentPath;
    for(NSString *item in [[NSFileManager defaultManager]contentsOfDirectoryAtPath:root error:nil])
    {
        if([item hasPrefix:@"."]) continue;
        
        NSString *itemPath = [root stringByAppendingPathComponent:item];
        NSDictionary* attribs = [[NSFileManager defaultManager] attributesOfItemAtPath:itemPath error:nil];
        BOOL isFile = $eql(attribs.fileType, NSFileTypeRegular);
        if (isFile)
        {
            FLOSyncCopyData *local = [[FLOSyncCopyData alloc] init];
            local.modified = attribs.fileModificationDate;
            local.rev = nil;
            local.fileName = item;
            local.fileLocation = itemPath;
            
            
            //Check to see if there is already a sync object for an item with this filename.
            FLOSyncObject *object;
            BOOL isContainedInSyncObjects = NO;
            for(FLOSyncObject *o in objectsWithRemoteCopies)
                if([o.remote.fileName isEqualToString:local.fileName])
                {
                    object = o;
                    isContainedInSyncObjects = YES;
                }
            
            //There is not. Create one.
            if(!object)
                object = [[FLOSyncObject alloc] init];
            
            //add local sync copy data to the sync object
            [object setLocal:local];
            
            if(!isContainedInSyncObjects)
                [objectsWithRemoteCopies addObject:object];
        }
    }
    return objectsWithRemoteCopies;
}

#pragma mark - Create and Follow Syncing Instructions

-(void)processSyncObjects:(NSArray *)objects
{
    if(!syncingInstructions)
        syncingInstructions = [[FLOSyncInstructionList alloc] init];
    
    //Look at each sync object and decide how we should proceed to sync the file
    
    //We will use the last known file list to help us inductively decide on a list of executable instructions
    
    //Make decisions for each sync object.
    for(FLOSyncObject *object in objects)
    {        
        //For Conflicts
        if(object.local && object.remote)
        {
            //Compare dates
            NSString *recent = [object mostRecentCopy];
            FLOSyncInstruction *toDo = [[FLOSyncInstruction alloc] init];
            [toDo setSyncObject:object];
            
            if([recent isEqualToString:@"local"])
            {
                [toDo setOperation:FLOSyncOperationUploadFile];
                [syncingInstructions addInstruction:toDo];
            }
            
            else if([recent isEqualToString:@"remote"])
            {
                [toDo setOperation:FLOSyncOperationDownloadFile];
                [syncingInstructions addInstruction:toDo];
            }
            
            //If the dates are the same, nothing needs done.
        }
        
        //Local but not remote
        else if(object.local && !object.remote)
        {
            //Was it deleted remotely? If it was in the last sync list, then, yes. Else, no.
            
            //IF this is the first sync, there won't be a last sync list. So upload it.
            if(![self FileListFromLastSync])
            {
                FLOSyncInstruction *toDo = [[FLOSyncInstruction alloc] init];
                [toDo setSyncObject:object];
                [toDo setOperation:FLOSyncOperationUploadFile];
                [syncingInstructions addInstruction:toDo];
            }
            else
            {
                BOOL wasRemotelyDeleted = [self wasFileWasInLastSyncList:object.local.fileName];
                
                FLOSyncInstruction *toDo = [[FLOSyncInstruction alloc] init];
                [toDo setSyncObject:object];
                
                //Yes? Delete it Locally.
                if(wasRemotelyDeleted)
                {
                    [toDo setOperation:FLOSyncOperationDeleteLocalFile];
                }
                
                //No? Upload it.
                else
                {
                    [toDo setOperation:FLOSyncOperationUploadFile];
                }
                
                [syncingInstructions addInstruction:toDo];
            }
        }
        
        //Remote not local
        else
        {
            //Was it deleted locally? If it was in the last sync list, then, yes. Else, no.
            //Again, iF this is the first sync, there won't be a last sync list. So download it.
            
            if(![self FileListFromLastSync])
            {
                FLOSyncInstruction *toDo = [[FLOSyncInstruction alloc] init];
                [toDo setSyncObject:object];
                [toDo setOperation:FLOSyncOperationDownloadFile];
                [syncingInstructions addInstruction:toDo];
            }
            else
            {
                BOOL wasLocallyDeleted = [self wasFileWasInLastSyncList:object.remote.fileName];
                
                FLOSyncInstruction *toDo = [[FLOSyncInstruction alloc] init];
                [toDo setSyncObject:object];
                
                //Yes? Delete it Remotely.
                if(wasLocallyDeleted)
                {
                    [toDo setOperation:FLOSyncOperationDeleteRemoteFile];
                }
                
                //No? Download it.
                else
                {
                    [toDo setOperation:FLOSyncOperationDownloadFile];
                }
                
                [syncingInstructions addInstruction:toDo];
            }
        }
    }
    
    //We should now have a list of executable instructions.
    
    [self executeInstructions];
}

#pragma mark - Handle File List Snapshot from Last Sync

-(BOOL)wasFileWasInLastSyncList: (NSString *)fileName
{
    return [[self FileListFromLastSync] containsObject:fileName];
}

-(NSArray *)FileListFromLastSync
{
    return [[NSUserDefaults standardUserDefaults] arrayForKey:LastSyncUserDefaultsKey];
}

-(void)WriteFileList
{
    NSMutableArray *toSave = [[NSMutableArray alloc] init];
    
    NSString *root = $.documentPath;
    for(NSString *item in [[NSFileManager defaultManager]contentsOfDirectoryAtPath:root error:nil])
    {
        if([item hasPrefix:@"."]) continue;
        
        NSString *itemPath = [root stringByAppendingPathComponent:item];
        NSDictionary* attribs = [[NSFileManager defaultManager] attributesOfItemAtPath:itemPath error:nil];
        BOOL isFile = $eql(attribs.fileType, NSFileTypeRegular);
        if (isFile)
        {
            [toSave addObject:item];
        }
    }

    [[NSUserDefaults standardUserDefaults] setObject:toSave forKey:LastSyncUserDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Execute Sync Instructions

-(void)executeInstructions
{
    
    currentInstruction = [syncingInstructions nextInstruction];
    if(currentInstruction)
    {
        if(currentInstruction.operation == FLOSyncOperationDeleteLocalFile)
            [self deleteLocalFile:currentInstruction.syncObject];
        else if(currentInstruction.operation == FLOSyncOperationDeleteRemoteFile)
            [self deleteRemoteFile:currentInstruction.syncObject];
        else if(currentInstruction.operation == FLOSyncOperationDownloadFile)
            [self downloadFile:currentInstruction.syncObject];
        else if(currentInstruction.operation == FLOSyncOperationUploadFile)
            [self uploadFile:currentInstruction.syncObject];
    }
    else
    {
        //No more instructions. We're done
        [self syncFinished];
    }
}

-(void)uploadFile:(FLOSyncObject *)file
{
    NSLog(@"uploading file: %@",file.local.fileName);
    [self.client uploadFile:file.local.fileName toPath:@"/" withParentRev:file.remote.rev fromPath:file.local.fileLocation];
}

-(void)downloadFile:(FLOSyncObject *)file
{
    NSLog(@"downloading file: %@",file.remote.fileName);
    [self.client loadFile:file.remote.fileLocation atRev:file.remote.rev intoPath:[$.documentPath stringByAppendingPathComponent:file.remote.fileName]];
}

-(void)deleteRemoteFile:(FLOSyncObject *)file
{
    NSLog(@"deleting remote file: %@",file.remote.fileName);
    [self.client deletePath:file.remote.fileLocation];
}
-(void)deleteLocalFile:(FLOSyncObject *)file
{
    NSLog(@"deleting local file: %@",file.local.fileName);
    BOOL result = [[NSFileManager defaultManager] removeItemAtPath:file.local.fileLocation error:nil];
    
    if(result)
        [self operationSucceeded];
    else
        [self operationFailed];
}

#pragma mark - Async Dropbox Callbacks

//For Uploading files
- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath from:(NSString *)srcPath metadata:(DBMetadata *)metadata
{
    // Now the file has uploaded, we need to set its 'last modified' date locally to match the date on dropbox.
    NSDictionary* attr = $dict(metadata.lastModifiedDate, NSFileModificationDate);
    [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:[$.documentPath stringByAppendingPathComponent: destPath] error:nil];
    
    [self operationSucceeded];
}
-(void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error
{
    [self operationFailed];
}

//For downloading files
- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath contentType:(NSString*)contentType metadata:(DBMetadata*)metadata
{
    // Now the file has downloaded, we need to set its 'last modified' date locally to match the date on dropbox.
    
    NSDictionary* attr = $dict(metadata.lastModifiedDate, NSFileModificationDate);
    [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:destPath error:nil];
    
    [self operationSucceeded];
}
-(void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error
{
    [self operationFailed];
}

//For deleting files
-(void)restClient:(DBRestClient *)client deletedPath:(NSString *)path
{
    [self operationSucceeded];
}
-(void)restClient:(DBRestClient *)client deletePathFailedWithError:(NSError *)error
{
    [self operationFailed];
}

#pragma mark - Post Operation Completion status
-(void)operationSucceeded
{
    [syncingInstructions removeInstruction:currentInstruction];
    
    [self executeInstructions];
}
-(void)operationFailed
{
    //If it has been tried before, this is second failure, so remove it from instructions.
    NSLog(@"an operation has failed");
    if(!currentInstruction.result)
        currentInstruction.result = FLOSyncOperationResultFailed;
    else
        [syncingInstructions removeInstruction:currentInstruction];
    
    [self executeInstructions];
}
@end