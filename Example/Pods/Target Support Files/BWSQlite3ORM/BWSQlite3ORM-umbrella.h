#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "BWDataBaseManager.h"
#import "BWDataModel.h"

FOUNDATION_EXPORT double BWSQlite3ORMVersionNumber;
FOUNDATION_EXPORT const unsigned char BWSQlite3ORMVersionString[];

