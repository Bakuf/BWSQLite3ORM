//
//  BWDataBaseManager.h
//  
//
//  Created by Bakuf on 7/8/14.
//  Copyright (c) 2014 Rodrigo Galvez. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BWDataModel.h"

@interface BWDataBaseManager : NSObject

+ (instancetype)sharedInstance;

- (void)dropTableForDataModelClass:(Class)dataModelClass;
- (void)deleteDataBase;

//Insert,Get,Update Row Methods

//Inserts row into table with the given data model
- (void)insertRowFromDataModel:(BWDataModel*)dataModel;

//Updates the row with the data model given, the property id should be set, if it is null a insert will be made
- (void)updateRowFromDataModel:(BWDataModel*)dataModel;

//Delete the row with the data model given, the property id should be set
- (void)deleteRowFromDataModel:(BWDataModel*)dataModel;

//Returns a mutable array of the data model class given with all the rows of the table
- (NSMutableArray*)getAllRowsForDataModel:(Class)dataModelClass;

//Get the last row of the table for the data model class given
- (BWDataModel*)getLastInsertedRowForDataModel:(Class)dataModelClass;

//Returns a mutable array of the data model class given with the results of the query
- (NSMutableArray*)getRowsFromQuery:(NSString*)query forDataModel:(Class)dataModelClass;

//Returns an array of dictionaries with the results of the query
//raw data :
//NSDate = float
//Dictionary and Array = JSON
- (NSMutableArray*)getRawDataFromQuery:(NSString*)query;

@end
