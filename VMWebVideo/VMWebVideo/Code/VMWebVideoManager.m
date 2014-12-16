//
//  VMWebvideoManager.m
//  VMWebVideo
//
//  Created by Benjamin Maer on 12/14/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import "VMWebVideoManager.h"
#import <objc/message.h>

@interface VMWebVideoCombinedOperation : NSObject <VMWebVideoOperation>

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (copy, nonatomic) VMWebVideoNoParamsBlock cancelBlock;
@property (strong, nonatomic) NSOperation *cacheOperation;

@end

@interface VMWebVideoManager ()

@property (strong, nonatomic, readwrite) VMVideoCache *videoCache;
@property (strong, nonatomic, readwrite) VMWebVideoDownloader *videoDownloader;
@property (strong, nonatomic) NSMutableArray *failedURLs;
@property (strong, nonatomic) NSMutableArray *runningOperations;

@end

@implementation VMWebVideoManager

+ (id)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (id)init {
    if ((self = [super init])) {
        _videoCache = [self createCache];
        _videoDownloader = [VMWebVideoDownloader sharedDownloader];
        _failedURLs = [NSMutableArray new];
        _runningOperations = [NSMutableArray new];
    }
    return self;
}

- (VMVideoCache *)createCache {
    return [VMVideoCache sharedVidoeCache];
}

- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (self.cacheKeyFilter) {
        return self.cacheKeyFilter(url);
    }
    else {
        return [url absoluteString];
    }
}

- (BOOL)cachedVideoExistsForURL:(NSURL *)url {
    NSString *key = [self cacheKeyForURL:url];
    return [self.videoCache videoExistsWithKey:key];
}

- (void)cachedVideoExistsForURL:(NSURL *)url
                     completion:(VMWebVideoCheckCacheCompletionBlock)completionBlock {
    NSString *key = [self cacheKeyForURL:url];
    
    [self.videoCache videoExistsWithKey:key completion:^(BOOL isInCache) {
        dispatch_main_async_safe(^{
            if(completionBlock) {
                completionBlock(isInCache);
            }
        });
    }];
}

- (id <VMWebVideoOperation>)downloadVideoWithURL:(NSURL *)url
                                         options:(VMWebVideoOptions)options
                                        progress:(VMWebVideoDownloaderProgressBlock)progressBlock
                                       completed:(VMWebVideoCompletionWithFinishedBlock)completedBlock {
    // Invoking this method without a completedBlock is pointless
    NSAssert(completedBlock != nil, @"If you mean to prefetch the video, use -[VMWebVideoPrefetcher prefetchURLs] instead");
    
    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, XCode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }
    
    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }
    
    __block VMWebVideoCombinedOperation *operation = [VMWebVideoCombinedOperation new];
    __weak VMWebVideoCombinedOperation *weakOperation = operation;
    
    BOOL isFailedUrl = NO;
    @synchronized (self.failedURLs) {
        isFailedUrl = [self.failedURLs containsObject:url];
    }
    
    if (!url || (!(options & VMWebVideoRetryFailed) && isFailedUrl)) {
        dispatch_main_sync_safe(^{
            NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil];
            completedBlock(nil, error, VMVideoCacheTypeNone, YES, url);
        });
        return operation;
    }
    
    @synchronized (self.runningOperations) {
        [self.runningOperations addObject:operation];
    }
    NSString *key = [self cacheKeyForURL:url];
    
    operation.cacheOperation = [self.videoCache queryCacheForKey:key filePathCompletion:^(NSURL *videoDataFilePath, VMVideoCacheType cacheType) {
    
        if (operation.isCancelled) {
            @synchronized (self.runningOperations) {
                [self.runningOperations removeObject:operation];
            }
            
            return;
        }
        
        if ((!videoDataFilePath || options & VMWebVideoRefreshCached) && (![self.delegate respondsToSelector:@selector(videoManager:shouldDownloadVideoForURL:)] || [self.delegate videoManager:self shouldDownloadVideoForURL:url])) {
            if (videoDataFilePath && options & VMWebVideoRefreshCached) {
                dispatch_main_sync_safe(^{
                    // If video was found in the cache bug VMWebVideoRefreshCached is provided, notify about the cached video
                    // AND try to re-download it in order to let a chance to NSURLCache to refresh it from server.
                    completedBlock(videoDataFilePath, nil, cacheType, YES, url);
                });
            }
            
            // download if no video or requested to refresh anyway, and download allowed by delegate
            VMWebVideoDownloaderOptions downloaderOptions = 0;
            if (options & VMWebVideoLowPriority) downloaderOptions |= VMWebVideoDownloaderLowPriority;
            if (options & VMWebVideoProgressiveDownload) downloaderOptions |= VMWebVideoDownloaderProgressiveDownload;
            if (options & VMWebVideoRefreshCached) downloaderOptions |= VMWebVideoDownloaderUseNSURLCache;
            if (options & VMWebVideoContinueInBackground) downloaderOptions |= VMWebVideoDownloaderContinueInBackground;
            if (options & VMWebVideoHandleCookies) downloaderOptions |= VMWebVideoDownloaderHandleCookies;
            if (options & VMWebVideoAllowInvalidSSLCertificates) downloaderOptions |= VMWebVideoDownloaderAllowInvalidSSLCertificates;
            if (options & VMWebVideoHighPriority) downloaderOptions |= VMWebVideoDownloaderHighPriority;
            if (videoDataFilePath && options & VMWebVideoRefreshCached) {
                // force progressive off if video already cached but forced refreshing
                downloaderOptions &= ~VMWebVideoDownloaderProgressiveDownload;
                // ignore video read from NSURLCache if video if cached but force refreshing
                downloaderOptions |= VMWebVideoDownloaderIgnoreCachedResponse;
            }
            id <VMWebVideoOperation> subOperation = [self.videoDownloader downloadVideoWithURL:url options:downloaderOptions progress:progressBlock completed:^(NSData *videoData, NSError *error, BOOL finished) {
                if (weakOperation.isCancelled) {
                    // Do nothing if the operation was cancelled
                    // See #699 for more details
                    // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data
                }
                else if (error) {
                    dispatch_main_sync_safe(^{
                        if (!weakOperation.isCancelled) {
                            completedBlock(nil, error, VMVideoCacheTypeNone, finished, url);
                        }
                    });
                    
                    if (error.code != NSURLErrorNotConnectedToInternet && error.code != NSURLErrorCancelled && error.code != NSURLErrorTimedOut) {
                        @synchronized (self.failedURLs) {
                            [self.failedURLs addObject:url];
                        }
                    }
                }
                else {
                    
                    if (options & VMWebVideoRefreshCached && !videoData) {
                        // video refresh hit the NSURLCache cache, do not call the completion block
                    }
                    else {
                        
                        if (videoData && finished) {
                            [self.videoCache storeVideoDataToDisk:videoData forKey:key];
                        }
                        
                        NSURL *path = [self.videoCache videoDataFilePathFromCacheForKey:key];
                        
                        dispatch_main_sync_safe(^{
                            if (!weakOperation.isCancelled) {
                                completedBlock(path, nil, VMVideoCacheTypeNone, finished, url);
                            }
                        });
                    }
                }
                
                if (finished) {
                    @synchronized (self.runningOperations) {
                        [self.runningOperations removeObject:operation];
                    }
                }
            }];
            operation.cancelBlock = ^{
                [subOperation cancel];
                
                @synchronized (self.runningOperations) {
                    [self.runningOperations removeObject:weakOperation];
                }
            };
        }
        else if (videoDataFilePath) {
            dispatch_main_sync_safe(^{
                if (!weakOperation.isCancelled) {
                    completedBlock(videoDataFilePath, nil, cacheType, YES, url);
                }
            });
            @synchronized (self.runningOperations) {
                [self.runningOperations removeObject:operation];
            }
        }
        else {
            // video not in cache and download disallowed by delegate
            dispatch_main_sync_safe(^{
                if (!weakOperation.isCancelled) {
                    completedBlock(nil, nil, VMVideoCacheTypeNone, YES, url);
                }
            });
            @synchronized (self.runningOperations) {
                [self.runningOperations removeObject:operation];
            }
        }
    }];
    
    return operation;
}

- (void)saveVideoToCache:(NSData *)video forURL:(NSURL *)url {
    if (video && url) {
        NSString *key = [self cacheKeyForURL:url];
        [self.videoCache storeVideoDataToDisk:video forKey:key];
    }
}

- (void)cancelAll {
    @synchronized (self.runningOperations) {
        NSArray *copiedOperations = [self.runningOperations copy];
        [copiedOperations makeObjectsPerformSelector:@selector(cancel)];
        [self.runningOperations removeObjectsInArray:copiedOperations];
    }
}

- (BOOL)isRunning {
    return self.runningOperations.count > 0;
}

@end


@implementation VMWebVideoCombinedOperation

- (void)setCancelBlock:(VMWebVideoNoParamsBlock)cancelBlock {
    // check if the operation is already cancelled, then we just call the cancelBlock
    if (self.isCancelled) {
        if (cancelBlock) {
            cancelBlock();
        }
        _cancelBlock = nil; // don't forget to nil the cancelBlock, otherwise we will get crashes
    } else {
        _cancelBlock = [cancelBlock copy];
    }
}

- (void)cancel {
    self.cancelled = YES;
    if (self.cacheOperation) {
        [self.cacheOperation cancel];
        self.cacheOperation = nil;
    }
    if (self.cancelBlock) {
        self.cancelBlock();
        
        // TODO: this is a temporary fix to #809.
        // Until we can figure the exact cause of the crash, going with the ivar instead of the setter
        //        self.cancelBlock = nil;
        _cancelBlock = nil;
    }
}

@end
