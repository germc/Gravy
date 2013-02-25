//
//  MYDetailViewController.h
//  Gravy
//
//  Created by Nathan Tesler on 25/02/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRViewController.h"
#import "MYRecipe.h"

@interface MYDetailViewController : GRViewController

@property (strong, nonatomic) MYRecipe *recipe;

@property (weak, nonatomic) IBOutlet UITextField *titleField;
@property (weak, nonatomic) IBOutlet UITextView *instructionsField;
@property (weak, nonatomic) IBOutlet UISlider *prepSlider;

@end
