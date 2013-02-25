//
//  GRSource.h
//  Gravy
//
//  Created by Nathan Tesler on 25/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GRObject.h"

/* GRSource is the model-controller layer of your application that manages your application's objects. Each subclass of GRObject has a single source, and a source can only correspond to one GRObject subclass. Each source has an objects array that contains all the objects of its managed class, and can notify observers when any of these objects changes, is added or removed. */

@protocol GRSourceObserver;
@interface GRSource : NSObject <GRObjectRegistrar>

/* Returns the source corresponding to the given class. You should always access a source with this method. */
+(instancetype)source:(Class)managedClass;

/* The designated initializer for GRSource. You should never call this in your own code, but you may override it in a subclass and call `[super initWithManagedClass:]` to customize your source when it's created. */
-(id)initWithManagedClass:(Class)managedClass;

/* The class managed by the source. A source can only have one class, and every class has its own source. */
@property (strong, nonatomic, readonly) Class managedClass;

/* All objects of the managed class that are registered with the source. */
@property (strong, nonatomic) NSMutableArray *objects;

/* Registers an observer with the source. The source will receive source:didUpdateObject:changeType:keyPath: when any object is added, updated or removed. */
-(void)registerObserver:(id<GRSourceObserver>)observer;

/* Deregisters an observer with the source so it no longer receives change messages. You must call this in the observer's dealloc method. */
-(void)deregisterObserver:(id<GRSourceObserver>)observer;

@end

/* GRSourceObserver defines the change message that is sent to observers of GRSource. */
@protocol GRSourceObserver

/* Sent whenever an object in a GRSource is added, updated or removed.
 @param source The source that changed
 @param object The affected object
 @param changeType The change that occured to the object
 @param keyPath If the object was updated, this is the name of the changed property, otherwise nil
 */
-(void)source:(GRSource *)source didUpdateObject:(GRObject *)object changeType:(GRObjectChangeType)changeType keyPath:(NSString *)keyPath;

@end
