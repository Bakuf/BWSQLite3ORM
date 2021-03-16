//
//  BWDataBaseManager.h
//  
//
//  Created by Rodrigo Galvez on 7/8/14.
//  Copyright (c) 2014 Rodrigo Galvez. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BWDataModel.h"

@interface BWDataBaseManager : NSObject

+ (instancetype)sharedInstance;

+ (void)scanClassesAndInitializeAllBWDataModels;
+ (void)initializeTablesWithDataModelClasses:(NSArray*)dataModelClasses;

- (void)cleanForInitialize;
- (BOOL)isTableAlreadyInitialized:(NSString*)tableName;
- (void)dropTableForDataModelClass:(Class)dataModelClass;
- (void)deleteDataBase;

//Insert,Get,Update Row Methods
- (void)performSqliteOperationWithType:(sqliteOperation)operation forDataModel:(BWDataModel*)dataModel withResult:(operationResult)result;
- (void)performSqliteOperationWithType:(sqliteOperation)operation forDataModel:(BWDataModel *)dataModel recursive:(BOOL)recursive isRootObject:(BOOL)isRoot withResult:(operationResult)result;
- (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels withResult:(operationResult)result;
- (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels recursive:(BOOL)recursive withResult:(operationResult)result;

//Inserts row into table with the given data model
- (void)insertRowFromDataModel:(BWDataModel*)dataModel withOperationResult:(operationResult)opCallback;

//Updates the row with the data model given, the property id should be set, if it is null a insert will be made
- (void)updateRowFromDataModel:(BWDataModel*)dataModel withOperationResult:(operationResult)opCallback;

//Delete the row with the data model given, the property id should be set
- (void)deleteRowFromDataModel:(BWDataModel*)dataModel withOperationResult:(operationResult)opCallback;

//Insert the row with the data model given, if it already exist it will update it.
- (void)insertIfNotUpdateRowFromDataModel:(BWDataModel*)dataModel withOperationResult:(operationResult)opCallback;

//Returns a mutable array of the data model class given with all the rows of the table
- (void)getAllRowsForDataModel:(Class)dataModelClass WithResult:(queryResult)result;
- (void)getAllRowsForDataModel:(Class)dataModelClass orderedBy:(NSString*)orderedBy WithResult:(queryResult)result;

//Get the last row of the table for the data model class given
- (BWDataModel*)getLastInsertedRowForDataModel:(Class)dataModelClass;

//Returns a mutable array of the data model class given with the results of the query
- (void)getRowsFromQuery:(NSString*)query forDataModel:(Class)dataModelClass WithResult:(queryResult)result;

//Returns an array of dictionaries with the results of the query
//raw data :
//NSDate = float
//Dictionary and Array = JSON
- (void)getRawDataFromQuery:(NSString*)theQuery makeFromClass:(Class)dataModelClass withResult:(queryResult)result;

@end
