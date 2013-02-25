//
//  MYRecipe.h
//  Gravy
//
//  Created by Nathan Tesler on 25/02/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRObject.h"

@interface MYRecipe : GRObject

@property (strong, nonatomic) NSString *title;
@property (strong, nonatomic) NSString *instructions;
@property (nonatomic) float prep;

@end
