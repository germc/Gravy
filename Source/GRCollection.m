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
    return [self collectionWithClass:class sortDescriptors:nil predicate:nil];
}

+(GRCollection *)collectionWithClass:(Class)class sortDescriptors:(NSArray *)sortDescriptors
{
    return [self collectionWithClass:class sortDescriptors:sortDescriptors predicate:nil];
}

+(GRCollection *)collectionWithClass:(Class)class predicate:(NSPredicate *)predicate
{
    return [self collectionWithClass:class sortDescriptors:nil predicate:predicate];
}

+(GRCollection *)collectionWithClass:(Class)class sortDescriptors:(NSArray *)sortDescriptors predicate:(NSPredicate *)predicate
{
    return [[GRCollection alloc] initWithClasses:@[class] sortDescriptors:sortDescriptors predicate:predicate];
}

typedef void(^GRCollectionParameterSort)(NSArray *);

+(GRCollection *)collectionWithParameters:(NSArray *)parameters
{
    // Placeholders for three parameter types
    NSMutableArray *classes         = [NSMutableArray array];
    NSMutableArray *predicates      = [NSMutableArray array];
    NSMutableArray *sortDescriptors = [NSMutableArray array];

    // Iterate through parameters and divide into these types
    [self sortParameters:parameters intoClasses:classes predicates:predicates sortDescriptors:sortDescriptors];

    // Replace predicate array with compound predicate
    NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];

    // Return the collection
    return [[self alloc] initWithClasses:classes sortDescriptors:sortDescriptors predicate:predicate];
}

+(void)sortParameters:(NSArray *)parameters intoClasses:(NSMutableArray *)classes predicates:(NSMutableArray *)predicates sortDescriptors:(NSMutableArray *)sortDescriptors
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

        // Recursively divide in arrays
        if ([parameter isKindOfClass:[NSArray class]])
            [self sortParameters:parameter intoClasses:classes predicates:predicates sortDescriptors:sortDescriptors];
    }
}

-(id)initWithClasses:(NSArray *)classes sortDescriptors:(NSArray *)sortDescriptors predicate:(NSPredicate *)predicate
{
    if (self = [super init])
    {
        // A custom initializer is used here to set the instance variables rather than call properties.
        // This is so that refreshObjects is triggered only once, manually.
        _classes         = classes;
        _sortDescriptors = sortDescriptors;
        _predicate       = predicate;

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

#pragma mark - Setters

-(void)setClasses:(NSArray *)classes
{
    // Changing classes means we need to deregister the collection with the current sources and register it with the new ones.
    [self deregisterClasses];
    _classes = classes;
    [self registerClasses];

    [self refreshObjects];
}

-(void)setSortDescriptors:(NSArray *)sortDescriptors
{
    _sortDescriptors = sortDescriptors;

    [self refreshObjects];
}

-(void)setPredicate:(NSPredicate *)predicate
{
    _predicate = predicate;

    [self refreshObjects];
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

    // Profit!!!
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

#pragma mark - Handling changes

-(void)source:(GRSource *)source didUpdateObject:(GRObject *)object changeType:(GRObjectChangeType)changeType keyPath:(NSString *)keyPath
{
    // Only refresh the collection's objects if the object is not precluded by the predicate
    if (self.predicate && ![self.predicate evaluateWithObject:object] && ![self.objects containsObject:object])
        return;

    // Notify of impending change
    [self.delegate collectionWillChangeContent:self];

    // Refresh dataset
    [self refreshObjects];

    // Notify delegate of specific change
    [self.delegate collection:self didChangeObjectAtIndexPath:[self indexPathOfObject:object] changeType:changeType];

    // Notify delegate of completed change
    [self.delegate collectionDidChangeContent:self];
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
