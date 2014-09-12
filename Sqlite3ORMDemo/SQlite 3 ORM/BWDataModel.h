//
//  BWDataModel.h
//
//
//  Created by Bakuf on 7/3/14.
//  Copyright (c) 2014 Rodrigo Galvez. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BWDataModel : NSObject <NSCoding>

@property (nonatomic, retain) NSNumber* BWRowId;

//Settings Properties to override in your own class
+ (BOOL)absoluteRow;
+ (void (^)(bool ifTableExists))initBlockCompletition;

//CRUD Methods

+ (instancetype)uniqueRow;
- (void)insertRow;
- (void)updateRow;
- (void)deleteRow;
+ (void)deleteTable;
+ (void)deleteDatabase;
+ (NSMutableArray*)getAllRows;
+ (NSMutableArray*)makeQuery:(NSString*)query;
+ (NSMutableArray*)rawQuery:(NSString*)query;

- (void)swapOrderWithDataModel:(BWDataModel*)otherDataModel;

//ORM Methods

+ (NSDictionary *)classPropsFor:(Class)klass;

+ (NSString*)allPropertiesSeparatedByComa;
+ (NSDictionary*)getDefaultDictionaryValues;

- (NSDictionary*)getParseDictionaryValues;
- (instancetype)setDataModelValuesFromDictionary:(NSDictionary*)dict;

@end
