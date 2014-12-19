//
//  VMWebImageManager.h
//  VMWebVideo
//
//  Created by Benjamin Maer on 12/14/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import "VMWebVideoCompat.h"
#import "VMWebVideoOperation.h"
#import "VMWebVideoDownloader.h"
#import "VMVideoCache.h"

typedef NS_OPTIONS(NSUInteger, VMWebVideoOptions) {
    /**
     * By default, when a URL fail to be downloaded, the URL is blacklisted so the library won't keep trying.
     * This flag disable this blacklisting.
     */
    VMWebVideoRetryFailed = 1 << 0,
    
    /**
     * By default, image downloads are started during UI interactions, this flags disable this feature,
     * leading to delayed download on UIScrollView deceleration for instance.
     */
    VMWebVideoLowPriority = 1 << 1,
    
    /**
     * This flag enables progressive download, the image is displayed progressively during download as a browser would do.
     * By default, the image is only displayed once completely downloaded.
     */
    VMWebVideoProgressiveDownload = 1 << 2,
    
    /**
     * Even if the image is cached, respect the HTTP response cache control, and refresh the image from remote location if needed.
     * The disk caching will be handled by NSURLCache instead of SDWebImage leading to slight performance degradation.
     * This option helps deal with images changing behind the same request URL, e.g. Facebook graph api profile pics.
     * If a cached image is refreshed, the completion block is called once with the cached image and again with the final image.
     *
     * Use this flag only if you can't make your URLs static with embeded cache busting parameter.
     */
    VMWebVideoRefreshCached = 1 << 3,
    
    /**
     * In iOS 4+, continue the download of the image if the app goes to background. This is achieved by asking the system for
     * extra time in background to let the request finish. If the background task expires the operation will be cancelled.
     */
    VMWebVideoContinueInBackground = 1 << 4,
    
    /**
     * Handles cookies stored in NSHTTPCookieStore by setting
     * NSMutableURLRequest.HTTPShouldHandleCookies = YES;
     */
    VMWebVideoHandleCookies = 1 << 5,
    
    /**
     * Enable to allow untrusted SSL ceriticates.
     * Useful for testing purposes. Use with caution in production.
     */
    VMWebVideoAllowInvalidSSLCertificates = 1 << 6,
    
    /**
     * By default, image are loaded in the order they were queued. This flag move them to
     * the front of the queue and is loaded immediately instead of waiting for the current queue to be loaded (which
     * could take a while).
     */
    VMWebVideoHighPriority = 1 << 7,
};

typedef void(^VMWebVideoCompletionBlock)(NSURL *videoDataFilePath, NSError *error, VMVideoCacheType cacheType, NSURL *videoURL);

typedef void(^VMWebVideoCompletionWithFinishedBlock)(NSURL *videoDataFilePath, NSError *error, VMVideoCacheType cacheType, BOOL finished, NSURL *videoURL);

typedef NSString *(^VMWebVideoCacheKeyFilterBlock)(NSURL *url);


@class VMWebVideoManager;

@protocol VMWebVideoManagerDelegate <NSObject>

@optional

/**
 * Controls which image should be downloaded when the image is not found in the cache.
 *
 * @param imageManager The current `SDWebImageManager`
 * @param imageURL     The url of the image to be downloaded
 *
 * @return Return NO to prevent the downloading of the image on cache misses. If not implemented, YES is implied.
 */
- (BOOL)videoManager:(VMWebVideoManager *)videoManager shouldDownloadVideoForURL:(NSURL *)videoURL;

@end

/**
 * The SDWebImageManager is the class behind the UIImageView+WebCache category and likes.
 * It ties the asynchronous downloader (SDWebImageDownloader) with the image cache store (SDImageCache).
 * You can use this class directly to benefit from web image downloading with caching in another context than
 * a UIView.
 *
 * Here is a simple example of how to use SDWebImageManager:
 *
 * @code
 
 SDWebImageManager *manager = [SDWebImageManager sharedManager];
 [manager downloadWithURL:imageURL
 options:0
 progress:nil
 completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
 if (image) {
 // do something with image
 }
 }];
 
 * @endcode
 */
@interface VMWebVideoManager : NSObject

@property (weak, nonatomic) id <VMWebVideoManagerDelegate> delegate;

@property (strong, nonatomic, readonly) VMVideoCache *videoCache;
@property (strong, nonatomic, readonly) VMWebVideoDownloader *videoDownloader;

/**
 * The cache filter is a block used each time SDWebImageManager need to convert an URL into a cache key. This can
 * be used to remove dynamic part of an image URL.
 *
 * The following example sets a filter in the application delegate that will remove any query-string from the
 * URL before to use it as a cache key:
 *
 * @code
 
 [[SDWebImageManager sharedManager] setCacheKeyFilter:^(NSURL *url) {
 url = [[NSURL alloc] initWithScheme:url.scheme host:url.host path:url.path];
 return [url absoluteString];
 }];
 
 * @endcode
 */
@property (nonatomic, copy) VMWebVideoCacheKeyFilterBlock cacheKeyFilter;

/**
 * Returns global SDWebImageManager instance.
 *
 * @return SDWebImageManager shared instance
 */
+ (VMWebVideoManager *)sharedManager;

/**
 * Downloads the image at the given URL if not present in cache or return the cached version otherwise.
 *
 * @param url            The URL to the image
 * @param options        A mask to specify options to use for this request
 * @param progressBlock  A block called while image is downloading
 * @param completedBlock A block called when operation has been completed.
 *
 *   This parameter is required.
 *
 *   This block has no return value and takes the requested UIImage as first parameter.
 *   In case of error the image parameter is nil and the second parameter may contain an NSError.
 *
 *   The third parameter is an `SDImageCacheType` enum indicating if the image was retrived from the local cache
 *   or from the memory cache or from the network.
 *
 *   The last parameter is set to NO when the SDWebImageProgressiveDownload option is used and the image is
 *   downloading. This block is thus called repetidly with a partial image. When image is fully downloaded, the
 *   block is called a last time with the full image and the last parameter set to YES.
 *
 * @return Returns an NSObject conforming to SDWebImageOperation. Should be an instance of SDWebImageDownloaderOperation
 */
- (id <VMWebVideoOperation>)downloadVideoWithURL:(NSURL *)url
                                         options:(VMWebVideoOptions)options
                                        progress:(VMWebVideoDownloaderProgressBlock)progressBlock
                                       completed:(VMWebVideoCompletionWithFinishedBlock)completedBlock;

/**
 * Saves image to cache for given URL
 *
 * @param image The image to cache
 * @param url   The URL to the image
 *
 */

- (void)saveVideoToCache:(NSData *)video forURL:(NSURL *)url;

/**
 * Cancel all current opreations
 */
- (void)cancelAll;

/**
 * Check one or more operations running
 */
- (BOOL)isRunning;

/**
 *  Check if image has already been cached
 *
 *  @param url image url
 *
 *  @return if the image was already cached
 */
- (BOOL)cachedVideoExistsForURL:(NSURL *)url;

/**
 *  Async check if image has already been cached
 *
 *  @param url              image url
 *  @param completionBlock  the block to be executed when the check is finished
 *
 *  @note the completion block is always executed on the main queue
 */
- (void)cachedVideoExistsForURL:(NSURL *)url
                     completion:(VMWebVideoCheckCacheCompletionBlock)completionBlock;


/**
 *Return the cache key for a given URL
 */
- (NSString *)cacheKeyForURL:(NSURL *)url;

@end
