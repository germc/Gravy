//
//  GRLocalSource.m
//  Gravy
//
//  Created by Nathan Tesler on 30/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRLocalSource.h"
#import "GRSerialization.h"

@implementation GRLocalSource

-(id)initWithManagedClass:(Class)managedClass
{
    if (self = [super initWithManagedClass:managedClass])
    {
        [self seed];
        [self loadObjects];
        [self addCommitTriggers];
    }

    return self;
}

-(void)seed
{
    NSString * const GRLocalSourceDidSeedDataKey = @"GRLocalSourceDidSeedData";

    // If we've already seeded, don't seed!
    if ([[NSUserDefaults standardUserDefaults] boolForKey:GRLocalSourceDidSeedDataKey])
        return;

    // Get the file path
    NSString *filePath = [[NSBundle mainBundle] pathForResource:NSStringFromClass(self.managedClass) ofType:@"json"];

    if (filePath)
    {
        // Move the file to the store path
        [[[NSFileManager alloc] init] copyItemAtPath:filePath toPath:[self storePath] error:nil];

        // Set DidSeedData
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:GRLocalSourceDidSeedDataKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

-(void)loadObjects
{
    // Create Data directory if it doesn't exist
    NSFileManager *fileManager = [[NSFileManager alloc] init];

    // Get or create .json store file
    if ([fileManager fileExistsAtPath:[self storePath]])
    {
        // Get stored data
        NSData *data = [fileManager contentsAtPath:[self storePath]];

        // Convert data into objects
        if ([data length])
        {
            // Serialize all objects
            NSArray *objects = [GRSerialization objectWithJSON:data class:self.managedClass options:nil];

            // Add each object to its source
            for (GRObject *object in objects)
                [object save];
        }

    }
    else
        [fileManager createFileAtPath:[self storePath] contents:nil attributes:nil];
}

-(void)addCommitTriggers
{
    // Add a commit trigger for the WillResignActive notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(commit) name:UIApplicationWillResignActiveNotification object:nil];
}

-(void)commit
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        // Turn the objects in the store into an NSData object
        NSData *soupData = [GRSerialization JSONWithObject:self.objects options:nil];

        // Write data to .soup file asynchronously & atomically
        [soupData writeToFile:[self storePath] atomically:YES];
    });
}

-(NSString *)storePath
{
    // Get ~/Library/Data path
    NSArray *paths              = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryPath       = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *dataDirectoryPath = [libraryPath stringByAppendingPathComponent:@"Data"];

    // If the Data directory doesn't exist, create it
    NSFileManager *fileManager  = [[NSFileManager alloc] init];
    if (![fileManager fileExistsAtPath:dataDirectoryPath isDirectory:nil])
        [fileManager createDirectoryAtPath:dataDirectoryPath withIntermediateDirectories:NO attributes:nil error:nil];

    // Return the path of this class' store (<ClassName>.json)
    return [dataDirectoryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", NSStringFromClass([self class])]];
}

@end
