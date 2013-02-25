//
//  GRObject.h
//  Gravy
//
//  Created by Nathan Tesler on 25/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GRSerialization.h"

#define keypath(PATH) \
[NSString stringWithUTF8String:(((void)(NO && ((void)PATH, NO)), strchr(# PATH, '.') + 1))]

/* GRObject is an abstract subclass of NSObject that acts as the model layer of your application and encapsulates the data your application works with. GRObject works in conjunction with its model controller, GRSource (one source per GRObject subclass) to provide custom functionality like persistance. GRObjects behave like vanilla NSObjects, but have two pieces of extra functionality.
 
 1. Metadata: Automatically generated and maintained metadata (creationDate, updateDate, uniqueIdentifier)
 2. Source management: Methods for accessing the object's source, retrieving, saving and removing an object from its source.
 */

@interface GRObject : NSObject <GRSerializable>

///
/// Metadata
///

/* A unique string that identifies the object. Generated in `-init` using NSUUID. */
@property (strong, nonatomic, readonly) NSString *uniqueIdentifier;

/* An timestamp indicating when the object was created. Set in `-init`. */
@property (strong, nonatomic, readonly) NSDate *creationDate;

/* A timestamp indicating when the object last changed any of its public non-metadata properties. */
@property (strong, nonatomic, readonly) NSDate *updateDate;

///
/// Source management
///

/* The source that manages the object. You should override this method in your subclass and call GRSource's `-source:` method to return the source of the object.
 
 For example, if you're using a GRLocalSource for your GRObject subclass, override this method with the implementation `return [GRLocalSource source:self]`.

 @return The source that corresponds to this GRObject subclass.
 @see GRSource
 */
+(id)source;

/* Returns the object of the receiving class whose `uniqueIdentifier` property matches the given identifier. */
+(instancetype)objectWithUniqueIdentifier:(NSString *)uniqueIdentifier;

/* By default, this method simply registers the object with its source. The source then takes ownership of the object. You should override this method to provide custom saving behaviour, such as writing to disk or submitting to a server. Remember to call `[super save]` so that the object is registered. */
-(void)save;

/* By default, this method deregisters the object with its source. As the source holds a strong reference to the object, this can cause the object to be deallocated if no one holds a pointer to it. You can override this method in your subclass to provide custom behaviour. Generally you should call `[super remove]` in your implementation to deregister the object. However, if you want to implement psuedo-deletion, for example by setting a 'removed' property to YES, you should not call super. */
-(void)remove;

///
/// Relationships
///

/* Relationships in Gravy are child to parent, where the child holds a reference to the parent object. If a parent needs to access its children, it can call this method to recieve an array of its children. For example, given a MYUser object that has a to-many relationship with the MYPost class:
 
    NSArray *currentUserPosts = [user relationship:@"author" ofClass:[MYPost class]];
 
 then this method will return every MYPost object that contains the receiving object in its `author` property.
 
 @param property The relationship property on the destination class
 @param class The destination class of the relationship
 @return An array of objects of the destination class that are part of this relationship.
*/
-(NSArray *)relationship:(NSString *)property ofClass:(Class)class;

@end

// A generic typedef used to denote changes to an object.
enum GRObjectChangeType {
    GRObjectChangeTypeInsert = 1 << 0,
    GRObjectChangeTypeUpdate = 1 << 1,
    GRObjectChangeTypeDelete = 1 << 2,
};
typedef NSUInteger GRObjectChangeType;

// Keys that are used to inspect the `changes` dictionary
extern NSString * const GRObjectChangesChangeKey;
extern NSString * const GRObjectChangesTimestampKey;

/* GRObjectRegistrar provides an interface for GRObjects to register themselves with the GRSource. These methods are declared here because they are only used by the GRObject. You generally wouldn't call these methods yourself.
*/
@protocol GRObjectRegistrar

/* Registers the GRObject with the receiver. The receiver should hold a strong reference to the object.
 @param object The object to register
 */
-(void)registerObject:(GRObject *)object;

/* Notifies the receiver that the object changed the value of the property at the given keypath.
 @param object The object that changed
 @param changedKeyPath The keypath that was affected by the change
 */
-(void)notifyUpdatedObject:(GRObject *)object withChangedKeyPath:(NSString *)changedKeyPath;

/* Deregisters the GRObject with the receiver. The receiver should release its reference to the object.
 @param object The object to deregister
 */
-(void)deregisterObject:(GRObject *)object;
@end
