//
//  GRViewController.h
//  Gravy
//
//  Created by Nathan Tesler on 26/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GRObject.h"
#import "GRCollection.h"
#import "GRBinding.h"

/* GRViewController is a UIViewController subclass that provides an interface for binding objects to controls. Instead of managing delegates and dataSources, GRViewController intelligently connects your data with your user interface, eliminating 99% of boilerplate code. */

@interface GRViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UICollectionViewDelegate, UICollectionViewDataSource, GRCollectionDelegate>

///
/// Registering object/control
///

/* Connects an object's keypath to a control. eg:

    [self registerControl:self.emailField forKeyPath:keypath(self.user.email)];

 This code will automatically update the emailField when the user's email changes, and automatically update the user's email when the emailField changes.
 */

-(void)registerControl:(id)control forKeyPath:(NSString *)keyPath;

/* Works like registerControl:forObject:keypath:, but you can also supply a transformer block to change the data before it's set:

    [self registerControl:self.twitterField forKeyPath:keypath(self.user.twitter) valueTransformer:^(id objectValue, id controlValue){

        if (objectValue)
            return objectValue;
        else if (controlValue)
            return [controlValue lowercaseString];
    }]
 
 @param valueTransformer A block with two parameters: the first is the updated object value, the second is the updated control value. If the object changes, the control value is nil. If the control changes, the object value is nil. Return from this block the value to set on the opposite object/control.
 */

-(void)registerControl:(id)control forKeyPath:(NSString *)keyPath valueTranformer:(GRBindingValueTransformer)valueTransformer;

///
/// Observing object/control
///

/* Observes changes to the given object's given keypath and executes the given block. Given. eg:
 
    [self observeObject:self.user withKeyPath:@"email" changeHandler:^{ NSLog(@"Email changed."); }];
 
 @discussion This is very similar to +[GRBinding bindingWithObject:property:changeHandler:] except you can use a keypath rather than specifying a specific object, and the ownership of the binding is handled for you automatically. 
 */
-(void)observeKeyPath:(NSString *)keyPath changeHandler:(GRBindingChangeHandler)changeHandler;

/* Observes a given control and executes the given block when the control changes value. eg:
 
    [self observeControl:self.emailField changeHandler:^{ NSLog(@"User entered email."); }];
 */
-(void)observeControl:(id)control changeHandler:(GRBindingChangeHandler)changeHandler;

///
/// Registering collection/contentView
///

/* Connects a GRCollection to a UITableView or UICollectionView. eg.

    self.users = [GRCollection collectionWithClass:[MYUser class]];
    [self registerContentView:self.tableView forCollection:self.users customizeHandler:^(UITableViewCell *cell, MYUser *user){
        cell.textLabel.text = user.name;
    } selectionHandler:^(id selectedObject){
        NSLog(@"Selected user: %@", user);
    }];

 This will populate the tableView with all the objects in the collection, customize the cell with the given customizeHandler and execute the selectionHandler when the user selects a cell.

 @param customizeHandler A block that is called when the cell needs to be customized. Optional
 @param selectionHandler A block that is called when the user selects the cell. Its parameter passes in the object that corresponds to the selected object. Optional.
 */

typedef void(^GRCellSelectionHandler)(id selectedObject);
typedef void(^GRCellCustomizeHandler)(id cell, id object);

-(void)registerContentView:(id)contentView forCollection:(GRCollection *)collection customizeHandler:(GRCellCustomizeHandler)customizeHandler selectionHandler:(GRCellSelectionHandler)selectionHandler;

/* Connects a GRCollection to a UITableView or UICollectionView. eg.

    self.users = [GRCollection collectionWithClass:[MYUser class]];
    [self registerContentView:self.tableView forCollection:self.users cellSubclass:[MYUserCell class] selectionHandler:^(id selectedObject){
        NSLog(@"Selected: %@", selectedObject);
    }];
 
 This will populate the tableView with all the objects in the collection and will send the MYUserCell a updateCellForObject: message when it needs to display data. See GRContentCell for more info (declared in GRCollection.h).

 @param cellSubclass The class of the cell to register with the contentView
 @param selectionHandler A block that is called when the user selects the cell. Its parameter passes in the object that corresponds to the selected object. Optional.
 */
-(void)registerContentView:(id)contentView forCollection:(GRCollection *)collection cellSubclass:(Class)cellSubclass selectionHandler:(GRCellSelectionHandler)selectionHandler;

///
/// Deregistration
///

/* Removes any binding containing this object. In other words, it undoes observeObject: or registerControl:withKeyPath:. */
-(void)deregisterObject:(GRObject *)object;

@end
