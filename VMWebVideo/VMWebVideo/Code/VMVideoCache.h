//
//  VMVideoCache.h
//  VMWebVideo
//
//  Created by Benjamin Maer on 12/14/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>





typedef NS_ENUM(NSInteger, VMVideoCacheType) {
	/**
	 * The video wasn't available the VMWebVideo caches.
	 */
	VMVideoCacheType_None,

	/**
	 * The video was obtained from the disk cache.
	 */
	VMVideoCacheType_Disk,
};





typedef void(^VMVideoCacheQueryCompletionBlock)(NSString* videoDataFilePath, VMVideoCacheType cacheType);
typedef void(^VMVideoCacheNoParamsBlock)();





@interface VMVideoCache : NSObject

- (instancetype)initWithNamespace:(NSString *)ns;

/**
 * The maximum length of time to keep an video in the cache, in seconds
 */
@property (assign, nonatomic) NSInteger maxCacheAge;

/**
 * The maximum size of the cache, in bytes.
 */
@property (assign, nonatomic) NSUInteger maxCacheSize;

+ (instancetype)sharedInstance;

/**
 * Store video data to disk cache at the given key.
 *
 * @param videoData		The videoData to store
 * @param key			The unique video cache key, usually it's video absolute URL
 */
- (void)storeVideoDataToDisk:(NSData *)videoData forKey:(NSString *)key;

- (NSOperation *)queryDiskCacheForKey:(NSString *)key completion:(VMVideoCacheQueryCompletionBlock)completion;

/**
 * Remove the video from disk cache
 *
 * @param key             The unique video cache key
 * @param completionBlock An block that should be executed after the video has been removed (optional). The cacheType passed through the block represents where the video was removed from: VMVideoCacheType_Disk indicates it was removed from disk, VMVideoCacheType_None indicates it wasn't removed.
 */
- (void)removeVideoForKey:(NSString *)key completion:(VMVideoCacheQueryCompletionBlock)completion;

/**
 * Clear all disk cached videos. Non-blocking method - returns immediately.
 * @param completionBlock An block that should be executed after cache expiration completes (optional)
 */
- (void)clearDiskWithCompletion:(VMVideoCacheNoParamsBlock)completion;

/**
 * Remove all expired cached videos from disk. Non-blocking method - returns immediately.
 * @param completionBlock An block that should be executed after cache expiration completes (optional)
 */
- (void)cleanDiskWithCompletion:(VMVideoCacheNoParamsBlock)completionBlock;

@end
