//
//  BWDataBaseManager.m
//
//
//  Created by Bakuf on 7/8/14.
//  Copyright (c) 2014 Rodrigo Galvez. All rights reserved.
//

#import "BWDataBaseManager.h"
#import "BWDB.h"
#import <objc/runtime.h>

#define DatabaseName @"DB.db"

@interface BWDataBaseManager(){
    BWDB *db;
}

@end

@implementation BWDataBaseManager

#pragma mark -
#pragma mark Private Methods

+ (instancetype)sharedInstance{
    static dispatch_once_t pred;
    static id shared = nil;
    dispatch_once(&pred, ^{
        shared = [[BWDataBaseManager alloc] init];
    });
    return shared;
}

-(id)init{
    
    self = [super init];
    if (self) {
        // Custom initialization
        //Init Database and create tables if necesary
        
        db = [[BWDB alloc] initWithDBFilename:DatabaseName];
        [self initializeDataModels];
    }
    return self;
    
}

- (void)initializeDataModels{
    int numClasses;
    Class * classes = NULL;
    
    classes = NULL;
    numClasses = objc_getClassList(NULL, 0);
    
    if (numClasses > 0 )
    {
        classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        for (int i = 0; i < numClasses; i++) {
            Class c = classes[i];
            NSBundle *b = [NSBundle bundleForClass:c];
            if (b == [NSBundle mainBundle]) {
                if (class_getSuperclass(c) == [BWDataModel class]) {
                    //NSLog(@"%s is subclass of BWDataModel",class_getName(c));
                    [self createTableWithDataModel:c];
                }
            }
        }
        free(classes);
    }
}



- (void)dropTableForDataModelClass:(Class)dataModelClass{
    [db doQuery:[NSString stringWithFormat:@"drop table if exists %@",NSStringFromClass(dataModelClass)]];
}

-(void)deleteDataBase{
    [db closeDB];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath =  [documentsDirectory stringByAppendingPathComponent:DatabaseName];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    
}

- (void)createTableWithDataModel:(Class)dataModel{
    if (![self checkClassForBWDataModel:dataModel])return;
    
    NSString *className = NSStringFromClass(dataModel);
    if (![db checkIfTableExists:className]) {
        [db setTableName:className];
        [db doQuery:[NSString stringWithFormat:@"drop table if exists %@",className]];
        [db doQuery:[NSString stringWithFormat:@"CREATE TABLE %@ (id INTEGER PRIMARY KEY %@)",className,[dataModel allPropertiesSeparatedByComa]]];
        NSLog(@"Table Created for Datamodel : %@",className);
        if ([dataModel absoluteRow]) {
            [self insertDefaultValuesRowForDataModel:dataModel];
        }
        if ([dataModel initBlockCompletition] != nil) {
            [dataModel initBlockCompletition](NO);
        }
    }else{
        BOOL added = NO;
        NSDictionary *properties = [dataModel getDefaultDictionaryValues];
        NSMutableArray *keysToAdd = [[NSMutableArray alloc] init];
        for (NSString* key in properties.allKeys) {
            if (![db checkIfColumnExists:key InTable:className]) {
                [keysToAdd addObject:key];
                added = YES;
            }
        }
        if (added) {
            for (NSString *key in keysToAdd) {
                [db addColumn:key andDefaultValue:properties[key] inTable:className];
            }
            NSLog(@"New Property added to data model : %@ \n %@",NSStringFromClass(dataModel),keysToAdd);
            [db DisplayinLogContentofTable:className];
        }
        if ([dataModel initBlockCompletition] != nil) {
            [dataModel initBlockCompletition](YES);
        }
    }
}

#pragma mark Insert, Select, Update, Delete, Query Methods

- (void)insertDefaultValuesRowForDataModel:(Class)dataModelClass{
    if (![self checkClassForBWDataModel:dataModelClass])return;
    
    [db setTableName:NSStringFromClass(dataModelClass)];
    [db insertRow:[dataModelClass getDefaultDictionaryValues]];
}

- (void)insertRowFromDataModel:(BWDataModel*)dataModel{
    [db setTableName:NSStringFromClass([dataModel class])];
    [db insertRow:[dataModel getParseDictionaryValues]];
}

- (BWDataModel*)getLastInsertedRowForDataModel:(Class)dataModelClass{
    if (![self checkClassForBWDataModel:dataModelClass])return nil;
    
    id dataModel = NULL;
    [db setTableName:NSStringFromClass(dataModelClass)];
    if ([[db countRows] integerValue] != 0) {
        NSDictionary *row = [db getRow:[db countRows]];
        
        dataModel = [[dataModelClass alloc] init];
        [dataModel setDataModelValuesFromDictionary:row];
    }
    
    return dataModel;
}

- (void)deleteRowFromDataModel:(BWDataModel*)dataModel{
    [db setTableName:NSStringFromClass([dataModel class])];
    [db deleteRow:dataModel.BWRowId];
}

- (NSMutableArray*)getAllRowsForDataModel:(Class)dataModelClass{
    if (![self checkClassForBWDataModel:dataModelClass])return nil;
    
    [db setTableName:NSStringFromClass(dataModelClass)];
    NSMutableArray *results = [db getAllRowsFromTable];
    NSMutableArray *data = [[NSMutableArray alloc] init];
    for (NSDictionary *row in results) {
        id dataModel = [[dataModelClass alloc] init];
        [dataModel setDataModelValuesFromDictionary:row];
        [data addObject:dataModel];
    }
    return data;
}

- (NSMutableArray*)getRowsFromQuery:(NSString*)query forDataModel:(Class)dataModelClass{
    if (![self checkClassForBWDataModel:dataModelClass])return nil;
    
    NSString *completeQuery = [NSString stringWithFormat:@"SELECT * FROM %@ %@",NSStringFromClass(dataModelClass),query];
    NSMutableArray *results = [db getRowsFromQuery:completeQuery];
    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    if (results.count != 0) {
        for (int i = 0; i < results.count; i++) {
            id dataModel = [[dataModelClass alloc] init];
            [returnArray addObject:[dataModel setDataModelValuesFromDictionary:results[i]]];
        }
    }
    NSLog(@"Results from query : %@ \n%@",query,results);
    return returnArray;
}

- (NSMutableArray*)getRawDataFromQuery:(NSString*)query{
    return [db getRowsFromQuery:query];
}

- (void)updateRowFromDataModel:(BWDataModel*)dataModel{
    [db setTableName:NSStringFromClass([dataModel class])];
    [db updateRow:[dataModel getParseDictionaryValues] rowID:dataModel.BWRowId];
}

#pragma mark Validations Methods

- (BOOL)checkClassForBWDataModel:(Class)theClass{
    if (![theClass isSubclassOfClass:[BWDataModel class]]) {
        NSLog(@"ERROR : The data model class passed as parameter is not of type BWDataModel");
        return NO;
    }
    return YES;
}

@end
