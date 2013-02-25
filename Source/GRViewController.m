//
//  GRViewController.m
//  Gravy
//
//  Created by Nathan Tesler on 26/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRViewController.h"
#import "GRSerialization.h"

@interface GRViewController ()

@property (strong, nonatomic) NSMutableArray *bindings;
@property (strong, nonatomic) NSMutableArray *collections;

@property (strong, nonatomic) NSMutableArray *sectionChanges;
@property (strong, nonatomic) NSMutableArray *objectChanges;

@end

@implementation GRViewController

#pragma mark - Object handling

/* Here we create bindings, to serve one of two purposes:
 1. To connect a control with an object and automatically update both as the other changes.
 2. To have a simple, uniform interface for calling a block when an object or control changes.
 The bulk of the bindings logic is in GRBinding, this is just a simple API for creating bindings.
 */

-(void)registerControl:(id)control forKeyPath:(NSString *)keyPath
{
    [self bindControl:control keyPath:keyPath changeHandler:nil valueTransformer:nil];
}

-(void)registerControl:(id)control forKeyPath:(NSString *)keyPath valueTranformer:(GRBindingValueTransformer)valueTransformer
{
    // Assert that control and object are not nil
    NSAssert(control, @"Cannot register a nil control. Check that this method is not being called before viewDidLoad.");
    NSParameterAssert(keyPath);

    [self bindControl:control keyPath:keyPath changeHandler:nil valueTransformer:valueTransformer];
}

-(void)observeControl:(id)control changeHandler:(GRBindingChangeHandler)changeHandler
{
    // Assert that the control and change handler are not nil.
    NSParameterAssert(control);
    NSParameterAssert(changeHandler);

    [self bindControl:control keyPath:nil changeHandler:changeHandler valueTransformer:nil];
}

-(void)observeKeyPath:(NSString *)keyPath changeHandler:(GRBindingChangeHandler)changeHandler
{
    // Assert that the keypath and change handler are not nil.
    NSParameterAssert(keyPath);
    NSParameterAssert(changeHandler);

    [self bindControl:nil keyPath:keyPath changeHandler:changeHandler valueTransformer:nil];
}

-(void)bindControl:(id)control keyPath:(NSString *)keyPath changeHandler:(GRBindingChangeHandler)changeHandler valueTransformer:(GRBindingValueTransformer)valueTransformer
{
    // Create binding with parameters
    GRBinding *binding = [[GRBinding alloc] init];
    binding.control = control;
    binding.changeHandler = changeHandler;
    binding.valueTransformer = valueTransformer;

    // Add object and keypath to binding if there's a keypath
    // The keypath must be in the format self.object.property or object.property
    if (keyPath)
    {
        // Get all keys from the path
        NSArray *keys = [keyPath componentsSeparatedByString:@"."];

        // Check that the keypath is compatible
        NSAssert1([keys count] == 2, @"The keypath \"%@\" is not compatible. It should be in the format \"self.object.property\".", keyPath);

        // Get object key
        NSString *objectKey = [keys objectAtIndex:0];

        // Check that this class has a property corresponding to this keypath
        NSAssert2([self respondsToSelector:NSSelectorFromString(objectKey)], @"This class does not respond to the selector \"%@\" in keyPath \"%@\"", objectKey, keyPath);

        // Get the object
        id object = [self valueForKey:objectKey];

        // Set the object and keypath to the object on the binding
        binding.object = object;
        binding.keyPath = objectKey;

        // Get the property key
        NSString *propertyKey = [keys objectAtIndex:1];

        // Check that the object responds to the property;
        NSAssert3([object respondsToSelector:NSSelectorFromString(propertyKey)], @"The object %@ does not respond to the selector \"%@\". KeyPath: \"%@\" ", object, propertyKey, keyPath);

        // Set the property on the binding
        binding.property = propertyKey;

        // Observe the keypath of the object
        [self addObserver:self forKeyPath:objectKey options:0 context:nil];
    }

    // Setup the binding
    [binding bind];

    // Create the bindings array to hold a strong reference to the binding, while the source holds a weak one.
    // When the bindings are removed from the view controller or the view controller is deallocated, the binding will be deallocated and deregister itself from the source.
    if (!self.bindings)
        self.bindings = [NSMutableArray array];

    // Add this binding to the array
    [self.bindings addObject:binding];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // Observe changes to the property
    for (GRBinding *binding in self.bindings)
        if ([binding.keyPath isEqualToString:keyPath])
            binding.object = [self valueForKey:keyPath];
}

-(void)deregisterObject:(id)object
{
    // Filter out any bindings that contain this object. The bindings will lose their retain count and be dealloced.
    [self.bindings filterUsingPredicate:[NSPredicate predicateWithFormat:@"object != %@", object]];
}

-(void)dealloc
{
    // Remove observers for bound keypath changes
    for (GRBinding *binding in self.bindings)
        [self removeObserver:self forKeyPath:binding.keyPath];
}

#pragma mark - Collection handling

/* Here we are providing a consistent API for connecting a GRCollection with a UITableView or UICollectionView. It uses a similarly worded API (registerControl:withObject vs. registerContentView:withCollection). However, instead of bindings, it implements the boilerplate delegate and dataSource methods common to most implementations, and implements the GRCollectionDelegate to respond to changes to the data. 
 
 If you need to customize this behaviour, you can freely implement any UITableView/UICollectionView delegate and datasource method, but exercise caution when overriding the core methods, as GRViewController relies on these behaviours (-numberOfSections..., -numberOfRows..., -cellForRow... and -didSelectRow...)
 */

static NSString * const GRViewControllerCollectionKey       = @"GRViewControllerCollection";
static NSString * const GRViewControllerContentViewKey      = @"GRViewControllerContentView";
static NSString * const GRViewControllerCustomizeHandlerKey = @"GRViewControllerCustomizeHandler";
static NSString * const GRViewControllerSelectionHandlerKey = @"GRViewControllerSelectionHandler";
static NSString * const GRCellIdentifier                    = @"Cell";

-(void)registerContentView:(id)contentView forCollection:(GRCollection *)collection customizeHandler:(GRCellCustomizeHandler)customizeHandler selectionHandler:(GRCellSelectionHandler)selectionHandler
{
    [self registerContentView:contentView forCollection:collection cellSubclass:Nil customizeHandler:customizeHandler selectionHandler:selectionHandler];
}

-(void)registerContentView:(id)contentView forCollection:(GRCollection *)collection cellSubclass:(Class)cellSubclass selectionHandler:(GRCellSelectionHandler)selectionHandler
{
    [self registerContentView:contentView forCollection:collection cellSubclass:cellSubclass customizeHandler:nil selectionHandler:selectionHandler];
}

-(void)registerContentView:(id)contentView forCollection:(GRCollection *)collection cellSubclass:(__unsafe_unretained Class)cellSubclass customizeHandler:(GRCellCustomizeHandler)customizeHandler selectionHandler:(GRCellSelectionHandler)selectionHandler
{
    // Check that this is either a UICollectionView or UITableView
    NSAssert([contentView isKindOfClass:[UITableView class]] || [contentView isKindOfClass:[UICollectionView class]], @"Attempting to register a contentView that is not a UITableView or UICollectionView.");

    // Make sure a collection was given
    NSParameterAssert(collection);

    // Set delegate and datasource for the content view
    [contentView setDataSource:self];
    [contentView setDelegate:self];

    // Set the delegate for the collection
    [collection setDelegate:self];

    // Create an array to hold the collections
    if (!self.collections)
        self.collections = [NSMutableArray array];

    // Add collection/contentView info to the collections array
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:collection forKey:GRViewControllerCollectionKey];
    [info setObject:contentView forKey:GRViewControllerContentViewKey];
    if (selectionHandler) [info setObject:selectionHandler forKey:GRViewControllerSelectionHandlerKey];
    if (customizeHandler) [info setObject:customizeHandler forKey:GRViewControllerCustomizeHandlerKey];
    [self.collections addObject:[info copy]];

    // Check that the cell responds to GRContentCell.
    // A nil cellSubclass is only allowed if we're using a UITableView, because UICollectionView needs a cell subclass.
    if (cellSubclass || [contentView isKindOfClass:[UICollectionView class]])
        NSAssert1([cellSubclass conformsToProtocol:@protocol(GRContentCell)], @"Cell subclass %@ must conform to GRContentCell and respond to the selector updateCellForObject:, declared in GRCollection.h", NSStringFromClass(cellSubclass));

    if (cellSubclass)
    {
        // Register the cell subclass (yay for inconsistent APIs!!!)
        if ([contentView isKindOfClass:[UITableView class]])
            [contentView registerClass:cellSubclass forCellReuseIdentifier:GRCellIdentifier];
        else if ([contentView isKindOfClass:[UICollectionView class]])
            [contentView registerClass:cellSubclass forCellWithReuseIdentifier:GRCellIdentifier];
    }
}

#pragma mark - UITableView/UICollectionView delegate/dataSource methods

// Getting corresponding objects from the collection information

-(id)objectWithKey:(NSString *)desiredKey inCollectionInfoForObject:(id)object withKey:(NSString *)existingKey
{
    for (NSDictionary *info in self.collections)
    {
        if (info[existingKey] == object)
            return info[desiredKey];
    }

    return nil;
}

-(GRCollection *)collectionForContentView:(id)contentView
{
    return [self objectWithKey:GRViewControllerCollectionKey inCollectionInfoForObject:contentView withKey:GRViewControllerContentViewKey];
}

// Sections

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self collectionForContentView:tableView] numberOfSections];
}

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [[self collectionForContentView:collectionView] numberOfSections];
}

// Items

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self collectionForContentView:tableView] numberOfObjectsInSection:section];
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [[self collectionForContentView:collectionView] numberOfObjectsInSection:section];
}

// Cells

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Dequeue or create cell
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:GRCellIdentifier];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:GRCellIdentifier];

    // Prompt cell customization
    [self promptCustomizeCell:cell forContentView:tableView atIndexPath:indexPath];

    return cell;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // Dequeue cell (UICollectionViewCells cannot be created unless a class is registered)
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:GRCellIdentifier forIndexPath:indexPath];

    // Prompt cell customization
    [self promptCustomizeCell:cell forContentView:collectionView atIndexPath:indexPath];

    return cell;
}

// Customization

-(GRCellCustomizeHandler)customizeHandlerForContentView:(id)contentView
{
    return [self objectWithKey:GRViewControllerCustomizeHandlerKey inCollectionInfoForObject:contentView withKey:GRViewControllerContentViewKey];
}

-(void)promptCustomizeCell:(id)cell forContentView:(id)contentView atIndexPath:(NSIndexPath *)indexPath
{
    // Get the object to customize
    id object = [[self collectionForContentView:contentView] objectAtIndexPath:indexPath];

    // If the cell conforms to GRContentCell, send it an update message
    if ([cell conformsToProtocol:@protocol(GRContentCell)])
        [cell updateCellForObject:object];

    // If there is a customizeHandler, execute it
    else if ([self customizeHandlerForContentView:contentView])
        [self customizeHandlerForContentView:contentView](cell, object);
}

// Selection

-(GRCellSelectionHandler)selectionHandlerForContentView:(id)contentView
{
    return [self objectWithKey:GRViewControllerSelectionHandlerKey inCollectionInfoForObject:contentView withKey:GRViewControllerContentViewKey];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    id object = [[self collectionForContentView:tableView] objectAtIndexPath:indexPath];
    [self selectionHandlerForContentView:tableView](object);
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    id object = [[self collectionForContentView:collectionView] objectAtIndexPath:indexPath];
    [self selectionHandlerForContentView:collectionView](object);
}

#pragma mark - Delegates

/* Here we are implementing a generic delegate protocol for responding to changes in the GRCollection's data, prompted by changes to the GRSource's data. This should be familiar to anyone who's worked with NSFetchedResultsControllerDelegate.
 */

-(id)contentViewWithCollection:(GRCollection *)collection
{
    return [self objectWithKey:GRViewControllerContentViewKey inCollectionInfoForObject:collection withKey:GRViewControllerCollectionKey];
}

-(void)collectionWillChangeContent:(GRCollection *)collection
{
    id contentView = [self contentViewWithCollection:collection];
    if ([contentView isKindOfClass:[UITableView class]])
        [contentView beginUpdates];
}

-(void)collection:(GRCollection *)collection didChangeSectionAtIndex:(NSInteger)index changeType:(GRObjectChangeType)changeType
{
    id contentView = [self contentViewWithCollection:collection];
    if ([contentView isKindOfClass:[UITableView class]])
    {
        switch(changeType)
        {
            case GRObjectChangeTypeInsert:
                [contentView insertSections:[NSIndexSet indexSetWithIndex:index] withRowAnimation:UITableViewRowAnimationFade];
                break;

            case GRObjectChangeTypeDelete:
                [contentView deleteSections:[NSIndexSet indexSetWithIndex:index] withRowAnimation:UITableViewRowAnimationFade];
                break;
        }
    }
    else if ([contentView isKindOfClass:[UICollectionView class]])
    {
        NSMutableDictionary *change = [NSMutableDictionary new];

        switch(changeType)
        {
            case GRObjectChangeTypeInsert:
                change[@(changeType)] = @(index);
                break;
            case GRObjectChangeTypeDelete:
                change[@(changeType)] = @(index);
                break;
        }

        if (!self.sectionChanges)
            self.sectionChanges = [NSMutableArray array];

        [self.sectionChanges addObject:change];
    }
}

-(void)collection:(GRCollection *)collection didChangeObjectAtIndexPath:(NSIndexPath *)indexPath changeType:(GRObjectChangeType)changeType
{
    id contentView = [self contentViewWithCollection:collection];
    if ([contentView isKindOfClass:[UITableView class]])
    {
        switch(changeType)
        {
            case GRObjectChangeTypeInsert:
                [contentView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                break;

            case GRObjectChangeTypeDelete:
                [contentView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                break;

            case GRObjectChangeTypeUpdate:
                [contentView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                break;
        }
    }
    else if ([contentView isKindOfClass:[UICollectionView class]])
    {
        NSMutableDictionary *change = [NSMutableDictionary new];
        switch(changeType)
        {
            case GRObjectChangeTypeInsert:
                change[@(changeType)] = indexPath;
                break;
            case GRObjectChangeTypeDelete:
                change[@(changeType)] = indexPath;
                break;
            case GRObjectChangeTypeUpdate:
                change[@(changeType)] = indexPath;
                break;
        }

        // Create objectChanges array if necessary
        if (!self.sectionChanges)
            self.sectionChanges = [NSMutableArray array];

        // Add this changes dictionary
        [self.sectionChanges addObject:change];
    }
}

-(void)collectionDidChangeContent:(GRCollection *)collection
{
    id contentView = [self contentViewWithCollection:collection];
    if ([contentView isKindOfClass:[UITableView class]])
    {
        [contentView endUpdates];
    }
    else if ([contentView isKindOfClass:[UICollectionView class]])
    {
        if ([self.sectionChanges count] > 0)
        {
            [contentView performBatchUpdates:^{

                for (NSDictionary *change in self.sectionChanges)
                {
                    [change enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, id obj, BOOL *stop) {

                        GRObjectChangeType changeType = [key unsignedIntegerValue];
                        switch (changeType)
                        {
                            case GRObjectChangeTypeInsert:
                                [contentView insertSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                                break;
                            case GRObjectChangeTypeDelete:
                                [contentView deleteSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                                break;
                            case GRObjectChangeTypeUpdate:
                                [contentView reloadSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                                break;
                        }
                    }];
                }
            } completion:nil];
        }

        if ([self.objectChanges count] > 0 && [self.sectionChanges count] == 0)
        {
            [contentView performBatchUpdates:^{

                for (NSDictionary *change in self.objectChanges)
                {
                    [change enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, id obj, BOOL *stop) {

                        GRObjectChangeType changeType = [key unsignedIntegerValue];
                        switch (changeType)
                        {
                            case GRObjectChangeTypeInsert:
                                [contentView insertItemsAtIndexPaths:@[obj]];
                                break;
                            case GRObjectChangeTypeDelete:
                                [contentView deleteItemsAtIndexPaths:@[obj]];
                                break;
                            case GRObjectChangeTypeUpdate:
                                [contentView reloadItemsAtIndexPaths:@[obj]];
                                break;
                        }
                    }];
                }
            } completion:nil];
        }

        [self.sectionChanges removeAllObjects];
        [self.objectChanges removeAllObjects];
    }
}

@end
