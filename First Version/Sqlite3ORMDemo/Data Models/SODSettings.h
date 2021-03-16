//
//  SODSettings.h
//  Sqlite3ORMDemo
//
//  Created by Bakuf on 9/8/14.
//  Copyright (c) 2014 bakufsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BWDataModel.h"

@interface SODSettings : BWDataModel

@property (nonatomic, strong) NSString *uniqueId;
@property (nonatomic, strong) NSString *lastTimeUsed;

@end
