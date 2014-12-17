//
//  VMWebVideoCompat.h
//  VMWebVideo
//
//  Created by Mike Verderese on 12/15/14.
//  Copyright (c) 2014 VM Labs. All rights reserved.
//

#import <TargetConditionals.h>

#ifdef __OBJC_GC__
#error VMWebVideo does not support Objective-C Garbage Collection
#endif

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
#error VMWebVideo doesn't support Deployement Target version < 5.0
#endif

#if !TARGET_OS_IPHONE
#import <AppKit/AppKit.h>
#ifndef UIImage
#define UIImage NSImage
#endif
#ifndef UIImageView
#define UIImageView NSImageView
#endif
#else

#import <UIKit/UIKit.h>

#endif

#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

#ifndef NS_OPTIONS
#define NS_OPTIONS(_type, _name) enum _name : _type _name; enum _name : _type
#endif

#if OS_OBJECT_USE_OBJC
#undef VMDispatchQueueRelease
#undef VMDispatchQueueSetterSementics
#define VMDispatchQueueRelease(q)
#define VMDispatchQueueSetterSementics strong
#else
#undef VMDispatchQueueRelease
#undef VMDispatchQueueSetterSementics
#define VMDispatchQueueRelease(q) (dispatch_release(q))
#define VMDispatchQueueSetterSementics assign
#endif

typedef void(^VMWebVideoNoParamsBlock)();

#define dispatch_main_sync_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_sync(dispatch_get_main_queue(), block);\
}

#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}