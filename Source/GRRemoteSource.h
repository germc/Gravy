//
//  GRRemoteSource.h
//  Gravy
//
//  Created by Nathan Tesler on 31/01/13.
//  Copyright (c) 2013 Nathan Tesler. All rights reserved.
//

#import "GRSource.h"

@protocol GRRemoteObject

+(NSString *)endpoint;

@end

@interface GRRemoteSource : GRSource

@end
