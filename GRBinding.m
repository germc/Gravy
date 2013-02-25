//
//  GRBinding.m
//  Gravy
//
//  Created by Nathan Tesler on 26/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRBinding.h"

@interface GRBinding ()
@property (nonatomic) BOOL disabled;
@end

@implementation GRBinding

#pragma mark - Simple API

+(GRBinding *)bindingWithControl:(id)control changeHandler:(GRBindingChangeHandler)changeHandler
{
    GRBinding *binding = [[GRBinding alloc] init];
    binding.control = control;
    binding.changeHandler = changeHandler;
    [binding bind];

    return binding;
}

+(GRBinding *)bindingWithObject:(id)object property:(NSString *)property changeHandler:(GRBindingChangeHandler)changeHandler
{
    GRBinding *binding = [[GRBinding alloc] init];
    binding.object = object;
    binding.property = property;
    binding.changeHandler = changeHandler;
    [binding bind];

    return binding;
}

#pragma mark - Complex API

-(void)bind
{
    // The binding gets its object change notifications by registering with the GRSource. We also register bindings without objects (for example, those created with -[GRViewController observeControl] for consistancy. The GRSource holds a weak reference to the binding.
    [[GRSource source:[self.object class]] registerObserver:self];

    if (self.control)
    {
        // Call controlDidChange when a control changes
        [self addControlEventTargets];

        // Set initial state of the control
        [self updateControl];
    }
}

-(void)addControlEventTargets
{
    // Here we register to receive messages when the control changes. UIControl is not KVO compliant, so we need to use control events. To make matters even stupider, UITextView is a UIView subclass, not a UIControl subclass. To observe its changes and not intefere with UITextViewDelegate methods, we use notifications. To observe custom controls we either check if they conform to GRControl, in which case we use KVO to observe the given valueKeyPath, or we check if they have a 'value' attribute and observe that.
    // http://www.youtube.com/watch?v=ajsNJtnUb7c

    if ([self.control isKindOfClass:[UITextField class]])
        [self.control addTarget:self action:@selector(controlDidChange) forControlEvents:UIControlEventEditingChanged];
    else if ([self.control isKindOfClass:[UIButton class]])
        [self.control addTarget:self action:@selector(controlDidChange) forControlEvents:UIControlEventTouchDown];
    else if ([self.control isKindOfClass:[UIControl class]])
        [self.control addTarget:self action:@selector(controlDidChange) forControlEvents:UIControlEventValueChanged];
    else if ([self.control isKindOfClass:[UITextView class]])
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controlDidChange) name:UITextViewTextDidChangeNotification object:self.control];
    else if ([self.control conformsToProtocol:@protocol(GRControl)])
        [self.control addObserver:self forKeyPath:[self.control valueProperty] options:0 context:nil];
    else if ([self.control respondsToSelector:@selector(value)])
        [self.control addObserver:self forKeyPath:@"value" options:0 context:nil];
}

-(void)setObject:(id)object
{
    // Mark if the object is changed (and not new)
    BOOL change = _object != nil;

    // Set the new object
    _object = object;

    // Update the control for the new object
    if (change)
        [self updateControl];
}

-(void)dealloc
{
    // Deregister the binding with the source
    [[GRSource source:[self.object class]] deregisterObserver:self];
}

#pragma mark - Change methods

-(void)updateObject
{
    // Hijack the update if there is a change handler
    if (self.changeHandler)
    {
        self.changeHandler();
        return;
    }

    // Get the updated value of the control
    id newValue = [self.control valueForKey:[self controlKeyPath]];

    // Transform value if necessary
    if (self.valueTransformer)
        newValue = self.valueTransformer(nil, newValue);

    // Set the updated value on the object
    [self.object setValue:newValue forKey:self.property];
}

-(void)updateControl
{
    // Return if the binding is disabled
    if (self.disabled)
        return;

    // Hijack the update if there is a change handler
    if (self.changeHandler)
    {
        self.changeHandler();
        return;
    }

    // Get the updated value of the control
    id newValue = [self.object valueForKey:self.property];

    // Transform value if necessary
    if (self.valueTransformer)
        newValue = self.valueTransformer(newValue, nil);

    // Set the updated value on the object
    [self.control setValue:newValue forKey:[self controlKeyPath]];
}

-(void)clearControl
{
    [self.control setValue:NULL forKey:[self controlKeyPath]];
    
//    // To clear the control we either set its value to nil or 0. The app will throw an exception if we try to set nil for a primitive value, so we
//    @try
//    {
//        [self.control setValue:nil forKey:[self controlKeyPath]];
//    }
//    @catch (NSException *exception)
//    {
//        [self.control setValue:0 forKey:[self controlKeyPath]];
//    }
}

-(void)controlDidChange
{
    // Called by the control events we added in addControlEventTargets
    // If the control changed, we disable the binding, update the object and reenable the binding
    // This is so we don't get a loop (ie. control changes, which changes the object, which changes the control...)

    self.disabled = YES;

    [self updateObject];

    self.disabled = NO;
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // If this method is called when an observed custom control changes its value, we just need to call controlDidChange
    if (object == self.control)
        [self controlDidChange];

    // If this method is a keypath change, we need to swap out the object
    
}

-(void)source:(GRSource *)source didUpdateObject:(GRObject *)object changeType:(GRObjectChangeType)changeType keyPath:(NSString *)keyPath
{
    switch (changeType)
    {
        case GRObjectChangeTypeUpdate:
            if (self.object == object && [keyPath isEqualToString:self.property])
                [self updateControl];
            break;

        case GRObjectChangeTypeDelete:
            if (self.object == object)
            {
                // Clear the control
                [self clearControl];

                // Deregister the binding
                [[[self.object class] source] deregisterObserver:self];
            }
        default:
            break;
    }
}

#pragma mark - Helpers

-(NSString *)controlKeyPath
{
    // This disgusting method is used to determine what key path of the control to update when the model object changes.

    if ([self.control isKindOfClass:[UITextField class]] ||
        [self.control isKindOfClass:[UITextView class]] ||
        [self.control isKindOfClass:[UILabel class]])
    {
        return @"text";
    }
    else if ([self.control isKindOfClass:[UISwitch class]])
    {
        return @"on";
    }
    else if ([self.control isKindOfClass:[UIButton class]])
    {
        return @"selected";
    }
    else if ([self.control isKindOfClass:[UISegmentedControl class]])
    {
        return @"selectedSegmentIndex";
    }
    else if ([self.control isKindOfClass:[UISlider class]] ||
             [self.control isKindOfClass:[UIStepper class]])
    {
        return @"value";
    }
    else if ([self.control isKindOfClass:[UIImageView class]])
    {
        return @"image";
    }
    else if ([self.control isKindOfClass:[UIDatePicker class]])
    {
        return @"date";
    }
    else if ([self.control isKindOfClass:[UIProgressView class]])
    {
        return @"progress";
    }
    else if ([self.control conformsToProtocol:@protocol(GRControl)])
    {
        return [(id<GRControl>)self.control valueProperty];
    }
    else if ([self.control respondsToSelector:@selector(value)])
    {
        return @"value";
    }
    else
    {
        [NSException raise:NSLocalizedString(@"Attempting to register a control without a value keyPath", nil) format:NSLocalizedString(@"To use a custom control with GRBinding, you must make it conform to GRControl and return the name of the value attribute from the -valueKeyPath method. For example, if you are creating a custom progress view, return @\"progress\" from the -valueKeyPath method.", nil)];

        return nil;
    }
}

@end
