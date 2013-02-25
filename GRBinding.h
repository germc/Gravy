//
//  GRBinding.h
//  Gravy
//
//  Created by Nathan Tesler on 26/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GRSource.h"

// Block typedefs
typedef id(^GRBindingValueTransformer)(id objectValue, id controlValue);
typedef void(^GRBindingChangeHandler)();

/* GRBindings are model/controller objects that bind objects and controls together, and eliminate generic "glue" code. These are created automatically by GRViewController and you generally should never interact with GRObjectBindings directly.
 
 GRObjectBindings are incredibly powerful. Say you have a user profile screen with a "usernameTextField" and your user object has a "name" property. GRBinding enables either of the following automatic behaviours:
    
 1. Direct binding: The user's "name" property is directly bound to the "usernameTextField". If the user's name property is set to "John", the text field will contain "John" when the binding is created. If the user types "Bob" into the usernameTextField, the user object's "name" property is automatically set to "Bob".
 2. Change handling: When the "name" property of the user object changes or when the value of the "usernameTextField" changes, a specified block is called, say to update a character counter or to initiate a HTTP request.
 
 GRObjectBindings can accept valueTransformer blocks which operate on direct bindings. These transform the value of the change before setting it. For example, if a tranformer block is provided in the above example, it could take the value "Bob" from the usernameTextField, convert it to lowercase and prepend an "@" before setting it on the user object, and reverse the change before setting on the control object.
 
 See GRViewController for the practical side of GRObjectBinding.
 */

@interface GRBinding : NSObject <GRSourceObserver>

/* The bound object. */
@property (strong, nonatomic) id object;

/* The name of the property of the object that is bound to the control. */
@property (strong, nonatomic) NSString *property;

/* The control to which the object is bound. */
@property (strong, nonatomic) id control;

/* The keypath of the object bound to the control. This is used by clients of GRBinding to identify bindings, and is not used by GRBinding itself. */
@property (strong, nonatomic) NSString *keyPath;

/* The block to execute when the value of either the control or object's keypath changes. */
@property (strong, nonatomic) GRBindingChangeHandler changeHandler;

/* The block to execute when the value of one side of the binding changes to determine the value to set on the other. The objectValue is nil when the control changes and the controlValue is nil when the object changes. */
@property (strong, nonatomic) GRBindingValueTransformer valueTransformer;

/* Sets up the binding to receive and respond to change events. */
-(void)bind;

/* Creates, binds and returns a GRBinding that calls the specified block when the specified control changes. You must hold a strong reference to the binding and you can just set to nil when you're done with it. */
+(GRBinding *)bindingWithControl:(id)control changeHandler:(GRBindingChangeHandler)changeHandler;

/* Creates, binds and returns a GRBinding that calls the specified block when the object's property changes. You must hold a strong reference to the binding and you can just set to nil when you're done with it. */
+(GRBinding *)bindingWithObject:(id)object property:(NSString *)property changeHandler:(GRBindingChangeHandler)changeHandler;

@end

/* If you wish to use a custom control with GRObjectBinding, your control must have a key-value observing compliant property that both represents the value of the control and usually, can be set to change the value of the control. This can be a property named `value`, in which case the binding behaviour will work automatically, or your control class can conform to the GRControl protocol, in which case the property name returned from the `valueProperty` method will be used.
 */
@protocol GRControl

/* The name of the value property of the control. For example, if you are creating a custom progress view, you could return `@"progress"` from this method. You can test this will the following code:
 
    Getting (required): [myControl valueForKey:[myControl valueProperty]]
    Setting (optional): [myControl setValue:x forKey:[myControl valueProperty]]
 */

-(NSString *)valueProperty;

@end