//
//  VMVideoCache.h
//  VMWebVideo
//
//  Created by Benjamin Maer on 12/14/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMWebVideoCompat.h"





typedef NS_ENUM(NSInteger, VMVideoCacheType) {
	/**
	 * The video wasn't available the VMWebVideo caches.
	 */
	VMVideoCacheTypeNone,

	/**
	 * The video was obtained from the disk cache.
	 */
	VMVideoCacheTypeDisk,
};





typedef void(^VMVideoCacheQueryFilePathCompletionBlock)(NSURL *videoDataFilePath, VMVideoCacheType cacheType);
typedef void(^VMVideoCacheQueryVideoDataCompletionBlock)(NSData *videoData, VMVideoCacheType cacheType);

typedef void(^VMWebVideoCheckCacheCompletionBlock)(BOOL isInCache);

typedef void(^VMWebVideoCalculateSizeBlock)(NSUInteger fileCount, NSUInteger totalSize);





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

+ (VMVideoCache *)sharedVidoeCache;

- (void)storeVideoDataToDiskInBackground:(NSData *)videoData forKey:(NSString *)key completion:(VMVideoCacheQueryFilePathCompletionBlock)completion;

//This method is blocking
- (void)storeVideoDataToDisk:(NSData *)videoData forKey:(NSString *)key;


- (NSOperation *)queryCacheForKey:(NSString *)key filePathCompletion:(VMVideoCacheQueryFilePathCompletionBlock)filePathCompletion;

- (NSOperation *)queryCacheForKey:(NSString *)key videoDataCompletion:(VMVideoCacheQueryVideoDataCompletionBlock)videoDataCompletion;

/**
 * Query the memory cache synchronously.
 *
 * @param key The unique key used to store the wanted image
 */
- (NSURL *)videoDataFilePathFromCacheForKey:(NSString *)key;

/**
 *  Check if image exists in disk cache already (does not load the image)
 *
 *  @param key the key describing the url
 *
 *  @return YES if an image exists for the given key
 */
- (BOOL)videoExistsWithKey:(NSString *)key;

/**
 *  Async check if image exists in disk cache already (does not load the image)
 *
 *  @param key             the key describing the url
 *  @param completionBlock the block to be executed when the check is done.
 *  @note the completion block will be always executed on the main queue
 */
- (void)videoExistsWithKey:(NSString *)key completion:(VMWebVideoCheckCacheCompletionBlock)completionBlock;

/**
 * Remove the video from disk cache
 *
 * @param key             The unique video cache key
 * @param completionBlock An block that should be executed after the video has been removed (optional). The cacheType passed through the block represents where the video was removed from: VMVideoCacheType_Disk indicates it was removed from disk, VMVideoCacheType_None indicates it wasn't removed.
 */
- (void)removeVideoForKey:(NSString *)key completion:(VMWebVideoNoParamsBlock)completion;

/**
 * Clear all disk cached videos. Non-blocking method - returns immediately.
 * @param completionBlock An block that should be executed after cache expiration completes (optional)
 */
- (void)clearDiskOnCompletion:(VMWebVideoNoParamsBlock)completion;

/**
 * Remove all expired cached videos from disk. Non-blocking method - returns immediately.
 * @param completionBlock An block that should be executed after cache expiration completes (optional)
 */
- (void)cleanDiskWithCompletionBlock:(VMWebVideoNoParamsBlock)completionBlock;

- (void)calculateSizeWithCompletionBlock:(VMWebVideoCalculateSizeBlock)completionBlock;

@end
