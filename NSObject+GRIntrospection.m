//
//  NSObject+GRIntrospection.m
//  Gravy
//
//  Created by Nathan Tesler on 24/02/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "NSObject+GRIntrospection.h"
#import <objc/runtime.h>

#pragma mark - Introspection

@implementation NSObject (GRIntrospection)

+(NSArray *)propertiesOfType:(NSString *)type
{
    // Get an array of all of the class' properties that match the given type
    // The type string is based on NSStringFromClass() for classes and @encode() value for primitives
    NSDictionary *propertyList = [self classProperties];
    NSMutableArray *propertiesOfType = [NSMutableArray array];
    for (NSString *property in propertyList)
    {
        if (!type || [[propertyList valueForKey:property] isEqualToString:type])
            [propertiesOfType addObject:property];
    }

    return [propertiesOfType copy];
}

+(NSDictionary *)classProperties
{
    // Create a dictionary to represent the class' properties like so: { property: type, property: type  }
    NSMutableDictionary *classProperties = [NSMutableDictionary dictionary];

    // We need to iterate through all classes up to, but not including, NSObject
    Class klass = self;
    while (klass != [NSObject class])
    {
        // Get property list
        unsigned int outCount, i;
        objc_property_t *properties = class_copyPropertyList(klass, &outCount);
        for (i = 0; i < outCount; i++)
        {
            // Get property name and type and set on classProperties dictionary
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            if(propertyName)
                [classProperties setObject:@(gravy_getPropertyType(property)) forKey:@(propertyName)];
        }
        free(properties);

        // Go up a class
        klass = [klass superclass];
    }

    // Return immutable dictionary
    return [classProperties copy];
}

+(NSArray *)subclasses
{
    return gravy_getSubclasses([self class]);
}

static const char * gravy_getPropertyType(objc_property_t property)
{
    // Given a property, what is its type?
    const char *attributes = property_getAttributes(property);
    char buffer[1 + strlen(attributes)];
    strcpy(buffer, attributes);
    char *state = buffer, *attribute;
    while ((attribute = strsep(&state, ",")) != NULL)
    {
        if (attribute[0] == 'T' && attribute[1] != '@')
        {
            // C primitive type:
            return (const char *)[[NSData dataWithBytes:(attribute + 1) length:strlen(attribute) - 1] bytes];
        }
        else if (attribute[0] == 'T' && attribute[1] == '@' && strlen(attribute) == 2)
        {
            // ObjC id type:
            return "id";
        }
        else if (attribute[0] == 'T' && attribute[1] == '@' && attribute[2] != '?')
        {
            // Another ObjC object type:
            return (const char *)[[NSData dataWithBytes:(attribute + 3) length:strlen(attribute) - 4] bytes];
        }
    }

    return "";
}

NSArray *gravy_getSubclasses(Class parentClass)
{
    // This method gets all the classes registered with the runtime,
    // filters them and adds the subclasses we need to this array.
    NSMutableArray *result = [NSMutableArray array];

    // Get the number of classes (there are thousands).
    // If you think this is a brute force approach, you are correct.
    int numClasses;
    Class *classes = NULL;
    numClasses = objc_getClassList(NULL, 0);

    if (numClasses > 0)
    {
        classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++)
        {
            // Iterate through the classes.
            // Stop once the superclass becomes our desired class or nil.
            Class superClass = classes[i];
            do
            {
                superClass = class_getSuperclass(superClass);
            }
            while(superClass && superClass != parentClass);

            if (superClass != nil)
            {
                // Discard framework classes, eg. NSKVONotifying.
                // If you are using NS as your own class prefix, you deserve this to break.
                if (![[NSString stringWithUTF8String:class_getName(classes[i])] hasPrefix:@"NS"])
                    [result addObject:classes[i]];
            }

            continue;
        }
        free(classes);
    }
    
    return [result copy];
}

@end
