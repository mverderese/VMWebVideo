//
//  VMWebImageManager.m
//  VMWebVideo
//
//  Created by Benjamin Maer on 12/14/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import "VMWebVideoManager.h"
#import "VMVideoCache.h"

#import "RUSingleton.h"





@implementation VMWebVideoManager

#pragma mark - NSObject
-(instancetype)init
{
	if (self = [super init])
	{
		_videoCache = [VMVideoCache sharedInstance];
	}

	return self;
}

#pragma mark - Singleton
RUSingletonUtil_Synthesize_Singleton_Implementation_SharedInstance;

@end
