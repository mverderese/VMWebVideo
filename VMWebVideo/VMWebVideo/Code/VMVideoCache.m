//
//  VMImageCache.m
//  VMWebVideo
//
//  Created by Benjamin Maer on 12/14/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import "VMVideoCache.h"

#import "RUSingleton.h"





@interface VMVideoCache ()

@property (nonatomic, readonly) dispatch_queue_t ioQueue;
@property (nonatomic, readonly) NSString *diskCachePath;
@property (nonatomic, readonly) NSFileManager* fileManager;

-(void)backgroundCleanDisk;

-(void)notificationDidFire_UIApplication_WillTerminateNotification;
-(void)notificationDidFire_UIApplication_DidEnterBackgroundNotification;

@end





@implementation VMVideoCache

#pragma mark - VMVideoCache init
- (instancetype)initWithNamespace:(NSString *)ns
{
	if ((self = [super init]))
	{
		const char *kVMVideoCache_localNamespaceCString = "com.VMWebVideo.VMVideoCache";

		NSString* localNamespaceString = [NSString stringWithUTF8String:kVMVideoCache_localNamespaceCString];
		NSString *fullNamespace = [NSString stringWithFormat:@"%@.%@",localNamespaceString,ns];
		
		_ioQueue = dispatch_queue_create(kVMVideoCache_localNamespaceCString, DISPATCH_QUEUE_SERIAL);

		// Init default values
		_maxCacheAge = 60 * 60 * 24 * 7 * 8; // 8 weeks;
		
		NSArray* cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
		NSString* firstCachePath = cachePaths.firstObject;
		_diskCachePath = [firstCachePath stringByAppendingPathComponent:fullNamespace];
		
		dispatch_sync(_ioQueue, ^{
			_fileManager = [NSFileManager new];
		});

		
#if TARGET_OS_IPHONE
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(notificationDidFire_UIApplication_WillTerminateNotification)
													 name:UIApplicationWillTerminateNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(notificationDidFire_UIApplication_DidEnterBackgroundNotification)
													 name:UIApplicationDidEnterBackgroundNotification
												   object:nil];
#endif

	}
	
	return self;
}

#pragma mark - NSObject
- (instancetype)init
{
	return [self initWithNamespace:@"default"];
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillTerminateNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

#pragma mark - Singleton
RUSingletonUtil_Synthesize_Singleton_Implementation_SharedInstance;

#pragma mark - NSNotificationCenter
-(void)notificationDidFire_UIApplication_WillTerminateNotification
{
	[self cleanDiskWithCompletion:nil];
}

-(void)notificationDidFire_UIApplication_DidEnterBackgroundNotification
{
	[self backgroundCleanDisk];
}

#pragma mark - Clean Disk
-(void)backgroundCleanDisk
{
	UIApplication *application = [UIApplication sharedApplication];
	__block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
		// Clean up any unfinished task business by marking where you
		// stopped or ending the task outright.
		[application endBackgroundTask:bgTask];
		bgTask = UIBackgroundTaskInvalid;
	}];
	
	// Start the long-running task and return immediately.
	[self cleanDiskWithCompletion:^{
		[application endBackgroundTask:bgTask];
		bgTask = UIBackgroundTaskInvalid;
	}];
}

- (void)cleanDiskWithCompletion:(VMVideoCacheNoParamsBlock)completionBlock
{
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

@end
