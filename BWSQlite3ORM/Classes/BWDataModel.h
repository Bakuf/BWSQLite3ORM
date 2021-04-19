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

typedef NS_ENUM(NSInteger,BWSyncType) {
    BWSyncTypeAsync,
    BWSyncTypeSync,
    
    //Next 2 will ignore custom queue identifier and run in main queue
    BWSyncTypeMainAsync,
    BWSyncTypeMainSync
};

@interface BWDataModel : NSObject <NSCoding>

typedef void (^operationResult)(BOOL success, NSString *error);
typedef void (^queryResult)(BOOL success, NSString *error,NSMutableArray *results);

@property (nonatomic, strong) NSString* BWRowId;
@property (nonatomic, strong) NSArray *mutateOnlyFields;
@property (nonatomic, assign) BOOL createdFromSQLite;
@property (nonatomic, assign) BOOL wasModifiedAfterFetch;

//Settings Properties to override in your own class
+ (BOOL)absoluteRow;
+ (void (^)(bool ifTableExists))initBlockCompletition;
+ (BOOL)saveDateWithOutTime;
+ (BOOL)MonthlyTable;

- (NSDictionary*)BWCustomParsingPropertiesInfo;
- (NSArray*)BWNestedModelsStringNamesOrSufix;
- (BOOL)shouldPerformRecursiveOperation:(sqliteOperation)operation onPropType:(NSString*)type;

//Utility Methods
+ (NSDate *)dateWithOutTime:(NSDate *)datDate;
+ (NSString *)dateStringFromDate:(NSDate *)datDate;

//Start of CRUD Methods
+ (void)uniqueRowWithResult:(queryResult)result;
+ (void)deleteTable;
+ (void)deleteDatabase;

//New insert, update, delete - Methods
- (void)performSqliteOperationWithType:(sqliteOperation)operation withResult:(operationResult)result;
- (void)performSqliteOperationWithType:(sqliteOperation)operation recursive:(BOOL)recursive withResult:(operationResult)result;
- (void)performSqliteOperationWithType:(sqliteOperation)operation recursive:(BOOL)recursive withResult:(operationResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType;
+ (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels withResult:(operationResult)result;
+ (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels recursive:(BOOL)recursive withResult:(operationResult)result;
+ (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels recursive:(BOOL)recursive withResult:(operationResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType;

//Old insert, update, delete - Methods
- (void)insertRow;
- (void)updateRow;
- (void)deleteRow;
- (void)insertIfNotUpdateRow;

//Query Methods
+ (void)getAllRowsWithResult:(queryResult)result;
+ (void)getAllRowsWithResult:(queryResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType;
+ (void)getAllRowsOrderedBy:(NSString*)orderedBy withResult:(queryResult)result;
+ (void)getAllRowsOrderedBy:(NSString*)orderedBy withResult:(queryResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType;
+ (void)makeSelectQuery:(NSString*)query withResult:(queryResult)result;
+ (void)makeSelectQuery:(NSString*)query withResult:(queryResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType;
+ (void)rawQuery:(NSString*)query withResult:(queryResult)result;
+ (void)rawQuery:(NSString*)query withResult:(queryResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType;

//End of CRUD Methods
//ORM Methods
- (void)swapOrderWithDataModel:(BWDataModel*)otherDataModel;

+ (void)runInBWCustomQueue:(NSString*)identifier withSyncType:(BWSyncType)type completion:(void(^)(void))block;

+ (NSDictionary *)classPropsFor:(Class)klass;

+ (NSString*)allPropertiesSeparatedByComa;
+ (NSDictionary*)getDefaultDictionaryValues;

- (NSDictionary*)getParseDictionaryValues;
- (instancetype)setDataModelValuesFromDictionary:(NSDictionary*)dict;
- (instancetype)setBasicDataModelValuesFromDictionary:(NSDictionary*)dict;
- (void)modelValuesWereSetFromSQLite:(NSDictionary*)dict;

+ (NSArray*)parseResultsArray:(NSArray*)resultsArray;

@end
