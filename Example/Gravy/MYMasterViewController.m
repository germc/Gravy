//
//  MYMasterViewController.m
//  Gravy
//
//  Created by Nathan Tesler on 25/02/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "MYMasterViewController.h"
#import "MYRecipe.h"

@interface MYMasterViewController ()
@property (nonatomic, getter = isQuickies) BOOL quickies;
@end

@implementation MYMasterViewController

///
/// Setup
///

-(void)viewDidLoad
{
    [super viewDidLoad];

    // Fetch all recipes
    self.recipes = [GRCollection collectionWithClass:[MYRecipe class] sortDescriptor:[NSSortDescriptor sortDescriptorWithKey:@"updateDate" ascending:NO]];

    // Register the collection with the table view
    [self registerContentView:self.tableView
                forCollection:self.recipes
             customizeHandler:^(UITableViewCell *cell, MYRecipe *recipe){
                 cell.textLabel.text = recipe.title;
                 cell.detailTextLabel.text = recipe.instructions;
             }
             selectionHandler:^(MYRecipe *selectedRecipe){
                 [self showDetailViewWithRecipe:selectedRecipe];
             }];
}

///
/// Create
///

-(IBAction)addRecipe:(id)sender
{
    MYRecipe *newRecipe = [[MYRecipe alloc] init];
    newRecipe.prep = arc4random() % 100;
    [newRecipe save];

    [self showDetailViewWithRecipe:newRecipe];
}

///
/// Update
///

-(void)showDetailViewWithRecipe:(MYRecipe *)recipe
{
    // Get the detailViewController, set the detail item and present the view.
    // You can do this any way you prefer (storyboards, nibs, segues, in code, etc)
    if (!self.detailViewController)
        self.detailViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"Detail"];

    self.detailViewController.recipe = recipe;
    [self.navigationController pushViewController:self.detailViewController animated:YES];
}

// Destroy

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    MYRecipe *recipe = [self.recipes objectAtIndexPath:indexPath];
    [recipe remove];
}

///
/// Filter
///

-(IBAction)toggleQuickRecipes:(id)sender
{
    // Toggle quickies
    [self setQuickies:!self.isQuickies];
}

-(void)setQuickies:(BOOL)quickies
{
    _quickies = quickies;

    if (_quickies)
    {
        // Toggle prep time predicate
        self.recipes.predicate = [NSPredicate predicateWithFormat:@"prep < 30"];
        self.quickButton.title = NSLocalizedString(@"All", nil);
    }
    else
    {
        self.recipes.predicate = nil;
        self.quickButton.title = NSLocalizedString(@"Quickies", nil);
    }
}

///
/// Search
///

-(BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    // Set quickies to NO when starting the search
    if (self.isQuickies)
        [self setQuickies:NO];

    return YES;
}

-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if ([searchText length])
        self.recipes.predicate = [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@", searchText];
    else
        self.recipes.predicate = nil;
}

-(void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = nil;
    self.recipes.predicate = nil;

    [searchBar resignFirstResponder];
}

-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

@end
