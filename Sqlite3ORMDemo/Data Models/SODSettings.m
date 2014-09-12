//
//  SODSettings.m
//  Sqlite3ORMDemo
//
//  Created by Bakuf on 9/8/14.
//  Copyright (c) 2014 bakufsoft. All rights reserved.
//

#import "SODSettings.h"

@implementation SODSettings

+ (BOOL)absoluteRow{
    return YES;
}

+ (NSDictionary *)getDefaultDictionaryValues{
    NSMutableDictionary *defaultValues = [[NSMutableDictionary alloc] initWithDictionary:[super getDefaultDictionaryValues]];;
    defaultValues[@"uniqueId"] = [[NSUUID UUID] UUIDString];
    return defaultValues;
}

@end
