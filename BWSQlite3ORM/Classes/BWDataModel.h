//
//  BWDataModel.h
//
//
//  Created by Rodrigo Galvez on 7/3/14.
//  Copyright (c) 2014 Rodrigo Galvez. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define BWCustomPropInfoClass @"ClassName"
#define BWCustomPropInfoName @"propName"
#define BWCustomPropInfoId @"Id"
#define BWCustomPropInfoQuery @"NestedQ"

typedef NS_ENUM(NSInteger,sqliteOperation) {
    sqliteOperationCreate,
    sqliteOperationUpdate,
    sqliteOperationDelete,
    sqliteOperationInsertIfNotUpdate
};

@interface BWDataModel : NSObject <NSCoding>

typedef void (^operationResult)(BOOL success, NSString *error);
typedef void (^queryResult)(BOOL success, NSString *error,NSMutableArray *results);

@property (nonatomic, strong) NSString* BWRowId;
@property (nonatomic, strong) NSArray *mutateOnlyFields;
@property (nonatomic, assign) BOOL createdFromSQLite;

//Settings Properties to override in your own class
+ (BOOL)absoluteRow;
+ (void (^)(bool ifTableExists))initBlockCompletition;
+ (BOOL)saveDateWithOutTime;
+ (BOOL)MonthlyTable;

//Utility Methods
+ (NSDate *)dateWithOutTime:(NSDate *)datDate;
+ (NSString *)dateStringFromDate:(NSDate *)datDate;

//CRUD Methods

+ (void)uniqueRowWithResult:(queryResult)result;
- (void)insertRow;
- (void)updateRow;
- (void)deleteRow;
- (void)insertIfNotUpdateRow;
+ (void)deleteTable;
+ (void)deleteDatabase;
+ (void)getAllRowsWithResult:(queryResult)result;
+ (void)getAllRowsOrderedBy:(NSString*)orderedBy withResult:(queryResult)result;
+ (void)makeSelectQuery:(NSString*)query withResult:(queryResult)result;
+ (void)rawQuery:(NSString*)query withResult:(queryResult)result;

- (void)swapOrderWithDataModel:(BWDataModel*)otherDataModel;

- (NSDictionary*)BWCustomParsingPropertiesInfo;
- (NSArray*)BWNestedModelsStringNamesOrSufix;
- (BOOL)shouldPerformRecursiveOperation:(sqliteOperation)operation onPropType:(NSString*)type;

//ORM Methods

//Thread where all calls are sent
+ (void)runInBWThread:(void(^)(void))block;

+ (NSDictionary *)classPropsFor:(Class)klass;

+ (NSString*)allPropertiesSeparatedByComa;
+ (NSDictionary*)getDefaultDictionaryValues;

- (NSDictionary*)getParseDictionaryValues;
- (instancetype)setDataModelValuesFromDictionary:(NSDictionary*)dict;
- (instancetype)setBasicDataModelValuesFromDictionary:(NSDictionary*)dict;
- (void)modelValuesWereSetFromSQLite:(NSDictionary*)dict;

+ (NSArray*)parseResultsArray:(NSArray*)resultsArray;

- (void)performSqliteOperationWithType:(sqliteOperation)operation withResult:(operationResult)result;
- (void)performSqliteOperationWithType:(sqliteOperation)operation recursive:(BOOL)recursive withResult:(operationResult)result;
+ (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels withResult:(operationResult)result;
+ (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels recursive:(BOOL)recursive withResult:(operationResult)result;

@end
