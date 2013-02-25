//
//  GRSerialization.m
//  Gravy
//
//  Created by Nathan Tesler on 31/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRSerialization.h"

// Cached NSDateFormatter for performance
static NSDateFormatter *dateFormatter;

// An array of dictionaries with information on how to convert non-supported classes
static NSMutableDictionary *learnedConversions;

// Private options keys
static NSString * const GRSerializationOptionPropertyKey         = @"GRSerializationOptionProperty";
static NSString * const GRSerializationOptionDestinationClassKey = @"GRSerializationOptionDestinationClass";

@implementation GRSerialization

#pragma mark - Serialization API

+(NSData *)JSONWithObject:(id)object options:(NSDictionary *)options
{
    // Check that a destination clas was not provided (only valid for JSON->Object)
    NSAssert(!options[GRSerializationOptionDestinationClassKey], @"You must not provide a destination class for Object->JSON serialization. It is only used for JSON->Object.");

    // Convert object into JSONObject
    id JSONObject = [self objectWithObject:object options:options];

    // Convert JSONObject into JSON (we don't check the error, it's useless)
    NSData *JSON = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:nil];

    return JSON;
}

+(id)objectWithJSON:(NSData *)JSON class:(__unsafe_unretained Class)class options:(NSDictionary *)options
{
    // Convert JSON into JSONObject
    id JSONObject = [NSJSONSerialization JSONObjectWithData:JSON options:0 error:nil];

    // Add class to options
    if (class)
    {
        NSMutableDictionary *newOptions = [NSMutableDictionary dictionaryWithDictionary:options];
        newOptions[GRSerializationOptionDestinationClassKey] = class;
        options = [newOptions copy];
    }

    // Convert JSONObject into object
    id object = [self objectWithObject:JSONObject options:options];

    return object;
}

+(void)learnConversionForClass:(Class)class converter:(GRSerializationConverter)converter
{
    // Create learnedConversions array if neccesary
    if (!learnedConversions)
        learnedConversions = [NSMutableArray array];

    // Add this conversion
    [learnedConversions setObject:converter forKey:NSStringFromClass(class)];
}

#pragma mark - Conversion to/from JSONObject

/* Converting to JSONObject is pretty easy. We just need to recursively ensure that every value is either an NSDictionary, NSArray, NSString or NSNumber. Converting from JSONObject is harder, mainly because JSON carries no data about class. We solve this problem in three possible ways:
 
 1. Providing a class for GRSerializationOptionDestinationClass. This forces all objects to be serialized to the given class.
 2. Using the keys in the payload to help us determine class. For example, given a key of "user" and a value of a dictionary, we can inspect the runtime for registered classes that contain "user" in their names, then serialize the dictionary to a class, if found.
 2. Knowing the destination class, we can again use the ObjC runtime to find its properties and their types. For example, the user object might have a joinDate property, for which we know the type is an NSDate. We then convert the value for the key "joinDate" from an NSString to NSDate.
 */

+(id)objectWithObject:(id)object options:(NSDictionary *)options
{
    if ([object conformsToProtocol:@protocol(GRSerializable)])
    {
        // Object > JSONObject: A serializable object. Return a dictionary representation, or an index representing the object.
        return [self dictionaryWithObject:object options:options];
    }
    else if ([object isKindOfClass:[NSArray class]])
    {
        // Object > JSONObject: This is an array. Serialize all the objects within it
        // JSONObject > Object: Ditto.
        return [self arrayWithArray:object options:options];
    }
    else if ([object isKindOfClass:[NSDictionary class]])
    {
        // Object > JSONObject: This is a dictionary. Convert the case of each key, if necessary.
        // JSONObject > Object: This is either:
        //      - A dictionary. Convert the case of each key, if necessary.
        //      - An object representation. Map the dictionary to an object.
        //      - A payload: Infer the class of each key, then map each value to object(s).
        return [self dictionaryWithDictionary:object options:options];
    }
    else if ([object isKindOfClass:[NSData class]])
    {
        // Object > JSONObject: Convert the data into a string
        return [self stringWithData:object options:options];
    }
    else if ([object isKindOfClass:[NSDate class]])
    {
        // Object > JSONObject: Convert the date into a string
        return [self stringWithDate:object options:options];
    }
    else if ([object respondsToSelector:@selector(isSubclassOfClass:)])
    {
        // This is a class object, return a string representation
        return [self stringWithClass:object options:options];
    }
    else if ([object isKindOfClass:[NSNumber class]])
    {
        // Object > JSONObject: Box primitive types.
        // JSONObject > Object: Basically, do nothing.
        return [self numberWithNumber:object options:options];
    }
    else if ([object isKindOfClass:[NSString class]])
    {
        return object;
    }
    else if ([object isKindOfClass:[NSNull class]])
    {
        return object;
    }
    else
    {
        // See if there is a learned conversion for this class, execute if it there is
        GRSerializationConverter converter = [learnedConversions valueForKey:NSStringFromClass([object class])];
        if (converter)
            return converter(object, nil);
    }
    
    return object;
}

#pragma mark - Recursive container serialization

+(NSArray *)arrayWithArray:(NSArray *)array options:(NSDictionary *)options
{
    // Recursively serialize the objects
    NSMutableArray *newArray = [NSMutableArray array];
    for (id subobject in array)
        [newArray addObject:[self objectWithObject:subobject options:options]];
    return [newArray copy];
}

+(NSDictionary *)dictionaryWithDictionary:(NSDictionary *)dictionary options:(NSDictionary *)options
{
    /* There are three scenarios here: 
     1. JSONDictionary -> Dictionary (no destination class provided) 
        - Just change the case of the keys
     2. JSONDictionary -> Object (a concrete destination class provided)
        - Create an object from the dictionary
     3. JSONDictionary -> Payload (GRObject provided as destination class)
        - Create objects from the values in the payload, using the keys as indications of class
     */

    // Get the destination class from the dictionary options
    Class destinationClass = options[GRSerializationOptionDestinationClassKey];

    // If GRObject was supplied as the destination class, we need to infer the actual subclass
    BOOL inferClass = [NSStringFromClass(destinationClass) isEqualToString:@"GRObject"];

    // Serialize the keys and objects
    NSMutableDictionary *toDictionary = [NSMutableDictionary dictionary];
    for (NSString *key in dictionary)
    {
        // Check that the key is an NSString (this constraint is placed on us by JSON)
        NSAssert2([key isKindOfClass:[NSString class]], @"Keys in dictionaries being serialized must be NSString objects. Invalid key: \"%@\" in dictionary: %@", key, dictionary);

        // Change the case of the key
        NSString *toKey = [self convertString:key options:options];

        // Get the value
        id value = [dictionary valueForKey:key];

        // Convert the value to object/payload if neccesary
        if (inferClass)
            value = [self valueWithPayloadValue:value forKey:toKey options:options];

        // Set the new value and key on the dictionary
        [toDictionary setValue:value forKey:toKey];
    }

    // Return the object
    if (destinationClass && !inferClass)
    {
        // If a class was given but this is not a payload, return an object with this class instead of a dictionary
        return [self objectWithDictionary:toDictionary options:options];
    }
    else
    {
        // Return the dictionary or payload
        return [toDictionary copy];
    }
}

+(id)valueWithPayloadValue:(id)value forKey:(NSString *)key options:(NSDictionary *)options
{
    // Change the destination class to an inferred concrete subclass if
    NSMutableDictionary *newOptions = [NSMutableDictionary dictionaryWithDictionary:options];
    newOptions[GRSerializationOptionDestinationClassKey] = [self objectSubclassWithKey:key options:options];

    // Check that the payload is correctly formatted
    NSAssert([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]], @"Payload must contain class names as keys, with dictionaries or arrays as values. Payload: %@", value);

    // Either convert this dictionary into an object or this array into an array of objects
    return [self objectWithObject:value options:newOptions];
}

#pragma mark - Object to JSON

+(NSDictionary *)dictionaryWithObject:(id)object options:(NSDictionary *)options
{
    // Return a unique index rather than a representation if: this is a property, is not recursive and has an index
    if (options[GRSerializationOptionPropertyKey] &&
        ![options[GRSerializationOptionRecursiveKey] boolValue] &&
        [object respondsToSelector:@selector(uniqueIndexWithContext:)])
    {
        return [object uniqueIndexWithContext:options[GRSerializationOptionContextKey]];
    }

    // Create a dictionaryRepresentation of the object and add each property
    NSMutableDictionary *dictionaryRepresentation = [NSMutableDictionary dictionary];
    for (NSString __strong *property in [[object class] propertiesOfType:nil])
    {
        // If this property is ignored, continue
        if ([object respondsToSelector:@selector(serializationShouldIncludeProperty:context:)])
            if (![object serializationShouldIncludeProperty:property context:options[GRSerializationOptionContextKey]])
                continue;

        // Get the value of the property
        id value = [object valueForKey:property];

        // We only include a nil value if the GRSerializationOptionIncludeNull option is given
        // For primitive types we must include it because we can't differentiate between a 0 and a nil
        if (![value respondsToSelector:@selector(objCType)] && [options[GRSerializationOptionIncludeNullKey] boolValue] && !value)
            value = [NSNull null];

        // If not recursive, serialize property as index, rather than dictionary
        if (![options[GRSerializationOptionRecursiveKey] boolValue])
        {
            NSMutableDictionary *propertyOptions = [NSMutableDictionary dictionaryWithDictionary:options];
            propertyOptions[GRSerializationOptionPropertyKey] = @(YES);
            value = [self objectWithObject:value options:propertyOptions];
        }

        // Set the serialization key for the property
        if ([object respondsToSelector:@selector(serializationKeyForProperty:context:)])
            property = [object serializationKeyForProperty:property context:options[GRSerializationOptionContextKey]];

        // Set the key value pair on the dictionary representation
        [dictionaryRepresentation setValue:value forKey:property];
    }

    // Notify object of impending serialization
    if ([object respondsToSelector:@selector(serializationWillSerializeDictionaryRepresentation:context:)])
        [object serializationWillSerializeDictionaryRepresentation:&dictionaryRepresentation context:options[GRSerializationOptionContextKey]];

    // JSONify the dictionary (this converts key cases, converts unsupported values)
    NSDictionary *JSONDictionary = [self objectWithObject:dictionaryRepresentation options:options];

    return JSONDictionary;
}

+(NSString *)stringWithData:(NSData *)data options:(NSDictionary *)options
{
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+(NSString *)stringWithDate:(NSDate *)date options:(NSDictionary *)options
{
    return [[self uniformDateFormatter] stringFromDate:date];
}

+(NSString *)stringWithClass:(Class)class options:(NSDictionary *)options
{
    return NSStringFromClass(class);
}

+(NSNumber *)numberWithNumber:(NSNumber *)number options:(NSDictionary *)options
{
    // Return an NSNumber for NSNumber objects and C primitives
    NSString *type = [NSString stringWithCString:[number objCType] encoding:NSUTF8StringEncoding];

    if ([type isEqualToString:@"i"])
        return @([number integerValue]);
    else if ([type isEqualToString:@"I"])
        return @([number unsignedIntegerValue]);
    else if ([type isEqualToString:@"l"])
        return @([number longValue]);
    else if ([type isEqualToString:@"L"])
        return @([number unsignedLongValue]);
    else if ([type isEqualToString:@"q"])
        return @([number longLongValue]);
    else if ([type isEqualToString:@"Q"])
        return @([number unsignedLongLongValue]);
    else if ([type isEqualToString:@"s"])
        return @([number shortValue]);
    else if ([type isEqualToString:@"S"])
        return @([number unsignedShortValue]);
    else if ([type isEqualToString:@"c"])
        return @([number boolValue]);
    else if ([type isEqualToString:@"d"])
        return @([number doubleValue]);
    else if ([type isEqualToString:@"f"])
        return @([number floatValue]);
    else
    {
        [NSException raise:@"Incompatible type in GRSerialization"
                    format:@"Invalid type: %s. GRSerialization can only serialize the following primitive types (even boxed as NSNumbers): signed and unsigned (integers, longs, longlongs, shorts), floats, doubles and BOOLs. This includes typedefs like NSInteger, NSUInteger and CGFloat. Chars are not supported.", [number objCType]];
        return nil;
    }
}

#pragma mark - JSON to Object

+(id)objectWithDictionary:(NSDictionary *)dictionary options:(NSDictionary *)options
{
    // Get the destination class
    Class destinationClass = options[GRSerializationOptionDestinationClassKey];

    // If this is an index, return the object that it belongs to
    if (options[GRSerializationOptionPropertyKey] &&
        ![options[GRSerializationOptionRecursiveKey] boolValue] &&
        [destinationClass instancesRespondToSelector:@selector(initWithUniqueIndex:context:)])
    {
        return [[destinationClass alloc] initWithUniqueIndex:dictionary context:options[GRSerializationOptionContextKey]];
    }

    // Use the class information of the properties to create a full representation of the object.
    NSDictionary *classProperties = [destinationClass classProperties];

    // Create a dictionary with the keys converted and cross-check it against the destination class' properties.
    NSMutableDictionary *dictionaryRepresentation = [NSMutableDictionary dictionary];
    for (NSString __strong *key in dictionary)
    {
        // Check if the class responds to the key
        if (![destinationClass instancesRespondToSelector:NSSelectorFromString(key)])
        {
            // If it doesn't, get the corresponding property or ignore it
            if ([destinationClass instancesRespondToSelector:@selector(propertyForCorrespondingKey:context:)])
                key = [destinationClass propertyForCorrespondingKey:key context:options[GRSerializationOptionContextKey]];
            else
                continue;
        }

        // Get the type of the property corresponding to this key
        NSString *type = [classProperties valueForKey:key];

        // Get the value of the property
        id value = [self propertyWithValue:[dictionary valueForKey:key] type:type options:options];

        // Set the value on the new dictionary representation
        [dictionaryRepresentation setValue:value forKey:key];
    }

    // Return an object with the dictionary representation
    return [[destinationClass alloc] initWithDictionaryRepresentation:dictionaryRepresentation context:options[GRSerializationOptionContextKey]];
}

+(id)propertyWithValue:(id)value type:(NSString *)type options:(NSDictionary *)options
{
    // Convert the given properties from JSON-safe to normal objects
    if ([NSClassFromString(type) conformsToProtocol:@protocol(GRSerializable)])
    {
        // Serialize the object with its class as the destination class
        NSMutableDictionary *newOptions = [NSMutableDictionary dictionaryWithDictionary:options];
        newOptions[GRSerializationOptionDestinationClassKey] = NSClassFromString(type);
        newOptions[GRSerializationOptionPropertyKey] = @(YES);

        return [self objectWithObject:value options:[newOptions copy]];
    }
    else if ([NSClassFromString(type) isSubclassOfClass:[NSArray class]] ||
             [NSClassFromString(type) isSubclassOfClass:[NSDictionary class]])
    {
        // Recursively serialize property without class information
        NSMutableDictionary *newOptions = [NSMutableDictionary dictionaryWithDictionary:options];
        [newOptions removeObjectForKey:GRSerializationOptionDestinationClassKey];
        id newValue = [self objectWithObject:value options:newOptions];

        // Make mutable if neccesary
        if ([NSClassFromString(type) isSubclassOfClass:[NSMutableArray class]] ||
            [NSClassFromString(type) isSubclassOfClass:[NSMutableDictionary class]])
        {
            newValue = [newValue mutableCopy];
        }

        return newValue;
    }
    else if ([NSClassFromString(type) isSubclassOfClass:[NSData class]])
    {
        // Create an NSData from the string
        id newValue = [value dataUsingEncoding:NSUTF8StringEncoding];

        // Make mutable if neccesary
        if ([NSClassFromString(type) isSubclassOfClass:[NSMutableData class]])
            newValue = [newValue mutableCopy];

        return newValue;
    }
    else if ([NSClassFromString(type) isSubclassOfClass:[NSDate class]])
    {
        // Create an NSDate from the string
        return [[self uniformDateFormatter] dateFromString:value];
    }
    else if ([NSClassFromString(type) isSubclassOfClass:[NSMutableString class]])
    {
        // Turn NSString into NSMutableString
        return [value mutableCopy];
    }
    else
    {
        GRSerializationConverter converter = [learnedConversions valueForKey:type];
        if (converter)
            return converter(nil, value);

        return value;
    }
}

#pragma mark - Helpers

+(Class)objectSubclassWithKey:(NSString *)key options:(NSDictionary *)options
{
    // Iterate through all subclasses of GRObject
    for (Class subclass in [NSClassFromString(@"GRObject") subclasses])
    {
        // If this class has corresponding keys, check if they (or any pluralization) is equal to the given key
        if ([subclass respondsToSelector:@selector(correspondsToKey:context:)])
            for (NSString *candidate in [self pluralizedCandidatesForKey:key])
                if ([subclass correspondsToKey:candidate context:options[GRSerializationOptionContextKey]])
                    return subclass;

        // Check if any singularization of the key corresponds to the given class
        for (NSString *candidate in [self singularizedCandidatesForKey:key])
        {
            NSPredicate *keyPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@", candidate];
            if ([keyPredicate evaluateWithObject:NSStringFromClass(subclass)])
                return subclass;
        }
    }

    [NSException raise:@"GRSerialization payload could not be inferred." format:@"A class could not be inferred from key \"%@\" in the payload. Either change the key or override +correspondingKeys in your object subclass. See GRSerialization docs for more information on automatic payload serialization.", key];

    return Nil;
}

#pragma mark - Singularization/Pluralization

+(NSArray *)singularizedCandidatesForKey:(NSString *)key
{
    // It's not worth using a pluralization library. Just chop off the end and add the singularization.
    // There's only one singularization I've intentionally left out (Ox > Oxen). Sorry if you're builing a farming app.
    NSArray *singularizationRules = @[  @{@""       : @(0)},   // Fish      >Fish
                                        @{@""       : @(1)},   // Cat       >Cats
                                        @{@""       : @(2)},   // Box       >Boxes
                                        @{@"y"      : @(3)},   // Category  >Categories
                                        @{@"fe"     : @(3)},   // Wife      >Wives
                                        @{@"f"      : @(3)},   // Dwarf     >Dwarves
                                        @{@"an"     : @(2)},   // Man       >Men
                                        @{@"Person" : @(6)},   // Person    >People
                                        @{@"Child"  : @(8)},   // Child     >Children
                                        @{@"is"     : @(2)},   // Diagnosis >Diagnoses
                                        @{@"ix"     : @(4)},   // Matrix    >Matrices
                                        @{@"ex"     : @(5)},   // Index     >Indices
                                        @{@""       : @(3)}    // Quiz      >Quizzes
                                    ];

    // Array to house all possible singularizations
    return [self candidatesForKey:key withPluralizationRuleset:singularizationRules];
}

+(NSArray *)pluralizedCandidatesForKey:(NSString *)key
{
    NSArray *pluralizationRules = @[  @{@""         : @(0)},   // Fish      >Fish
                                      @{@"s"        : @(0)},   // Cat       >Cats
                                      @{@"es"       : @(0)},   // Box       >Boxes
                                      @{@"ies"      : @(1)},   // Category  >Categories
                                      @{@"ves"      : @(2)},   // Wife      >Wives
                                      @{@"ves"      : @(1)},   // Dwarf     >Dwarves
                                      @{@"en"       : @(2)},   // Man       >Men
                                      @{@"People"   : @(6)},   // Person    >People
                                      @{@"Children" : @(5)},   // Child     >Children
                                      @{@"es"       : @(2)},   // Diagnosis >Diagnoses
                                      @{@"ices"     : @(2)},   // Matrix    >Matrices
                                      @{@"zes"      : @(0)}    // Quiz      >Quizzes
                                    ];

    // Array to house all possible singularizations
    return [self candidatesForKey:key withPluralizationRuleset:pluralizationRules];
}

+(NSArray *)candidatesForKey:(NSString *)key withPluralizationRuleset:(NSArray *)ruleset
{
    // Array to house all possible singularizations
    NSMutableArray *candidates = [NSMutableArray array];

    // Try each singularization rule and add it to the array
    for (NSDictionary *rule in ruleset)
    {
        // Get the backspace amount from the singularizations dictionary
        NSInteger backspace = [[[rule allValues] lastObject] integerValue];

        // Check that the key has more chars than the backspace amount (to avoid invalid range exception)
        if ([key length] < backspace)
            continue;

        // Chop off the backspace amount
        NSString *candidateKey = [key substringToIndex:[key length] - backspace];

        // Append the singularization
        candidateKey = [candidateKey stringByAppendingString:[[rule allKeys] lastObject]];

        // Add the possible singularization to the array
        [candidates addObject:candidateKey];
    }
    
    return [candidates copy];
}

#pragma mark - Case conversion

+(NSString *)convertString:(NSString *)string options:(NSDictionary *)options
{
    if (options[GRSerializationOptionCaseKey])
        return [self convertString:string toCase:[options[GRSerializationOptionCaseKey] integerValue]];

    return string;
}

+(NSString *)convertString:(NSString *)string toCase:(GRSerializationCase)serializationCase
{
    if (serializationCase == GRSerializationCaseLlamaCase)
    {
        // "id" is a reserved word in ObjC, so we just replace it with the "identifier".
        // If your class has an attribute like userId, please use userIdentifier instead.
        if ([string isEqualToString:@"id"])
            string = @"identifier";
        else if ([string hasSuffix:@"_id"])
            string = [[string substringFromIndex:[string length] - 2] stringByAppendingString:@"Identifier"];

        // Find underscores, replace with space and capitalize following letter (eg. "user_name" to "userName"
        if ([string rangeOfString:@"_"].location != NSNotFound)
        {
            NSRange rangeOfUnderscore = [string rangeOfString:@"_"];

            while (rangeOfUnderscore.location != NSNotFound)
            {
                string = [string stringByReplacingCharactersInRange:rangeOfUnderscore withString:@""];
                string = [string stringByReplacingCharactersInRange:rangeOfUnderscore withString:[[string substringWithRange:rangeOfUnderscore] uppercaseString]];

                rangeOfUnderscore = [string rangeOfString:@"_"];
            }
        }

        return string;
    }
    else if (serializationCase == GRSerializationCaseSnakeCase)
    {
        for (int i = 0; i < string.length - 1; i++)
        {
            // Find even capital letter, insert underscore and lowercase the letter
            if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:[string characterAtIndex:i]])
            {
                // Make replacement string
                NSString *lowercaseCharacter = [NSString stringWithFormat:@"_%c", [[string lowercaseString] characterAtIndex:i]];

                // Replace uppercase character with underscore and lowercase
                string = [string stringByReplacingCharactersInRange:NSMakeRange(i, 1) withString:lowercaseCharacter];
            }
        }

        // Convert instances of "identifier" to "id"
        string = [string stringByReplacingOccurrencesOfString:@"identifier" withString:@"id"];
        
        return string;
    }

    return nil;
}

#pragma mark - Date conversion

+(NSDateFormatter *)uniformDateFormatter
{
    // Return cached dateFormatter if exists
    if (dateFormatter)
        return dateFormatter;

    // Cache for performance
    dateFormatter = [[NSDateFormatter alloc] init];

    // Set format (compatible with rails), locale (to avoid discrepancies with client's calendar) and UTC timezone
    [NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];

    // I love using dates in Objective-C!!! It just works!
    return dateFormatter;
}

@end

NSString * const GRSerializationOptionContextKey          = @"GRSerializationOptionContext";
NSString * const GRSerializationOptionRecursiveKey        = @"GRSerializationOptionRecursive";
NSString * const GRSerializationOptionIncludeNullKey      = @"GRSerializationOptionIncludeNull";
NSString * const GRSerializationOptionCaseKey             = @"GRSerializationOptionCase";
