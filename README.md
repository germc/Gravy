
# Gravy
Gravy is a native quick-start framework for iOS that turns your app ideas into a working Version 0.1 in minutes. Gravy is built with **developer happiness** as Priority Number 1. It takes care of all the boilerplate you've written a thousand times over, letting you focus just on what's cool and original in your next big project.

Say you want to build Pinterest for recipes. What a great idea! To show you how productive you'll be using Gravy, here's how to get v0.1 off the ground in 9 easy steps and ~20 lines of code.

## Step 1: The Model
We start by subclassing `GRObject` and creating a normal interface file. No database schemas to be found here!

*Recipe.h*

	@interface Recipe : GRObject
	
	@property (strong, nonatomic) NSString *instructions;
	@property (nonatomic) int prep;
	
	@end

## Step 2: The Source
Our model objects live in a "source" which holds all objects of the `Recipe` class. We want to save our recipes to disk, so we'll use a `GRLocalSource`, which handles persistence automatically.

*Recipe.m*

	@implementation Recipe 
	
	+(id)source 
	{
		return [GRLocalSource source:self];
	}
	
	@end

## Step 3: The Collection
In our view controller we want to access all the recipes we've created, so we create a `GRCollection`, a class which fetches `GRObject`.

*MasterViewController.m*
	
    self.recipes = [GRCollection collectionWithClass:[Recipe class]];

The collection will automatically update whenever we add, update or remove recipes.

## Step 4: The Content View
We want to present the recipes to the user, so we register the collection with a UITableView.

    [self registerContentView:self.tableView
            forCollection:self.recipes
         customizeHandler:^(UITableViewCell *cell, Recipe *recipe){ 
            cell.textLabel.text = recipe.instructions;
         }
         selectionHandler:^(Recipe *recipe){ 
                self.detailViewController.recipe = recipe;
                [self.navigationController pushViewController:self.detailViewController animated:YES];
         }
             
We'll override UITableViewDelegate/DataSource methods later to customize it, but for the moment, this will populate the table view with the objects in the collection. Any changes to the collection will update the table view as needed.

## Step 5: Creating Recipes

Adding new recipes is as simple as `alloc init` and `save`.

	-(void)addButtonPressed
	{
    	Recipe *newRecipe = [[Recipe alloc] init];
    	newRecipe.prep = 10;
    	[newRecipe save];
	}

## Step 6: Updating Recipes
You may want to provide a text view for the user to edit the recipe object. Here it is:

*DetailViewController.m*
	    
    [self registerControl:self.instructionView forKeyPath:keypath(self.recipe.instructions)];
	
That one line of code is your entire detail view. The `registerControl:forKeyPath:` method binds the text view to the `instructions` property on the `recipe` object. Enter text and it'll be set on the `recipe` object. Change the recipe object and the view will update. Magical!

## Step 7: Destroying Recipes
Back in your `MasterViewController` implement this UITableViewDataSource method to handle deletion:

	-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath 
	{
		if (editingStyle == UITableViewCellEditingStyleDelete) 
		{
			Recipe *recipe = [self.recipes objectAtIndexPath:indexPath];	
			[recipe remove];
		}
	}

## Step 8: The Server
Say we want to fetch recipes from a server. We just need to few lines of code to our app:

*Recipe.h*

	@interface Recipe : GRObject <GRRemoteObject> // Add protocol
	@property (nonatomic) BOOL isShared;

*Recipe.m*

	+(id)source 
	{
		return [GRRemoteSource source:self]; // Change source class
	}

	+(NSString *)endpoint 
	{
		return @"http://api.myserver.com/recipes"; // Specify location
	}
	
	-(BOOL)serializationShouldIncludeProperty:(NSString *)property context:(NSString *)context 
	{
		if ([property isEqualToString:keypath(isShared)])
			return NO;
			
		return YES;
	}

Rails makes it trivial to generate a simple back-end. Type into terminal:

	rails new Recipintrest
	rails g scaffold Recipe instructions:string prep:integer
	rails g migrate
	
and in recipes_controller#index change `Recipe.all` to `Recipe.where("updated_at < ?", params[:last_sync])`.

From here, GRRemoteSource will automatically fetch recipes from the specified URL, serialize the returned JSON data as `Recipe` objects and add those objects to itself. Which will in turn automatically populate your tableView with recipe objects. 

**Note:** GRRemoteSource is a stub at the moment. It will be expanded to provide deep integration with a RESTful backend before the 1.0 release of Gravy.

## Step 9: Networking
Now we have a back-end set up, let's interact with it. In `DetailViewController` we've added a share button which calls this code:

	GRHTTPRequest *request = [GRHTTPRequest request:@"http://api.myserver.com/recipes"];
	request.HTTPMethod = GRHTTPMethodPost;
	request.payload = self.recipe;
	request.successHandler = ^(HTTPResponse *response){
		self.recipe.isShared = YES;
	};
	
	[request load];

**That's it.** That's about 20 lines of code to build a working CRUD app with a full user interface and server component. This app isn't going to get featured on the App Store, but it's an excellent starting point and it's good enough to pass around to some friends to get some feedback. 

Gravy is all about *convention over configuration*. It assumes you want to create a normal app, and you only need to interfere if you have custom needs. This makes it incredibly customizable, and you can learn more by diving into the lightweight, readable and well-documented source code.

# Installation
Download the source and add the Gravy folder to a new blank Xcode project to get started, then just `#import "Gravy.h"`. If you'd like some easy bedtime reading, check out Gravy for Dummies (Introductory) and Gravy for Smarties (Advanced).

*Try Gravy and let your ideas run free.*