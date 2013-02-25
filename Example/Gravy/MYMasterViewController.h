//
//  MYMasterViewController.h
//  Gravy
//
//  Created by Nathan Tesler on 25/02/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRViewController.h"
#import "MYDetailViewController.h"

@interface MYMasterViewController : GRViewController <UISearchBarDelegate>

// Setup
@property (strong, nonatomic) GRCollection *recipes;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

// Create
-(IBAction)addRecipe:(id)sender;

// Update
@property (strong, nonatomic) MYDetailViewController *detailViewController;

// Filter
@property (weak, nonatomic) IBOutlet UIBarButtonItem *quickButton;
-(IBAction)toggleQuickRecipes:(id)sender;

// Search
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;

@end
