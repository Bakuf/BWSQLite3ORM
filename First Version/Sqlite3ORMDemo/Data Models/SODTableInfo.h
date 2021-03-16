//
//  SODTableInfo.h
//  Sqlite3ORMDemo
//
//  Created by Bakuf on 9/8/14.
//  Copyright (c) 2014 bakufsoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BWDataModel.h"

@interface SODTableInfo : BWDataModel

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *cellDescription;
@property (nonatomic, strong) NSString *date;

@end
