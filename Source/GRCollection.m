//
//  GRCollection.m
//  Gravy
//
//  Created by Nathan Tesler on 26/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRCollection.h"
#import "GRSource.h"

@interface GRCollection ()
@property (strong, nonatomic) NSArray *objects;
@end

@implementation GRCollection

#pragma mark - Builders

+(GRCollection *)collectionWithClass:(Class)class
{
    return [self collectionWithClass:class sortDescriptor:nil predicate:nil];
}

+(GRCollection *)collectionWithClass:(Class)class sortDescriptor:(NSSortDescriptor *)sortDescriptor
{
    return [self collectionWithClass:class sortDescriptor:sortDescriptor predicate:nil];
}

+(GRCollection *)collectionWithClass:(Class)class predicate:(NSPredicate *)predicate
{
    return [self collectionWithClass:class sortDescriptor:nil predicate:predicate];
}

+(GRCollection *)collectionWithClass:(Class)class sortDescriptor:(NSSortDescriptor *)sortDescriptor predicate:(NSPredicate *)predicate
{
    return [[GRCollection alloc] initWithClasses:@[class]
                                 sortDescriptors:sortDescriptor ? @[sortDescriptor] : nil
                                      predicates:predicate ? @[predicate] : nil];
}

+(GRCollection *)collectionWithClasses:(NSArray *)classes sortDescriptors:(NSArray *)sortDescriptors predicates:(NSArray *)predicates
{
    return [[GRCollection alloc] initWithClasses:classes sortDescriptors:sortDescriptors predicates:predicates];
}

+(GRCollection *)collectionWithParameters:(id)parameter, ...
{
    // Get parameters array
    NSMutableArray *parameters = [NSMutableArray array];
    va_list args;
    va_start(args, parameter);
    for (id arg = parameter; arg != nil; arg = va_arg(args, id))
        [parameter addObject:parameter];
    va_end(args);

    // Placeholders for three parameter types
    NSMutableArray *classes         = [NSMutableArray array];
    NSMutableArray *predicates      = [NSMutableArray array];
    NSMutableArray *sortDescriptors = [NSMutableArray array];

    // Iterate through parameters and divide into these types
    [self sortParameters:parameters intoClasses:classes sortDescriptors:sortDescriptors predicates:predicates];

    // Return the collection
    return [[self alloc] initWithClasses:classes sortDescriptors:sortDescriptors predicates:predicates];
}

+(void)sortParameters:(NSArray *)parameters intoClasses:(NSMutableArray *)classes sortDescriptors:(NSMutableArray *)sortDescriptors predicates:(NSMutableArray *)predicates
{
    for (id parameter in parameters)
    {
        // Classes
        if ([parameter respondsToSelector:@selector(isSubclassOfClass:)])
            [classes addObject:parameter];

        // Predicate
        if ([parameter isKindOfClass:[NSPredicate class]])
            [predicates addObject:parameter];

        // Sort descriptors
        if ([parameter isKindOfClass:[NSSortDescriptor class]])
            [sortDescriptors addObject:parameter];

        // Recursively divide arrays
        if ([parameter isKindOfClass:[NSArray class]])
            [self sortParameters:parameter intoClasses:classes sortDescriptors:sortDescriptors predicates:predicates];
    }
}

-(id)initWithClasses:(NSArray *)classes sortDescriptors:(NSArray *)sortDescriptors predicates:(NSArray *)predicates
{
    // A custom initializer is used here to set the instance variables rather than call properties.
    // This is so that refreshObjects is triggered only once, manually.
    if (self = [super init])
    {
        // Set parameters
        _classes         = classes;
        _sortDescriptors = sortDescriptors;

        // Compound predicates if more than one
        _predicate = [predicates count] > 1 ?
            [NSCompoundPredicate andPredicateWithSubpredicates:predicates] : [predicates lastObject];

        // Register the collection with the source(s) to be notified when the underlying data changes
        [self registerClasses];

        // Load all the objects
        [self refreshObjects];
    }

    return self;
}

-(void)dealloc
{
    // Remove the collection from its sources
    [self deregisterClasses];
}

-(void)registerClasses
{
    for (Class class in _classes)
        [[class source] registerObserver:self];
}

-(void)deregisterClasses
{
    for (Class class in self.classes)
        [[class source] deregisterObserver:self];
}

#pragma mark - Handling parameter changes

-(void)setClasses:(NSArray *)classes
{
    // Changing classes means we need to deregister the collection with the current sources and register it with the new ones.
    [self deregisterClasses];
    _classes = classes;
    [self registerClasses];

    // Refresh and notify
    [self refreshObjects];
    [self.delegate collectionDidRefreshContent:self];
}

-(void)setSortDescriptors:(NSArray *)sortDescriptors
{
    _sortDescriptors = sortDescriptors;

    // Refresh and notify
    [self refreshObjects];
    [self.delegate collectionDidRefreshContent:self];
}

-(void)setPredicate:(NSPredicate *)predicate
{
    _predicate = predicate;

    // Refresh and notify
    [self refreshObjects];
    [self.delegate collectionDidRefreshContent:self];
}

#pragma mark - Handling data changes

-(void)source:(GRSource *)source didUpdateObject:(GRObject *)object changeType:(GRObjectChangeType)changeType keyPath:(NSString *)keyPath
{
    // Only refresh the collection's objects if the object is not precluded by the predicate
    if (self.predicate && ![self.predicate evaluateWithObject:object] && ![self.objects containsObject:object])
        return;

    // Notify of impending change
    [self.delegate collectionWillChangeContent:self];

    // Declare the indexPath to send to the delegate
    NSIndexPath *indexPath = nil;

    // If the object was not just inserted, we need its indexPath before we refresh
    if (changeType != GRObjectChangeTypeInsert)
        indexPath = [self indexPathOfObject:object];

    // Refresh dataset
    [self refreshObjects];

    // If the object was added/updated, we get the indexPath after the update
    if (!indexPath)
        indexPath = [self indexPathOfObject:object];

    // Notify delegate of specific change
    [self.delegate collection:self didChangeObjectAtIndexPath:indexPath changeType:changeType];

    // Notify delegate of completed change
    [self.delegate collectionDidChangeContent:self];
}

#pragma mark - Populating the array

-(void)refreshObjects
{
    // Get all objects from all classes
    NSMutableArray *allObjects = [NSMutableArray array];
    for (Class class in self.classes)
        [allObjects addObjectsFromArray:[[GRSource source:class] objects]];

    // Apply predicates
    if (self.predicate) [allObjects filterUsingPredicate:self.predicate];

    // Apply sort descriptors
    if (self.sortDescriptors) [allObjects sortUsingDescriptors:self.sortDescriptors];

    // Set a weak reference to each object on the backing store
    NSMutableArray *allWeakObjects = [NSMutableArray array];
    for (id object in allObjects)
        [allWeakObjects addObject:[NSValue valueWithNonretainedObject:object]];

    self.objects = [allWeakObjects copy];

    // Collate the objects
    [self collate];
}

-(void)collate
{
    // Subclasses of GRCollection should override this method to update the sections of the collection as needed
}

#pragma mark - Retrieving objects

-(NSArray *)objects
{
    // Return the objects strongified
    NSMutableArray *strongObjects = [NSMutableArray array];

    // Strongify each object
    for (NSValue *object in _objects)
        [strongObjects addObject:[object nonretainedObjectValue]];

    return [strongObjects copy];
}

#pragma mark - DataSource helpers

// This may seem like a pointless thing to have (why not have the tableView/collectionView's dataSource directly query the collection?) but this is here so subclasses can override this behaviour without affecting the dataSource implementation.

-(NSInteger)numberOfSections
{
    return 1;
}

-(NSInteger)numberOfObjectsInSection:(NSInteger)section
{
    return [self.objects count];
}

-(id)objectAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.objects objectAtIndex:indexPath.row];
}

-(NSIndexPath *)indexPathOfObject:(id)object
{
    return [NSIndexPath indexPathForItem:[self.objects indexOfObject:object] inSection:0];
}

#pragma mark - Description

-(NSString *)description
{
    return [NSString stringWithFormat:@"%@ (%i objects of class(es): %@)",
            NSStringFromClass([self class]), [self.objects count], [self.classes componentsJoinedByString:@", "]];
}

@end
