//
//  GRSource.m
//  Gravy
//
//  Created by Nathan Tesler on 25/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRSource.h"

/* The static variable that holds all our application's sources. Subclasses will access this same variable. */
static NSMutableArray *sources = nil;

@interface GRSource ()

/* The observers of the source. */
@property (strong, nonatomic) NSMutableArray *observers;
@end

@implementation GRSource

#pragma mark - Initialization

+(instancetype)source:(Class)managedClass
{
    // Check that the class argument is provided
    NSParameterAssert(managedClass);

    // If a source exists for this class, return it.
    for (GRSource *source in sources)
    {
        // We identify each source with its managedClass property.
        // A class can only have one source.
        if (source.managedClass == managedClass)
            return source;
    }

    // No source for this class, initialize and return one
    return [[self alloc] initWithManagedClass:managedClass];
}

-(id)initWithManagedClass:(Class)managedClass
{
    // We put this logic into a custom initializer so that subclasses can call [super initWithManagedClass:] and access all of the properties from their custom init methods.
    if (self = [super init])
    {
        // Set the class that identifies the store
        _managedClass = managedClass;

        // Add arrays that hold all the source's objects, collections and bindings. As the source owns its objects, it receives messages when the objects are added, changed or deleted, which it then passes to its collections and bindings.
        _objects     = [NSMutableArray array];
        _observers   = [NSMutableArray array];

        // Create the sources array if it does not exist
        if (!sources)
            sources = [NSMutableArray array];

        // Add the source to the sources array
        [sources addObject:self];
    }

    return self;
}

#pragma mark - Object registration & notifications

-(void)registerObject:(GRObject *)object
{
    // Check that a GRObject of this source's class is being registered
    NSAssert2([object isKindOfClass:self.managedClass], @"Only instances of the source's managed class can be registered with a GRSource. Did you mean to call registerObserver: instead of registerObject:? Source class: %@, given object: %@", NSStringFromClass(self.managedClass), object);

    // Add this object to the store
    [self.objects addObject:object];

    // Notify observers of the new object
    [self notifyObserversOfObjectChange:object type:GRObjectChangeTypeInsert keyPath:nil];
}

-(void)notifyUpdatedObject:(GRObject *)object withChangedKeyPath:(NSString *)changedKeyPath
{
    // Notify observers of the update
    [self notifyObserversOfObjectChange:object type:GRObjectChangeTypeUpdate keyPath:changedKeyPath];
}

-(void)deregisterObject:(GRObject *)object
{
    // Notify observers of removed object
    [self notifyObserversOfObjectChange:object type:GRObjectChangeTypeDelete keyPath:nil];

    // Remove this object from the store
    [self.objects removeObject:object];
}

-(void)notifyObserversOfObjectChange:(GRObject *)object type:(GRObjectChangeType)change keyPath:(NSString *)keyPath
{
    // Get the observer by unthawing the NSValue, send it the update message
    for (NSValue *observerValue in self.observers)
        [[observerValue nonretainedObjectValue] source:self didUpdateObject:object changeType:change keyPath:keyPath];
}

#pragma mark - Observer notifications

-(void)registerObserver:(id)observer
{
    // Add this observer to the observers array so it can be notified of data updates
    [self.observers addObject:[NSValue valueWithNonretainedObject:observer]];
}

-(void)deregisterObserver:(id)observer
{
    // Remove this collection from the collections array
    [self.observers removeObject:[NSValue valueWithNonretainedObject:observer]];
}

@end
