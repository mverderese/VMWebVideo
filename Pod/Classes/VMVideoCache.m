//
//  VMImageCache.m
//  VMWebVideo
//
//  Created by Benjamin Maer on 12/14/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import "VMVideoCache.h"

#import "VMSingleton.h"
#import <CommonCrypto/CommonDigest.h>





static const NSInteger kDefaultCacheMaxCacheAge = 60 * 60 * 24 * 7; // 1 week





@interface VMVideoCache ()

@property (nonatomic, readonly) NSFileManager *fileManager;
@property (strong, nonatomic, readonly) NSString *diskCachePath;
@property (strong, nonatomic, readonly) NSMutableArray *customPaths;
@property (VMDispatchQueueSetterSementics, nonatomic, readonly) dispatch_queue_t ioQueue;

- (void)addReadOnlyCachePath:(NSString *)path;
- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path;
- (NSString *)defaultCachePathForKey:(NSString *)key;

- (NSString *)cachedFileNameForKey:(NSString *)key;

- (void)backgroundCleanDisk;

- (NSUInteger)getSize;
- (NSUInteger)getDiskCount;

@end





@implementation VMVideoCache

#pragma mark - NSObject
- (id)init {
    return [self initWithNamespace:@"default"];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	VMDispatchQueueRelease(self.ioQueue);
}

#pragma mark - VMVideoCache
- (id)initWithNamespace:(NSString *)ns {
    if ((self = [super init])) {
        NSString *fullNamespace = [@"com.vmlabs.VMWebVideoCache." stringByAppendingString:ns];
        
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.vmlabs.VMWebVideoCache", DISPATCH_QUEUE_SERIAL);
        
        // Init default values
        _maxCacheAge = kDefaultCacheMaxCacheAge;
        
        // Init the disk cache
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _diskCachePath = [paths[0] stringByAppendingPathComponent:fullNamespace];
        
        dispatch_sync(self.ioQueue, ^{
			//Performed on
            _fileManager = [NSFileManager new];
        });
        
#if TARGET_OS_IPHONE
        // Subscribe to app events
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cleanDisk)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundCleanDisk)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
    }
    
    return self;
}

- (void)addReadOnlyCachePath:(NSString *)path {
    if (!self.customPaths) {
        _customPaths = [NSMutableArray new];
    }
    
    if (![self.customPaths containsObject:path]) {
        [self.customPaths addObject:path];
    }
}

- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *)path {
    NSString *filename = [self cachedFileNameForKey:key];
    return [path stringByAppendingPathComponent:filename];
}

- (NSString *)defaultCachePathForKey:(NSString *)key {
    return [self cachePathForKey:key inPath:self.diskCachePath];
}

#pragma mark SDImageCache (private)

- (NSString *)cachedFileNameForKey:(NSString *)key {
    const char *str = [key UTF8String];
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
    
    return [filename stringByAppendingString:@".mov"];
}

#pragma mark ImageCache

- (void)storeVideoDataToDiskInBackground:(NSData *)videoData forKey:(NSString *)key completion:(VMVideoCacheQueryFilePathCompletionBlock)completion {
    if (!videoData || !key) {
        if(completion) {
            completion(nil, VMVideoCacheTypeNone);
        }
        return;
    }
    
    dispatch_async(self.ioQueue, ^{
        
        if (videoData) {
            if (![self.fileManager fileExistsAtPath:self.diskCachePath]) {
                [self.fileManager createDirectoryAtPath:self.diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            
            NSString *path = [self defaultCachePathForKey:key];
            [self.fileManager createFileAtPath:path contents:videoData attributes:nil];
            if(completion) {
                completion([NSURL fileURLWithPath:path], VMVideoCacheTypeNone);
            }
        }
    });
}

- (void)storeVideoDataToDisk:(NSData *)videoData forKey:(NSString *)key {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [self storeVideoDataToDiskInBackground:videoData forKey:key completion:^(NSURL *videoDataFilePath, VMVideoCacheType cacheType) {
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
}

- (BOOL)videoExistsWithKey:(NSString *)key {
    BOOL exists = NO;
    
    // this is an exception to access the filemanager on another queue than ioQueue, but we are using the shared instance
    // from apple docs on NSFileManager: The methods of the shared NSFileManager object can be called from multiple threads safely.
    exists = [[NSFileManager defaultManager] fileExistsAtPath:[self defaultCachePathForKey:key]];
    
    return exists;
}

- (void)videoExistsWithKey:(NSString *)key completion:(VMWebVideoCheckCacheCompletionBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        BOOL exists = [self.fileManager fileExistsAtPath:[self defaultCachePathForKey:key]];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

- (NSURL *)videoDataFilePathFromCacheForKey:(NSString *)key {
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath];
    if (data) {
//        defaultPath = [defaultPath stringByAppendingString:@".mov"];
        return [NSURL fileURLWithPath:defaultPath];
    }
    
    for (NSString *path in self.customPaths) {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath];
        if (imageData) {
            return [NSURL fileURLWithPath:filePath];
        }
    }
    
    return nil;
}

- (NSData *)diskVideoDataBySearchingAllPathsForKey:(NSString *)key {
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath];
    if (data) {
        return data;
    }
    
    for (NSString *path in self.customPaths) {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath];
        if (imageData) {
            return imageData;
        }
    }
    
    return nil;
}

- (NSData *)videoDataForKey:(NSString *)key {
    return [self diskVideoDataBySearchingAllPathsForKey:key];
}

- (NSOperation *)queryCacheForKey:(NSString *)key filePathCompletion:(VMVideoCacheQueryFilePathCompletionBlock)filePathCompletion {
    if (!filePathCompletion) {
        return nil;
    }
    
    if (!key) {
        filePathCompletion(nil, VMVideoCacheTypeNone);
        return nil;
    }
    
    NSOperation *operation = [NSOperation new];
    dispatch_async(self.ioQueue, ^{
        if (operation.isCancelled) {
            return;
        }
        
        @autoreleasepool {
            NSURL *filePath = [self videoDataFilePathFromCacheForKey:key];
            if(filePath) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    filePathCompletion(filePath, VMVideoCacheTypeDisk);
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    filePathCompletion(nil, VMVideoCacheTypeNone);
                });
            }
        }
    });
    
    return operation;
}

- (NSOperation *)queryCacheForKey:(NSString *)key videoDataCompletion:(VMVideoCacheQueryVideoDataCompletionBlock)videoDataCompletion {
    if (!videoDataCompletion) {
        return nil;
    }
    
    if (!key) {
        videoDataCompletion(nil, VMVideoCacheTypeNone);
        return nil;
    }
    
    NSOperation *operation = [NSOperation new];
    dispatch_async(self.ioQueue, ^{
        if (operation.isCancelled) {
            return;
        }
        
        @autoreleasepool {
            NSData *data = [self videoDataForKey:key];
            if(data) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    videoDataCompletion(data, VMVideoCacheTypeDisk);
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    videoDataCompletion(nil, VMVideoCacheTypeNone);
                });
            }
        }
    });
    
    return operation;

}

- (void)removeVideoForKey:(NSString *)key {
    [self removeVideoForKey:key completion:nil];
}

- (void)removeVideoForKey:(NSString *)key completion:(VMWebVideoNoParamsBlock)completion {
    
    if (key == nil) {
        return;
    }
    
    dispatch_async(self.ioQueue, ^{
        [self.fileManager removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
    
}

- (void)clearDisk {
    [self clearDiskOnCompletion:nil];
}

- (void)clearDiskOnCompletion:(VMWebVideoNoParamsBlock)completion
{
    dispatch_async(self.ioQueue, ^{
        [self.fileManager removeItemAtPath:self.diskCachePath error:nil];
        [self.fileManager createDirectoryAtPath:self.diskCachePath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL];
        
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

- (void)cleanDisk {
    [self cleanDiskWithCompletionBlock:nil];
}

- (void)cleanDiskWithCompletionBlock:(VMWebVideoNoParamsBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
        NSArray *resourceKeys = @[NSURLIsDirectoryKey, NSURLContentModificationDateKey, NSURLTotalFileAllocatedSizeKey];
        
        // This enumerator prefetches useful properties for our cache files.
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];
        
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.maxCacheAge];
        NSMutableDictionary *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;
        
        // Enumerate all of the files in the cache directory.  This loop has two purposes:
        //
        //  1. Removing files that are older than the expiration date.
        //  2. Storing file attributes for the size-based cleanup pass.
        NSMutableArray *urlsToDelete = [[NSMutableArray alloc] init];
        for (NSURL *fileURL in fileEnumerator) {
            NSDictionary *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:NULL];
            
            // Skip directories.
            if ([resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }
            
            // Remove files that are older than the expiration date;
            NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
            if ([[modificationDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                [urlsToDelete addObject:fileURL];
                continue;
            }
            
            // Store a reference to this file and account for its total size.
            NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            currentCacheSize += [totalAllocatedSize unsignedIntegerValue];
            [cacheFiles setObject:resourceValues forKey:fileURL];
        }
        
        for (NSURL *fileURL in urlsToDelete) {
            [self.fileManager removeItemAtURL:fileURL error:nil];
        }
        
        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // size-based cleanup pass.  We delete the oldest files first.
        if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize) {
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.maxCacheSize / 2;
            
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                            usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                            }];
            
            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                if ([self.fileManager removeItemAtURL:fileURL error:nil]) {
                    NSDictionary *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= [totalAllocatedSize unsignedIntegerValue];
                    
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

- (void)backgroundCleanDisk {
    UIApplication *application = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task and return immediately.
    [self cleanDiskWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}

- (NSUInteger)getSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtPath:self.diskCachePath];
        for (NSString *fileName in fileEnumerator) {
            NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    });
    return size;
}

- (NSUInteger)getDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtPath:self.diskCachePath];
        count = [[fileEnumerator allObjects] count];
    });
    return count;
}

- (void)calculateSizeWithCompletionBlock:(VMWebVideoCalculateSizeBlock)completionBlock {
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
    
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;
        
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:@[NSFileSize]
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];
        
        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += [fileSize unsignedIntegerValue];
            fileCount += 1;
        }
        
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

#pragma mark - Singleton
VMSingletonUtil_Synthesize_Singleton_Implementation(sharedVideoCache);

@end