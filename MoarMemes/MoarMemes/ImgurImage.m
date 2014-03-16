//
//  ImgurImage.m
//  MoarMemes
//
//  Created by Vova Galchenko on 3/16/14.
//  Copyright (c) 2014 Galchenko. All rights reserved.
//

#import "ImgurImage.h"

@implementation ImgurImage

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    NSAssert([dictionary[@"is_album"] isEqualToNumber:@(0)], @"We don't support albums yet.");
    NSAssert([dictionary[@"animated"] isEqualToNumber:@(0)], @"We don't support animated images yet.");
    NSString *imageID = dictionary[@"id"];
    NSString *imageURLString = dictionary[@"link"];
    NSString *extension = [imageURLString pathExtension];
    NSString *pathWithoutExtension = [imageURLString stringByDeletingPathExtension];
    NSURL *imageURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@l.%@", pathWithoutExtension, extension]];
    self = [super initWithURL:imageURL imageID:imageID];
    return self;
}

@end
