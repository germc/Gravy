//
//  GRObject.m
//  Gravy
//
//  Created by Nathan Tesler on 25/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRObject.h"
#import "GRSource.h"
#import "GRCollection.h"
#import <objc/runtime.h>

NSString * const GRObjectChangesChangeKey = @"change";
NSString * const GRObjectChangesTimestampKey = @"timestamp";

@interface GRObject ()

@property (strong, nonatomic) NSString *uniqueIdentifier;
@property (strong, nonatomic) NSDate *creationDate;
@property (strong, nonatomic) NSDate *updateDate;

@end

@implementation GRObject

-(id)init
{
    if (self = [super init])
    {
        // Set metadata about the object
        self.uniqueIdentifier = [[NSUUID UUID] UUIDString];
        self.creationDate     = [NSDate date];
        self.updateDate       = [NSDate date];

        // Start observing properties from -observedChanges to notify the source of changes and update the changes dictionary and updateDate
        [self observeChanges];
    }

    return self;
}

+(GRSource *)source
{
    return [GRSource source:self];
}

+(instancetype)objectWithUniqueIdentifier:(NSString *)uniqueIdentifier
{
    // Return the object that matches the uniqueIdentifier, or nil if none match
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uniqueIdentifier == %@", uniqueIdentifier];
    return [[[[self source] objects] filteredArrayUsingPredicate:predicate] lastObject];
}

-(void)save
{
    /* This method registers the object with the class' source. The source then takes ownership of the object. This line of code could easily have been put into the init method, but we do this create-customize-save dance for two reasons:
     1. If you're just creating an object and not customizing it, it feels weird to just call [[MYObject alloc] init] and nothing else. In fact, the compiler will complain that the expression's result is unused.
     2. This method gives subclasses of GRSource a hook to perform more complex save actions, like persisting to disk or syncing to a server, while providing a consistant API.
     3. For some reason, you may not want to register your GRObject with its GRSource. 
     
     So the general rule is, don't call save or registerObject: in an -init method.
     */

    // If the object is not registered with the source, add it now.
    [[[self class] source] registerObject:self];
}

-(void)remove
{
    // Deregister object with it's source
    [[[self class] source] deregisterObject:self];
}

-(void)dealloc
{
    // We must remove observers in -dealloc, even on ARC.
    [self removeObservers];
}

#pragma mark - Observing changes

-(NSArray *)observableProperties
{
    // Returns an array of all properties except metadata
    NSMutableArray *allProperties = [[[self class] propertiesOfType:nil] mutableCopy];
    [allProperties removeObject:@"uniqueIdentifier"];
    [allProperties removeObject:@"updateDate"];
    [allProperties removeObject:@"creationDate"];
    [allProperties removeObject:@"changes"];

    return [allProperties copy];
}

-(void)observeChanges
{
    // Observe all keypaths except metadata (to update updateDate and notify GRSource of changes)
    for (NSString *property in [self observableProperties])
        [self addObserver:self forKeyPath:property options:NSKeyValueObservingOptionNew context:nil];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Set updateDate
    self.updateDate = [NSDate date];

    // Notify external observers
    [[[self class] source] notifyUpdatedObject:self withChangedKeyPath:keyPath];
}

-(void)removeObservers
{
    // Iterate through each observer in the filteredObservedChanges array and remove it
    for (NSString *property in [self observableProperties])
        [self removeObserver:self forKeyPath:property context:nil];
}

-(NSArray *)relationship:(NSString *)property class:(Class)class
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%s.uniqueIdentifier == %@", property, self.uniqueIdentifier];
    return [GRCollection collectionWithClass:class predicate:predicate].objects;
}

#pragma mark - Description

-(NSString *)description
{
    NSDictionary *properties = [[self class] classProperties];
    NSMutableString *description = [NSMutableString string];
    for (NSString *property in properties)
    {
        if ([property isEqualToString:keypath(self.uniqueIdentifier)])
            continue;

        id value       = [self valueForKey:property];
        NSString *type = [properties valueForKey:property];

        [description appendFormat:@"      %@ (%@): %@\r", property, type, value];
    }

    return [NSString stringWithFormat:@"%@ (%@): \r%@", NSStringFromClass([self class]), self.uniqueIdentifier, description];
}

#pragma mark - GRSerializable

-(instancetype)initWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation context:(NSString *)context
{
    if (self = [super init])
    {
        // Create the object from a dictionary where every key is a property and every value is its value
        for (NSString *property in dictionaryRepresentation)
        {
            // We check that self responds to the key so that we can simply ignore extraneous keys
            if ([self respondsToSelector:NSSelectorFromString(property)])
                [self setValue:[dictionaryRepresentation valueForKey:property] forKey:property];
        }

        // Start observing properties from -observedChanges to notify the source of changes and update the changes dictionary and updateDate
        [self observeChanges];
    }

    return self;
}

-(NSDictionary *)uniqueIndexWithContext:(NSString *)context
{
    return @{ keypath(self.uniqueIdentifier): self.uniqueIdentifier };
}

-(instancetype)initWithUniqueIndex:(NSDictionary *)uniqueIndex context:(NSString *)context
{
    // Create predicate with uniqueIdentifier as
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uniqueIdentifier == %@", uniqueIndex[keypath(self.uniqueIdentifier)]];

    // Return the object with that predicate
    return [[[[[self class] source] objects] filteredArrayUsingPredicate:predicate] lastObject];
}

@end
