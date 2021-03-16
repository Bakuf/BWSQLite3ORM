//
//  BWTableInfo.h
//  BWSQlite3ORM_Example
//
//  Created by Rodrigo Galvez on 16/03/21.
//  Copyright © 2021 Rodrigo Galvez. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BWDataModel.h>

@interface BWTableInfo : BWDataModel

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *cellDescription;
@property (nonatomic, strong) NSString *date;

@end
