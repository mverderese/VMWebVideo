//
//  VMWebVideoDownloader.h
//  VMWebVideo
//
//  Created by Mike Verderese on 12/15/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "VMWebVideoOperation.h"
#import "VMWebVideoCompat.h"

typedef NS_OPTIONS(NSUInteger, VMWebVideoDownloaderOptions) {
    VMWebVideoDownloaderLowPriority = 1 << 0,
    VMWebVideoDownloaderProgressiveDownload = 1 << 1,
    
    /**
     * By default, request prevent the of NSURLCache. With this flag, NSURLCache
     * is used with default policies.
     */
    VMWebVideoDownloaderUseNSURLCache = 1 << 2,
    
    /**
     * Call completion block with nil image/imageData if the image was read from NSURLCache
     * (to be combined with `SDWebImageDownloaderUseNSURLCache`).
     */
    
    VMWebVideoDownloaderIgnoreCachedResponse = 1 << 3,
    /**
     * In iOS 4+, continue the download of the image if the app goes to background. This is achieved by asking the system for
     * extra time in background to let the request finish. If the background task expires the operation will be cancelled.
     */
    
    VMWebVideoDownloaderContinueInBackground = 1 << 4,
    
    /**
     * Handles cookies stored in NSHTTPCookieStore by setting
     * NSMutableURLRequest.HTTPShouldHandleCookies = YES;
     */
    VMWebVideoDownloaderHandleCookies = 1 << 5,
    
    /**
     * Enable to allow untrusted SSL ceriticates.
     * Useful for testing purposes. Use with caution in production.
     */
    VMWebVideoDownloaderAllowInvalidSSLCertificates = 1 << 6,
    
    /**
     * Put the image in the high priority queue.
     */
    VMWebVideoDownloaderHighPriority = 1 << 7,
};

typedef NS_ENUM(NSInteger, VMWebVideoDownloaderExecutionOrder) {
    /**
     * Default value. All download operations will execute in queue style (first-in-first-out).
     */
    VMWebVideoDownloaderFIFOExecutionOrder,
    
    /**
     * All download operations will execute in stack style (last-in-first-out).
     */
    VMWebVideoDownloaderLIFOExecutionOrder
};

extern NSString *const VMWebVideoDownloadStartNotification;
extern NSString *const VMWebVideoDownloadStopNotification;

typedef void(^VMWebVideoDownloaderProgressBlock)(NSInteger receivedSize, NSInteger expectedSize);

typedef void(^VMWebVideoDownloaderCompletedBlock)(NSData *videoData, NSError *error, BOOL finished);

typedef NSDictionary *(^VMWebVideoDownloaderHeadersFilterBlock)(NSURL *url, NSDictionary *headers);

/**
 * Asynchronous downloader dedicated and optimized for image loading.
 */
@interface VMWebVideoDownloader : NSObject

@property (assign, nonatomic) NSInteger maxConcurrentDownloads;

/**
 * Shows the current amount of downloads that still need to be downloaded
 */

@property (readonly, nonatomic) NSUInteger currentDownloadCount;


/**
 *  The timeout value (in seconds) for the download operation. Default: 15.0.
 */
@property (assign, nonatomic) NSTimeInterval downloadTimeout;


/**
 * ----------- FOR FUTURE USE --------------
 */
/**
 * Changes download operations execution order. Default value is `SDWebImageDownloaderFIFOExecutionOrder`.
 */
@property (assign, nonatomic) VMWebVideoDownloaderExecutionOrder executionOrder;
/**
 * -------------------------------------------------------
 */


/**
 *  Singleton method, returns the shared instance
 *
 *  @return global shared instance of downloader class
 */
+ (VMWebVideoDownloader *)sharedDownloader;

/**
 * Set username
 */
@property (strong, nonatomic) NSString *username;

/**
 * Set password
 */
@property (strong, nonatomic) NSString *password;

/**
 * Set filter to pick headers for downloading image HTTP request.
 *
 * This block will be invoked for each downloading image request, returned
 * NSDictionary will be used as headers in corresponding HTTP request.
 */
@property (nonatomic, copy) VMWebVideoDownloaderHeadersFilterBlock headersFilter;

/**
 * Set a value for a HTTP header to be appended to each download HTTP request.
 *
 * @param value The value for the header field. Use `nil` value to remove the header.
 * @param field The name of the header field to set.
 */
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

/**
 * Returns the value of the specified HTTP header field.
 *
 * @return The value associated with the header field field, or `nil` if there is no corresponding header field.
 */
- (NSString *)valueForHTTPHeaderField:(NSString *)field;

/**
 * Sets a subclass of `SDWebImageDownloaderOperation` as the default
 * `NSOperation` to be used each time SDWebImage constructs a request
 * operation to download an image.
 *
 * @param operationClass The subclass of `SDWebImageDownloaderOperation` to set
 *        as default. Passing `nil` will revert to `SDWebImageDownloaderOperation`.
 */
- (void)setOperationClass:(Class)operationClass;



/**
 * Creates a VMWebVideoDownloader async downloader instance with a given URL
 *
 * The delegate will be informed when the image is finish downloaded or an error has happen.
 *
 * @see SDWebImageDownloaderDelegate
 *
 * @param url            The URL to the image to download
 * @param options        The options to be used for this download
 * @param progressBlock  A block called repeatedly while the image is downloading
 * @param completedBlock A block called once the download is completed.
 *                       If the download succeeded, the image parameter is set, in case of error,
 *                       error parameter is set with the error. The last parameter is always YES
 *                       if VMWebVideoDownloaderProgressiveDownload isn't use. With the
 *                       VMWebVideoDownloaderProgressiveDownload option, this block is called
 *                       repeatedly with the partial image object and the finished argument set to NO
 *                       before to be called a last time with the full image and finished argument
 *                       set to YES. In case of error, the finished argument is always YES.
 *
 * @return A cancellable VMWebVideoOperation
 */
- (id <VMWebVideoOperation>)downloadVideoWithURL:(NSURL *)url
                                         options:(VMWebVideoDownloaderOptions)options
                                        progress:(VMWebVideoDownloaderProgressBlock)progressBlock
                                       completed:(VMWebVideoDownloaderCompletedBlock)completedBlock;

/**
 * Sets the download queue suspension state
 */
- (void)setSuspended:(BOOL)suspended;

@end
