//
//  GRSerialization.h
//  Gravy
//
//  Created by Nathan Tesler on 31/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+GRIntrospection.h"

/* GRSerialization allows you to easily serialize almost any object as JSON. While NSJSONSerialization only supports dictionaries, arrays, strings and numbers, GRSerialization can convert many types to JSON. GRSerialization is extremely complex internally, but extremely simple to use, with only 2 methods you need to know.
    
 # Converting custom objects to JSON

 Given a MYUser class that subclasses GRObject and has a name and age property:

    MYUser *user     = [[MYUser alloc] initWithName:@"John" age:40];
    NSData *JSONUser = [GRSerialization JSONWithObject:user options:nil];
    >> { name: "John", age: 40 }
 
 Given an array of MYUser objects:
    
    NSArray *users    = @[ user1, user2, user3 ];
    NSData *JSONUsers = [GRSerialization JSONWithObject:users options:nil];
    >> [{ name: "John" }, { age: 40 }, { name: "Bill", age: 20 }]

 Given a dictionary with arbitrary objects:

    NSDictionary *payload = @{ @"author": user1, @"posts": [ post1, post2 ] };
    NSDate *JSONPayload = [GRSerialization JSONWithObject:users options:nil];
    >> { author: { name: "John" }, posts: [ { text: "Hi" }, { text: "Hello" } ] }

 # Converting JSON to custom objects
 
 Converting JSON data to your custom objects is simple too. You just need to tell GRSerialization what class to serialize to.

    MYUser *user   = [GRSerialization objectWithJSON:JSONUserData class:[MYUser class] options:nil];

 Complex payloads can also be converted. Simply pass in `GRObject` as the destination class and let Gravy infer which subclass of GRObject corresponds to each of the payload keys.

    >> { user: { name: "John" }, posts: [ { text: "Hello world!" }, { text: "My name is John" } ] }
    NSDictionary *payload = [GRSerialization objectWithJSON:payloadData class:[GRObject class] options:nil];
    >> { user: <MYUser>, posts: [ <MYPost>, <MYPost> ] }

 Keys must fully or partially match their corresponding class names (but can be singular or plural). If you are using unusual keys (say "author instead of "user"), see GRSerializable and `+correspondsToKey` for how to easily teach GRSerialization to recognize these keys.

 # Supported types
 
 GRSerialization supports the following types:
    - JSON supported types: NSDictionary, NSArray, NSString, NSNumber
    - Other types: NSData, NSDate
    - Primitives: unsigned and signed int/double/short/long/float, BOOL (plus typedefs like NSInteger and CGFloat)
    - Any object that conforms to GRSerializable and only contains properties of supported types
    - Any object that is of a class taught to GRSerialization with `[GRSerialization learnConversionForClass:converter:]`.
 
 Other types will be ignored by GRSerialization and will cause an unsupported type exception when handled by NSJSONSerialization. Blocks are entirely unsupported. It is impossible to represent a block as JSON.
 */

@interface GRSerialization : NSObject

/* Converts the given object to JSON using the options supplied. */
+(NSData *)JSONWithObject:(id)object options:(NSDictionary *)options;

/* Converts the given JSON data to an object of the specified class, using the given options. `class` is optional. */
+(id)objectWithJSON:(NSData *)JSON class:(Class)class options:(NSDictionary *)options;

/* Teaches GRSerialization how to convert an object of the given class to a JSON-safe object, or from a JSON-safe object to an instance of the class. Executes the block when attempting a conversion, and uses the return value of the block in the serialization. For example, if you want to serialize an NSPredicate, you can call the following code:
    
    [GRSerailization learnConversionForClass:[NSPredicate class] toJSONConverter:^(NSPredicate *predicate, NSString *format){
         if (predicate)
            return predicate.predicateFormat;
         else
            return [NSPredicate predicateWithFormat:format];
    }];
 */
typedef id(^GRSerializationConverter)(id toJSONValue, id fromJSONValue);
+(void)learnConversionForClass:(Class)class converter:(GRSerializationConverter)converter;

@end

/* The GRSerializable protocol provides methods that your classes can implement to allow and customize serialization. The only required method is initWithDictionaryRepresentation:context:, which asks the class to return an instance given the data derived from JSON. The other methods are optional and allow you to customize the way your objects are serialized.
 */

@protocol GRSerializable

///
/// Serialization
///

/* The custom initializer called by GRSerialization when converting JSON data to objects. Classes that conform to GRSerializable must implement this method to recreate an object from the dictionaryRepresentation supplied.
 
 @param dictionaryRepresentation A dictionary containing keys representing property names and values representing property values.
 @param context The reason/originator of the serialization. You can inspect this value to determine the purpose of the serialization. ie. You may want to serialize an object differently if it's being sent across the internet or saved to disk. 
 */
-(instancetype)initWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation context:(NSString *)context;

@optional

///
/// Object-to-JSON customization
///

/* Called when the serializer is about to add a property to a dictionary representation of the receiving object. Return whether the property and its value should be added to the dictionary representation of the object.

 @param property The name of the property to be added
 @param context A string representing the reason for the serialization
 */
-(BOOL)serializationShouldIncludeProperty:(NSString *)property context:(NSString *)context;

/* Called when the serializer is about to add a property key to the dictionary representation of the object. Return the string to use as the key for the given property in the dictionary representation of the object.

 @param property The name property of the property to be added
 @param context A string representing the reason for the serialization
 */
-(NSString *)serializationKeyForProperty:(NSString *)property context:(NSString *)context;

/* Called when the serializer has finished creating a dictionary representation of the object. You can alter the dictionary in this method.
 @param dictionaryRepresentation A generated dictionary that represents the object
 @param context A string representing the reason for the serialization
 */
-(void)serializationWillSerializeDictionaryRepresentation:(NSDictionary * __autoreleasing *)dictionaryRepresentation context:(NSString *)context;

///
/// Index serialization
///

/* Properties of GRSerializable objects that are themselves GRSerializable objects will attempt to be serialized with these methods to eliminate recursion. For example, if your MYPost object has a MYUser property, and MYUser implements `-uniqueIndexWithContext:` and returns `@{ @"uniqueIdentifier": @"1234" }`, the serializer will save the user object by its identifier, rather than serializing the whole object. The MYUser class will then receive `-initWithUniqueIndex:context:` where it can use the unique index to return the instance that corresponds to the unique identifier. GRObject implements this behaviour for you by default.
 */

/* Called when the serializer needs the unique index of an object.
 
 @param context A string representing the reason for the serialization
 @return An NSDictionary that contains information that can later be used to retrieve the object
 */
 -(NSDictionary *)uniqueIndexWithContext:(NSString *)context;

/* Objects that implement uniqueIndexWithContext: must also implement this method. Called when the serializer has a unique index and needs to return an object.
 
 @param uniqueIndex The unique index information retrieved from the JSON
 @param context A string representing the reason for the serialization
 @return The instance of the class that corresponds to the uniqueIndex information
*/
-(instancetype)initWithUniqueIndex:(NSDictionary *)uniqueIndex context:(NSString *)context;

///
/// Key inferrence
///

/* Called when the serializer can't figure out the property to which to map a key/value pair when serializing JSON data. For example, you may have a MYPost class with an `author` property. If you receive data like: `{ userIdentifier: 123 }`, this method will be called with the `key` argument as "userIdentifier" and you should return "author".
 
 @param key The unrecognized key
 @param context A string representing the reason for the serialization
 @return The name of the property on the receiving class that corresponds to this key, or nil if this key should be ignored
 */
+(NSString *)propertyForCorrespondingKey:(NSString *)key context:(NSString *)context;

/* Called when a payload contains a key unrecognized by the serializer. Return YES if the given key is used in payloads to identify this class. For example, if you have a MYUser and MYPost class, when you receive a payload containing the data `{ author: {...}, posts:[{...},{...}] }`, the serializer will create 2 MYPost objects and call this method with the key "author". If you create the following implementation, the serializer will also create a MYUser object:
 
    +(BOOL)correspondsToKey:(NSString *)key context:(NSString *)context 
    {
        return ([key isEqualToString:@"author"] || [key isEqualToString:@"customer"]);
    }

 @discussion Use singular forms of the key. If you provide the key "author", GRSerialization will also respond to "authors".
 @param context A string representing the reason for the serialization
 @return An array of keys that correspond to the class
 */
+(BOOL)correspondsToKey:(NSString *)key context:(NSString *)context;

@end

/* 
 # GRSerialization Options
 
 GRSerialization accepts an options dictionary which allows you to further customize serialization. The possible values are explained below.
 */

/* An arbitrary string used to identify the reason/originator of the serialization. Can be used in your GRSerializable implementation to customize data depending on the purpose of the serialization. For example, you may want to serialize your object differently when sending it over the internet than when saving it to disk. */
extern NSString * const GRSerializationOptionContextKey;

 /* By default, properties with nil values will not be included in the serialization. If you want nil property values included, you can pass in an options dictionary with `@(YES)` for the GRSerializationOptionInclueNull key. This will add an NSNull object as the value of any property set to nil:

     MYUser *user     = [[MYUser alloc] initWithName:nil age:30];
     NSData *JSONUser = [GRSerialization JSONWithObject:user options:@{ GRSerializationOptionInclueNull: @(YES) }];
     >> { name: <null>, age: 30 }
*/
extern NSString * const GRSerializationOptionIncludeNullKey;

/* By default, any reference to an object that is a property of another object will not be serialized as the full object, but rather by the data returned from GRSerializable's uniqueIndexWithContext: method, which for GRObject means its `uniqueIdentifier` property. For example, if you have a MYPost object that has a `user` property that is an instance of MYUser, by default the MYPost object will be serialized like so:

     NSData *JSONPost = [GRSerialization JSONWithObject:post options:nil];
     >> { text: "Hi", user: "ABC-123-DEF-345" }

 You may want objects to be recursively serialized, in which case you can pass @(YES) for the GRSerializationOptionRecursiveKey:

     NSData *JSONPost = [GRSerialization JSONWithObject:post options:@{ GRSerializationOptionRecursiveKey: @(YES) }];
     >> { text: "Hi", user: { name: "John", age: 30 } }

 Be careful though: if your object refers to an object which refers back to itself, you will cause an infinite loop.
 */
extern NSString * const GRSerializationOptionRecursiveKey;

/* GRSerialization can convert the case of keys in serialized dictionaries. Your server most likely uses snake_case, so you can pass GRSerializationCaseSnakeCase into the options dictionary.

 Given a MYPost object with postDate and commentIdentifier properties:

 NSData *JSONPost = [GRSerialization JSONWithObject:post options:@{ GRSerializationOptionCaseKey: @(GRSerializationCaseSnakeCase) }];
 >> { post_date: "2000-12-34 12:34:56", comment_id: 123 }

 Note that GRSerialization assumes that snake case uses "id" and llama case uses "identifier", and will convert one to the other as need. Please be a darl and use this convention.

 The possible values are listed below in the GRSerialziation case enum.
 */
extern NSString * const GRSerializationOptionCaseKey;

// Typedef to represent case. Currently supports llamaCase and snake_case
enum GRSerializationCase {
    GRSerializationCaseLlamaCase = 0,
    GRSerializationCaseSnakeCase
};
typedef NSInteger GRSerializationCase;
