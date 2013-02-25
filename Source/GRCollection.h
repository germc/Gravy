//
//  GRCollection.h
//  Gravy
//
//  Created by Nathan Tesler on 26/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GRSource.h"
#import "GRSerialization.h"

/* GRCollection fetches and manages a dynamic array of GRObjects. You provide parameters (Class, NSSortDescriptior and/or NSPredicate) and GRCollection automatically populates itself with objects from the classes' sources. You can change any of the parameters and the collection will automatically update. GRCollection will also update whenever an object of any of its classes is added, removed or changed.
 
 # DataSource

 You can use the GRCollection as a UITableView/UICollectionViewDataSource. GRCollection implements basic methods that can be used for providing the necessary data. GRCollection does not implement any type of sectioning behaviour (it pretends as if it has one section containing all its objects), but to implement sectioning you can subclass GRCollection, override -numberOfSections, -numberOfObjectsInSection:, -indexPathOfObject:, and -objectAtIndexPath:, add any other dataSource methods to provide section information, and override -collate to create and update section information as needed.
 */

@protocol GRCollectionDelegate;
@interface GRCollection : NSObject <GRSourceObserver>

/* The collection's delegate. Receives messages when the collection changes. */
@property (strong, nonatomic) id<GRCollectionDelegate> delegate;

///
/// Parameters
///

/* The classes that the collection manages. */
@property (strong, nonatomic) NSArray *classes;

/* The predicate used to filter the objects. */
@property (strong, nonatomic) NSPredicate *predicate;

/* The sort descriptors used to sort the objects. */
@property (strong, nonatomic) NSArray *sortDescriptors;

///
/// Objects
///

/* An NSArray of objects that are in this collection. */
-(NSArray *)objects;

///
/// Initialization
///

/* Creates a GRCollection containing all objects of the given class. */
+(GRCollection *)collectionWithClass:(Class)class;

/* Creates a GRCollection containing all objects of the given class, sorted by the given sort descriptors. */
+(GRCollection *)collectionWithClass:(Class)class sortDescriptors:(NSArray *)sortDescriptors;

/* Creates a GRCollection containing all objects of the given class, filtered by the given predicate.  */
+(GRCollection *)collectionWithClass:(Class)class predicate:(NSPredicate *)predicate;

/* Creates a GRCollection containing all objects of the given class, sorted by the given sort descriptors and filtered by the given predicate.  */
+(GRCollection *)collectionWithClass:(Class)class sortDescriptors:(NSArray *)sortDescriptors predicate:(NSPredicate *)predicate;

/* Creates a GRCollection fetching objects from any classes in the parameters array, filtering with any predicates and sorting with any sort descriptors. 
 @discussion If more than one NSPredicate is supplied, the predicates will become an NSCompoundPredicate using the -andPredicateWithSubpredicates method.
 @param parameters An NSArray of parameters of type Class, NSPredicate or NSSortDescriptor in any order
 */
+(GRCollection *)collectionWithParameters:(NSArray *)parameters;

///
/// Sectioning
///

/* Called whenever the data of the collection updates. Subclasses should override this method to collate the data and update the collection's section information, if needed. */
-(void)collate;

/* DataSource method returning the number of sections in the collection. By default, this method returns 1. */
-(NSInteger)numberOfSections;

/* DataSource method returning the number of objects in the given section. */
-(NSInteger)numberOfObjectsInSection:(NSInteger)section;

/* DataSource method for getting the indexPath of a given object. */
-(NSIndexPath *)indexPathOfObject:(id)object;

/* DataSource method that should return an object that corresponds to the given NSIndexPath. */
-(id)objectAtIndexPath:(NSIndexPath *)indexPath;

@end

/* GRCollectionDelegate provides a way for an object to observe changes to a collection. It is generally implemented by GRViewController to update its UITableView/UICollectionViews to respond to changes in the data.
 */
@protocol GRCollectionDelegate

/* Called when the collection is about to change its data. */
-(void)collectionWillChangeContent:(GRCollection *)collection;

/* Called when the collection view changed a section.
 @param index The index of the affected section
 @param changeType The type of change that occured
 */
-(void)collection:(GRCollection *)collection didChangeSectionAtIndex:(NSInteger)index changeType:(GRObjectChangeType)changeType;

/* Called when the collection view changed an object.
 @param indexPath The indexPath of the affected object
 @param changeType The type of change that occured
 */
-(void)collection:(GRCollection *)collection didChangeObjectAtIndexPath:(NSIndexPath *)indexPath changeType:(GRObjectChangeType)changeType;

/* Called when the collection finishes changing its data. */
-(void)collectionDidChangeContent:(GRCollection *)collection;

@end

/* The GRContentCell protocol is a simple way for UITableViewCell and UICollectionViewCell objects to receive messages when they need to update their views. You custom cell subclass should conform to GRContentCell and implement updateCellForObject: so as to work with GRViewController. */
@class GRObject;
@protocol GRContentCell

/* Called when the cell needs to update its views.
 @param object The model object that the cell should represent.
 */
-(void)updateCellForObject:(id)object;
@end
