//
//  BWDataBaseManager.m
//
//
//  Created by Bakuf on 7/8/14.
//  Copyright (c) 2014 Rodrigo Galvez. All rights reserved.
//

#import "BWDataBaseManager.h"
#import <objc/runtime.h>
#import <sqlite3.h>

#define DatabaseName @"DB.db"

@interface BWDataBaseManager(){
    sqlite3 *database;
    sqlite3_stmt *statement;
    NSString *tableName;
    NSString *query;
    
    int affectedRows;
    int lastInsertedRowID;
    
    NSMutableArray *resultsArray;
    BOOL allTablesInitialized;
    NSMutableArray *classesAlreadyInitialized;
}

@end

@implementation BWDataBaseManager

#pragma mark -
#pragma mark Private Methods

+ (void)scanClassesAndInitializeAllBWDataModels{
    [[BWDataBaseManager sharedInstance] initializeDataModels];
}

+ (void)initializeTablesWithDataModelClasses:(NSArray*)dataModelClasses{
    for (NSString *className in dataModelClasses) {
        Class c = NSClassFromString(className);
        if (class_getSuperclass(c) == [BWDataModel class]) {
            //NSLog(@"%s is subclass of BWDataModel",class_getName(c));
            [[BWDataBaseManager sharedInstance] createTableWithDataModel:c];
        }
    }
}

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
        classesAlreadyInitialized = [[NSMutableArray alloc] init];
        allTablesInitialized = NO;
        [self openDB];
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
    allTablesInitialized = YES;
}



- (void)dropTableForDataModelClass:(Class)dataModelClass{
    query = [NSString stringWithFormat:@"drop table if exists %@",NSStringFromClass(dataModelClass)];
    [self runQuerywithParamValues:nil];
}

-(void)deleteDataBase{
    [self closeDB];
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
    
    BOOL alreadyInitialized = NO;
    for (NSString *table in classesAlreadyInitialized) {
        if ([table isEqualToString:className]) {
            alreadyInitialized = YES;
        }
    }
    if (alreadyInitialized){
        return;
    }else{
        [classesAlreadyInitialized addObject:className];
    }
    
    if (![self checkIfTableExists:className]) {
        tableName = className;
        query = [NSString stringWithFormat:@"drop table if exists %@",className];
        [self runQuerywithParamValues:nil];
        query = [NSString stringWithFormat:@"CREATE TABLE %@ (id INTEGER PRIMARY KEY %@)",className,[dataModel allPropertiesSeparatedByComa]];
        [self runQuerywithParamValues:nil];
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
            if (![self checkIfColumnExists:key InTable:className]) {
                [keysToAdd addObject:key];
                added = YES;
            }
        }
        if (added) {
            for (NSString *key in keysToAdd) {
                [self addColumn:key andDefaultValue:properties[key] inTable:className];
            }
            NSLog(@"New Property added to data model : %@ \n %@",NSStringFromClass(dataModel),keysToAdd);
            [self DisplayinLogContentofTable:className];
        }
        if ([dataModel initBlockCompletition] != nil && added) {
            [dataModel initBlockCompletition](YES);
        }
    }
}

#pragma mark Insert, Select, Update, Delete, Query Methods

- (void)insertDefaultValuesRowForDataModel:(Class)dataModelClass{
    if (![self checkClassForBWDataModel:dataModelClass])return;
    
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];
    
    tableName = NSStringFromClass(dataModelClass);
    [self insertRow:[dataModelClass getDefaultDictionaryValues]];
}

- (void)insertRowFromDataModel:(BWDataModel*)dataModel{
    
    if (!allTablesInitialized) [self createTableWithDataModel:[dataModel class]];
    
    tableName = NSStringFromClass([dataModel class]);
    [self insertRow:[dataModel getParseDictionaryValues]];
}

- (BWDataModel*)getLastInsertedRowForDataModel:(Class)dataModelClass{
    if (![self checkClassForBWDataModel:dataModelClass])return nil;
    
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];
    
    id dataModel = NULL;
    tableName = NSStringFromClass(dataModelClass);
    NSInteger numberOfRows = [self getRowsCount];
    if (numberOfRows != 0) {
        NSDictionary *row = [self getRow:[NSNumber numberWithInteger:numberOfRows]];
        
        dataModel = [[dataModelClass alloc] init];
        [dataModel setDataModelValuesFromDictionary:row];
    }
    
    return dataModel;
}

- (void)deleteRowFromDataModel:(BWDataModel*)dataModel{
    tableName = NSStringFromClass([dataModel class]);
    query = [NSString stringWithFormat:@"delete from %@ where id = ?", tableName];
    [self runQuerywithParamValues:@[dataModel.BWRowId]];
}

- (NSMutableArray*)getAllRowsForDataModel:(Class)dataModelClass{
    if (![self checkClassForBWDataModel:dataModelClass])return nil;
    
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];
    
    tableName = NSStringFromClass(dataModelClass);
    query = [NSString stringWithFormat:@"select * from %@", tableName];
    [self runQuerywithParamValues:nil];
    NSMutableArray *data = [[NSMutableArray alloc] init];
    for (NSDictionary *row in resultsArray) {
        id dataModel = [[dataModelClass alloc] init];
        [dataModel setDataModelValuesFromDictionary:row];
        [data addObject:dataModel];
    }
    return data;
}

- (NSMutableArray*)getAllRowsForDataModel:(Class)dataModelClass orderedBy:(NSString*)orderedBy{
    if (![self checkClassForBWDataModel:dataModelClass])return nil;
    
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];
    
    tableName = NSStringFromClass(dataModelClass);
    query = [NSString stringWithFormat:@"select * from %@ order by %@", tableName,orderedBy];
    [self runQuerywithParamValues:nil];
    NSMutableArray *data = [[NSMutableArray alloc] init];
    for (NSDictionary *row in resultsArray) {
        id dataModel = [[dataModelClass alloc] init];
        [dataModel setDataModelValuesFromDictionary:row];
        [data addObject:dataModel];
    }
    return data;
}

- (NSMutableArray*)getRowsFromQuery:(NSString*)theQuery forDataModel:(Class)dataModelClass{
    if (![self checkClassForBWDataModel:dataModelClass])return nil;
    
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];
    
    query = [NSString stringWithFormat:@"SELECT * FROM %@ %@",NSStringFromClass(dataModelClass),theQuery];
    [self runQuerywithParamValues:nil];
    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    if (resultsArray.count != 0) {
        for (int i = 0; i < resultsArray.count; i++) {
            id dataModel = [[dataModelClass alloc] init];
            [returnArray addObject:[dataModel setDataModelValuesFromDictionary:resultsArray[i]]];
        }
    }
    NSLog(@"Results from query : %@ \n%@",query,resultsArray);
    return returnArray;
}

- (NSMutableArray*)getRawDataFromQuery:(NSString*)theQuery makeFromClass:(Class)dataModelClass{
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];
    query = theQuery;
    [self runQuerywithParamValues:nil];
    return resultsArray;
}

- (void)updateRowFromDataModel:(BWDataModel*)dataModel{
    tableName = NSStringFromClass([dataModel class]);
    [self updateRow:[dataModel getParseDictionaryValues] rowID:dataModel.BWRowId];
}

#pragma mark Validations Methods

- (BOOL)checkClassForBWDataModel:(Class)theClass{
    if (![theClass isSubclassOfClass:[BWDataModel class]]) {
        NSLog(@"ERROR : The data model class passed as parameter is not of type BWDataModel");
        return NO;
    }
    return YES;
}

#pragma mark SQLITE 3 Methods

- (void) openDB {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *dbPath = [documentsDirectory stringByAppendingPathComponent:DatabaseName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
        // The database file does not exist in the documents directory, so copy it from the main bundle now.
        NSString *sourcePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:DatabaseName];
        NSError *error;
        [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:dbPath error:&error];
        
        // Check if any error occurred during copying and display it.
        if (error != nil) {
            NSLog(@"%@", [error localizedDescription]);
        }
    }
    if (sqlite3_open([dbPath UTF8String], &database) != SQLITE_OK) {
        NSAssert1(0, @"Error: initializeDatabase: could not open database (%s)", sqlite3_errmsg(database));
    }
}

- (void) closeDB {
    if (database) sqlite3_close(database);
    database = NULL;
}

-(void)runQuerywithParamValues:(NSArray*)paramValues{
    
    // Initialize the results array.
    resultsArray = [[NSMutableArray alloc] init];
    
    // Load all data from database to memory.
    int prepareStatementResult = sqlite3_prepare_v2(database, [query UTF8String], -1, &statement, NULL);
    if(prepareStatementResult == SQLITE_OK) {
        [self bindParameterValues:paramValues];
        // Check if the query is non-executable.
        int rc = sqlite3_step(statement);
        if (rc == SQLITE_ROW) {
            // In this case data must be loaded from the database.
            //Since we already made a step to check if the query was executable or not we need to fetch the first row
            [self addRowToResultsArray];
            
            // Loop through the results and add them to the results array row by row.
            while(sqlite3_step(statement) == SQLITE_ROW) {
                [self addRowToResultsArray];
            }
        }else if (rc == SQLITE_DONE){
            // Keep the affected rows.
            affectedRows = sqlite3_changes(database);
            
            // Keep the last inserted row ID.
            //                lastInsertedRowID = sqlite3_last_insert_rowid(database);
        }else{
            // If could not execute the query show the error message on the debugger.
            NSLog(@"DB Error: %s", sqlite3_errmsg(database));
        }
    } else {
        // In the database cannot be opened then show the error message on the debugger.
        NSLog(@"%s", sqlite3_errmsg(database));
    }
    
    // Release the compiled statement from memory.
    if(sqlite3_finalize(statement) == SQLITE_OK) {
        int numChanges = sqlite3_changes(database);
        if (numChanges > 0) NSLog(@"%d Changes to databes from query %@ with params : %@",numChanges,query,paramValues);
    } else {
        NSLog(@"doQuery (%@) with params (%@) : sqlite3_finalize failed (%s)", query, paramValues, sqlite3_errmsg(database));
    }
    
}

- (void)bindParameterValues:(NSArray*)values{
    if (values == nil) return;
    int param_count;
    if ((param_count = sqlite3_bind_parameter_count(statement))) {
        for (int i = 0; i < param_count; i++) {
            id o = values[i];
            
            if (o == nil) {
                sqlite3_bind_null(statement, i + 1);
            } else if ([o respondsToSelector:@selector(objCType)]) {
                if (strchr("islISLB", *[o objCType])) { // integer
                    sqlite3_bind_int(statement, i + 1, [o intValue]);
                } else if (strcmp([o objCType], @encode(long)) == 0){ //long
                    sqlite3_bind_int(statement, i + 1, [o intValue]);
                } else if (strchr("fd", *[o objCType])) {   // double
                    sqlite3_bind_double(statement, i + 1, [o doubleValue]);
                } else {    // unhandled types
                    NSLog(@"bindParameterValues: Unhandled objCType: %s = %@", [o objCType],o);
                    statement = NULL;
                    return;
                }
            } else if ([o respondsToSelector:@selector(UTF8String)]) { // string
                sqlite3_bind_text(statement, i + 1, [o UTF8String], -1, SQLITE_TRANSIENT);
            } else {    // unhhandled type
                NSLog(@"bindParameterValues : Unhandled parameter type: %@", [o class]);
                statement = NULL;
                return;
            }
        }
    }
}

- (id) columnValue:(int) columnIndex {
    // NSLog(@"%s columnIndex: %d", __FUNCTION__, columnIndex);
    id o = nil;
    switch(sqlite3_column_type(statement, columnIndex)) {
        case SQLITE_INTEGER:
            o = [NSNumber numberWithInt:sqlite3_column_int(statement, columnIndex)];
            break;
        case SQLITE_FLOAT:
            o = [NSNumber numberWithFloat:sqlite3_column_double(statement, columnIndex)];
            break;
        case SQLITE_TEXT:
            o = [NSString stringWithUTF8String:(const char *) sqlite3_column_text(statement, columnIndex)];
            break;
        case SQLITE_BLOB:
            o = [NSData dataWithBytes:sqlite3_column_blob(statement, columnIndex) length:sqlite3_column_bytes(statement, columnIndex)];
            break;
        case SQLITE_NULL:
            o = [NSNull null];
            break;
    }
    return o;
}

- (void)addRowToResultsArray{
    // Initialize the mutable dictionary that will contain the data of a fetched row.
     NSMutableDictionary *dicDataRow = [[NSMutableDictionary alloc] init];
    
    // Get the total number of columns.
    int totalColumns = sqlite3_column_count(statement);
    
    // Go through all columns and fetch each column data.
    for (int i=0; i<totalColumns; i++){
        NSString * columnName = [NSString stringWithUTF8String:sqlite3_column_name(statement, i)];
        [dicDataRow setObject:[self columnValue:i] forKey:columnName];
    }
    
    // Store each fetched data row in the results array, but first check if there is actually data.
    if (dicDataRow.count > 0) {
        [resultsArray addObject:dicDataRow];
    }
}

- (BOOL)checkIfTableExists:(NSString*)Table{
    sqlite3_stmt *statementChk;
    const char *query = [[NSString stringWithFormat:@"SELECT name FROM sqlite_master WHERE type='table' AND name='%@';",Table] UTF8String];
    sqlite3_prepare_v2(database, query, -1, &statementChk, nil);
    
    bool boo = FALSE;
    
    if (sqlite3_step(statementChk) == SQLITE_ROW) {
        boo = TRUE;
    }
    sqlite3_finalize(statementChk);
    
    return boo;
}

- (BOOL)checkIfColumnExists:(NSString*)column InTable:(NSString*)Table{
    //""
    bool boo = NO;
    query = [NSString stringWithFormat:@"pragma table_info (%@)",Table];
    [self runQuerywithParamValues:nil];
    for (int i = 0; i < resultsArray.count; i++) {
        NSDictionary *row = resultsArray[i];
        if ([row[@"name"] isEqualToString:column]) {
            boo = YES;
        }
    }
    //NSLog(@"la validacion de la columna %@ en la tabla %@ dio : %@",column,Table,boo?@"YES":@"NO");
    return boo;
}

- (void)addColumn:(NSString*)columnName andDefaultValue:(id)defaultValue inTable:(NSString*)table{
    query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ DEFAULT %@",table,columnName,defaultValue];
    if ([defaultValue isKindOfClass:[NSString class]] || [defaultValue isKindOfClass:[NSNumber class]]) {
        [self runQuerywithParamValues:nil];
        return;
    }
    NSLog(@"addColumn on BWDB does not support the class : %@",NSStringFromClass([defaultValue class]));
}

-(void)DisplayinLogContentofTable:(NSString*)TableName{
    NSLog(@"All Values For Table %@",TableName);
    tableName = TableName;
    query = [NSString stringWithFormat:@"select * from %@", tableName];
    [self runQuerywithParamValues:nil];
    for (NSDictionary *row in resultsArray) {
        NSLog(@"%@",row);
    }
}

- (void) insertRow:(NSDictionary *) record {
    
    record = [self checkForNulls:record];
    
    // construct the query
    NSMutableArray * placeHoldersArray = [NSMutableArray arrayWithCapacity:record.count];
    for (int i = 0; i < record.count; i++)  // array of ? markers for placeholders in query
        [placeHoldersArray addObject:@"?"];
    
    query = [NSString stringWithFormat:@"insert into %@ (%@) values (%@)",
                        tableName,
                        [[record allKeys] componentsJoinedByString:@","],
                        [placeHoldersArray componentsJoinedByString:@","]];
    
    [self runQuerywithParamValues:[record allValues]];
}

- (NSDictionary*)checkForNulls:(NSDictionary*)record{
    NSMutableDictionary *tmpD = [record mutableCopy];
    
    for (NSString *aKey in [record allKeys]) {
        if ([[record valueForKey:aKey] isKindOfClass:[NSNull class]]) {
            [tmpD setValue:@"" forKey:aKey];
        }
    }
    
    record = [NSDictionary dictionaryWithDictionary:tmpD];
    
    return record;
}

- (void) updateRow:(NSDictionary *)record rowID:(NSNumber*)rowID {
    
    record = [self checkForNulls:record];
    
    query = [NSString stringWithFormat:@"update %@ set %@ = ? where id = ?",
                        tableName,
                        [[record allKeys] componentsJoinedByString:@" = ?, "]];
    
    NSMutableArray *params = [NSMutableArray arrayWithArray:[record allValues]];
    [params addObject:rowID];
    
    [self runQuerywithParamValues:params];
}

- (NSDictionary *) getRow: (NSNumber*) rowID {
    query = [NSString stringWithFormat:@"select * from %@ where id = ?", tableName];
    [self runQuerywithParamValues:@[rowID]];
    NSDictionary *resultDictionary = [resultsArray lastObject];
    return resultDictionary;
}

- (NSInteger)getRowsCount{
    query = [NSString stringWithFormat:@"select count(*) from %@", tableName];
    
    NSInteger rows = 0;
    // Load all data from database to memory.
    BOOL prepareStatementResult = sqlite3_prepare_v2(database, [query UTF8String], -1, &statement, NULL);
    if(prepareStatementResult == SQLITE_OK) {
        int rc = sqlite3_step(statement);
        if (rc == SQLITE_DONE) {
            sqlite3_finalize(statement);
            return 0;
        } else  if (rc == SQLITE_ROW) {
            int col_count = sqlite3_column_count(statement);
            if (col_count < 1) return 0;  // shouldn't really ever happen
            rows = sqlite3_column_int(statement, 0);
        } else {    // rc == SQLITE_ROW
            NSLog(@"valueFromPreparedQuery: could not get row: %s", sqlite3_errmsg(database));
            return 0;
        }
    }else{
        // In the database cannot be opened then show the error message on the debugger.
        NSLog(@"%s", sqlite3_errmsg(database));
    }
    
    // Release the compiled statement from memory.
    if(sqlite3_finalize(statement) == SQLITE_OK) {
        NSLog(@"%@ Changes to databes from query %@",[NSNumber numberWithInt: sqlite3_changes(database)],query);
    } else {
        NSLog(@"doQuery (%@) : sqlite3_finalize failed (%s)", query, sqlite3_errmsg(database));
    }
    
    return rows;
}

@end
