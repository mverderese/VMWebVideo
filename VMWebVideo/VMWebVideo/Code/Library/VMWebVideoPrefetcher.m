//
//  VMWebVideoPrefetcher.m
//  VMWebVideo
//
//  Created by Mike Verderese on 12/15/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import "VMWebVideoPrefetcher.h"

@interface VMWebVideoPrefetcher ()

@property (strong, nonatomic) VMWebVideoManager *manager;
@property (strong, nonatomic) NSArray *prefetchURLs;
@property (assign, nonatomic) NSUInteger requestedCount;
@property (assign, nonatomic) NSUInteger skippedCount;
@property (assign, nonatomic) NSUInteger finishedCount;
@property (assign, nonatomic) NSTimeInterval startedTime;
@property (copy, nonatomic) VMWebVideoPrefetcherCompletionBlock completionBlock;
@property (copy, nonatomic) VMWebVideoPrefetcherProgressBlock progressBlock;

@end

@implementation VMWebVideoPrefetcher

+ (VMWebVideoPrefetcher *)sharedVideoPrefetcher {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (id)init {
    if ((self = [super init])) {
        _manager = [VMWebVideoManager new];
        _options = VMWebVideoLowPriority;
        self.maxConcurrentDownloads = 3;
    }
    return self;
}

- (void)setMaxConcurrentDownloads:(NSUInteger)maxConcurrentDownloads {
    self.manager.videoDownloader.maxConcurrentDownloads = maxConcurrentDownloads;
}

- (NSUInteger)maxConcurrentDownloads {
    return self.manager.videoDownloader.maxConcurrentDownloads;
}

- (void)startPrefetchingAtIndex:(NSUInteger)index {
    if (index >= self.prefetchURLs.count) return;
    self.requestedCount++;
    [self.manager downloadVideoWithURL:self.prefetchURLs[index] options:self.options progress:nil completed:^(NSURL *videoDataFilePath, NSError *error, VMVideoCacheType cacheType, BOOL finished, NSURL *videoURL) {
        
        if (!finished) return;
        self.finishedCount++;
        
        if (videoDataFilePath) {
            if (self.progressBlock) {
                self.progressBlock(self.finishedCount,[self.prefetchURLs count]);
            }
            NSLog(@"Prefetched %@ out of %@", @(self.finishedCount), @(self.prefetchURLs.count));
        }
        else {
            if (self.progressBlock) {
                self.progressBlock(self.finishedCount,[self.prefetchURLs count]);
            }
            NSLog(@"Prefetched %@ out of %@ (Failed)", @(self.finishedCount), @(self.prefetchURLs.count));
            
            // Add last failed
            self.skippedCount++;
        }
        if ([self.delegate respondsToSelector:@selector(videoPrefetcher:didPrefetchURL:finishedCount:totalCount:)]) {
            [self.delegate videoPrefetcher:self
                            didPrefetchURL:self.prefetchURLs[index]
                             finishedCount:self.finishedCount
                                totalCount:self.prefetchURLs.count
             ];
        }
        
        if (self.prefetchURLs.count > self.requestedCount) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startPrefetchingAtIndex:self.requestedCount];
            });
        }
        else if (self.finishedCount == self.requestedCount) {
            [self reportStatus];
            if (self.completionBlock) {
                self.completionBlock(self.finishedCount, self.skippedCount);
                self.completionBlock = nil;
            }
        }
    }];
}

- (void)reportStatus {
    NSUInteger total = [self.prefetchURLs count];
    NSLog(@"Finished prefetching (%@ successful, %@ skipped, timeElasped %.2f)", @(total - self.skippedCount), @(self.skippedCount), CFAbsoluteTimeGetCurrent() - self.startedTime);
    if ([self.delegate respondsToSelector:@selector(videoPrefetcher:didFinishWithTotalCount:skippedCount:)]) {
        [self.delegate videoPrefetcher:self
               didFinishWithTotalCount:(total - self.skippedCount)
                          skippedCount:self.skippedCount
         ];
    }
}

- (void)prefetchURLs:(NSArray *)urls {
    [self prefetchURLs:urls progress:nil completed:nil];
}

- (void)prefetchURLs:(NSArray *)urls progress:(VMWebVideoPrefetcherProgressBlock)progressBlock completed:(VMWebVideoPrefetcherCompletionBlock)completionBlock {
    [self cancelPrefetching]; // Prevent duplicate prefetch request
    self.startedTime = CFAbsoluteTimeGetCurrent();
    self.prefetchURLs = urls;
    self.completionBlock = completionBlock;
    self.progressBlock = progressBlock;
    
    if(urls.count == 0){
        if(completionBlock){
            completionBlock(0,0);
        }
    }else{
        // Starts prefetching from the very first image on the list with the max allowed concurrency
        NSUInteger listCount = self.prefetchURLs.count;
        for (NSUInteger i = 0; i < self.maxConcurrentDownloads && self.requestedCount < listCount; i++) {
            [self startPrefetchingAtIndex:i];
        }
    }
}

- (void)cancelPrefetching {
    self.prefetchURLs = nil;
    self.skippedCount = 0;
    self.requestedCount = 0;
    self.finishedCount = 0;
    [self.manager cancelAll];
}

@end
