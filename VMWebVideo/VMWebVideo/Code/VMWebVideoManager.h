//
//  VMWebImageManager.h
//  VMWebVideo
//
//  Created by Benjamin Maer on 12/14/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import <Foundation/Foundation.h>





@class VMVideoCache;





@interface VMWebVideoManager : NSObject

@property (nonatomic, readonly) VMVideoCache* videoCache;

@end
