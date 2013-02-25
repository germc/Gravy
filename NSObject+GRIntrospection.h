//
//  NSObject+GRIntrospection.h
//  Gravy
//
//  Created by Nathan Tesler on 24/02/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import <Foundation/Foundation.h>

/* This category on NSObject implements three powerful methods using introspective language features of Objective C and the Objective C runtime to enable most of GRSerialization's wizardry. */

@interface NSObject (GRIntrospection)

/* Returns a dictionary containing all public properties of the class as keys, and the class/type of the property as values. ie. `{ age: "i", height: "f", name: "NSString" }`. Primitive types use the values explained in the Objective C Runtime Programming Guide. https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
 */
+(NSDictionary *)classProperties;

/* Returns an NSArray of all public property names of the receiving class that match the given type. If nil, it returns the name of every public property. Primitive types use the values explained in the Objective C Runtime Programming Guide. https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html
 */
+(NSArray *)propertiesOfType:(NSString *)type;

/* Returns an NSArray of every subclass of the receiving class registered with the runtime. */
+(NSArray *)subclasses;

@end
