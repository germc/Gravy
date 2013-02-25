//
//  MYDetailViewController.m
//  Gravy
//
//  Created by Nathan Tesler on 25/02/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "MYDetailViewController.h"

@implementation MYDetailViewController

-(void)viewDidLoad
{
    [super viewDidLoad];

    // Register controls
    [self registerControl:self.titleField forKeyPath:keypath(self.recipe.title)];
    [self registerControl:self.instructionsField forKeyPath:keypath(self.recipe.instructions)];

    // Register slider with transformer block
    [self registerControl:self.prepSlider forKeyPath:keypath(self.recipe.prep) valueTranformer:^id(id objectValue, id controlValue){
        if (objectValue)
            return @([objectValue floatValue] / 100);
        else if (controlValue)
            return @([controlValue floatValue] * 100);

        return @(0);
    }];
}

@end
