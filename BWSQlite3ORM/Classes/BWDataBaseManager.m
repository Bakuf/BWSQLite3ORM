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
    
    int affectedRows;
    NSString *lastInsertedRowID;
    
    BOOL allTablesInitialized;
    NSMutableArray *classesAlreadyInitialized;
    BOOL displayLogs;
}

@end

@implementation BWDataBaseManager

#pragma mark -
#pragma mark Private Methods

+ (void)scanClassesAndInitializeAllBWDataModels{
    [[BWDataBaseManager sharedInstance] initializeDataModels];
}

+ (void)initializeTablesWithDataModelClasses:(NSArray*)dataModelClasses{
    [BWDataModel runInBWThread:^{
        for (NSString *className in dataModelClasses) {
            Class c = NSClassFromString(className);
            if (class_getSuperclass(c) == [BWDataModel class] || class_getSuperclass(class_getSuperclass(c)) == [BWDataModel class]) {
                NSLog(@"%s is subclass of BWDataModel",class_getName(c));
                [[BWDataBaseManager sharedInstance] createTableWithDataModel:c];
            }
        }
    }];
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
        [self startDB];
    }
    return self;
    
}

- (void)cleanForInitialize{
    classesAlreadyInitialized = [[NSMutableArray alloc] init];
    allTablesInitialized = NO;
}

- (void)startDB{
    classesAlreadyInitialized = [[NSMutableArray alloc] init];
    allTablesInitialized = NO;
    displayLogs = NO;
    [self openDB];
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
    NSString *query = [NSString stringWithFormat:@"drop table if exists %@",NSStringFromClass(dataModelClass)];
    [self runQuery:query withParamValues:nil withResultsArray:nil withOperationResult:nil];
}

-(void)deleteDataBase{
    [self closeDB];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath =  [documentsDirectory stringByAppendingPathComponent:DatabaseName];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:filePath]){
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    
    //we create and open the database
    [self startDB];
}

- (BOOL)isTableAlreadyInitialized:(NSString*)tableName{
    BOOL alreadyInitialized = NO;
    for (NSString *table in classesAlreadyInitialized) {
        if ([table isEqualToString:tableName]) {
            alreadyInitialized = YES;
        }
    }
    return alreadyInitialized;
}

- (void)createTableWithDataModel:(Class)dataModel{
    if (![self checkClassForBWDataModel:dataModel])return;
    
    NSString *className = NSStringFromClass(dataModel);
    
    if ([dataModel MonthlyTable]) {
        className = [className stringByAppendingString:[dataModel dateStringFromDate:[NSDate date]]];
    }
    
    if ([self isTableAlreadyInitialized:className]){
        return;
    }else{
        [classesAlreadyInitialized addObject:className];
    }
    
    if (![self checkIfTableExists:className]) {
        NSString *query = [NSString stringWithFormat:@"drop table if exists %@",className];
        [self runQuery:query withParamValues:nil withResultsArray:nil withOperationResult:nil];
        query = [NSString stringWithFormat:@"CREATE TABLE %@ (id TEXT PRIMARY KEY %@)",className,[dataModel allPropertiesSeparatedByComa]];
        [self runQuery:query withParamValues:nil withResultsArray:nil withOperationResult:nil];
        if (displayLogs) NSLog(@"Table Created for Datamodel : %@",className);
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
            if (![key isEqualToString:@"Id"]) {
                if (![self checkIfColumnExists:key InTable:className]) {
                    [keysToAdd addObject:key];
                    added = YES;
                }
            }
        }
        if (added) {
            for (NSString *key in keysToAdd) {
                [self addColumn:key andDefaultValue:properties[key] inTable:className];
            }
            NSLog(@"SQL - New Property added to data model : %@ \n %@",NSStringFromClass(dataModel),keysToAdd);
            //[self DisplayinLogContentofTable:className];
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
    [self insertRow:[dataModelClass getDefaultDictionaryValues] forTable:NSStringFromClass(dataModelClass) withOperationResult:nil];
}

- (BWDataModel*)getLastInsertedRowForDataModel:(Class)dataModelClass{
    if (![self checkClassForBWDataModel:dataModelClass])return nil;
    
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];
    
    id dataModel = NULL;
//    NSInteger numberOfRows = [self getRowsCountForTable:NSStringFromClass(dataModelClass)];
//    if (numberOfRows != 0) {
//        NSDictionary *row = [self getRow:[NSNumber numberWithInteger:numberOfRows]];
//
//        dataModel = [[dataModelClass alloc] init];
//        [dataModel setDataModelValuesFromDictionary:row];
//    }
    
    return dataModel;
}

- (void)getAllRowsForDataModel:(Class)dataModelClass WithResult:(queryResult)result{
    if (![self checkClassForBWDataModel:dataModelClass])return;
    
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];

    NSMutableArray *resultsArray = [[NSMutableArray alloc] init];
    NSString *query = [NSString stringWithFormat:@"select * from %@", NSStringFromClass(dataModelClass)];
    NSString *error = [self runQuery:query withParamValues:nil withResultsArray:resultsArray withOperationResult:nil];
    NSMutableArray *data = [[NSMutableArray alloc] init];
    for (NSDictionary *row in resultsArray) {
        id dataModel = [[dataModelClass alloc] init];
        [dataModel setDataModelValuesFromDictionary:row];
        [data addObject:dataModel];
    }
    if (result != nil) result(error.length != 0 ? NO:YES,error,data);
}

- (void)getAllRowsForDataModel:(Class)dataModelClass orderedBy:(NSString*)orderedBy WithResult:(queryResult)result{
    if (![self checkClassForBWDataModel:dataModelClass])return;
    
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];
    
    NSMutableArray *resultsArray = [[NSMutableArray alloc] init];
    NSString *query = [NSString stringWithFormat:@"select * from %@ order by %@", NSStringFromClass(dataModelClass),orderedBy];
    NSString *error = [self runQuery:query withParamValues:nil withResultsArray:resultsArray withOperationResult:nil];
    NSMutableArray *data = [[NSMutableArray alloc] init];
    for (NSDictionary *row in resultsArray) {
        id dataModel = [[dataModelClass alloc] init];
        [dataModel setDataModelValuesFromDictionary:row];
        [data addObject:dataModel];
    }
    if (result != nil) result(error.length != 0 ? NO:YES,error,data);
}

- (void)getRowsFromQuery:(NSString*)theQuery forDataModel:(Class)dataModelClass WithResult:(queryResult)result{
    if (![self checkClassForBWDataModel:dataModelClass])return;
    
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];
    
    NSMutableArray *resultsArray = [[NSMutableArray alloc] init];
    NSString *query = [NSString stringWithFormat:@"SELECT * FROM %@ %@",NSStringFromClass(dataModelClass),theQuery];
    NSString *error = [self runQuery:query withParamValues:nil withResultsArray:resultsArray withOperationResult:nil];
    NSMutableArray *returnArray = [[NSMutableArray alloc] init];
    if (resultsArray.count != 0) {
        for (int i = 0; i < resultsArray.count; i++) {
            id dataModel = [[dataModelClass alloc] init];
            [returnArray addObject:[dataModel setDataModelValuesFromDictionary:resultsArray[i]]];
        }
    }
    if (displayLogs) NSLog(@"Results from query : %@ \n%@",query,resultsArray);
    if (result != nil) result(error.length != 0 ? NO:YES,error,returnArray);
}

- (void)getRawDataFromQuery:(NSString*)theQuery makeFromClass:(Class)dataModelClass withResult:(queryResult)result{
    if (!allTablesInitialized) [self createTableWithDataModel:dataModelClass];
    NSMutableArray *resultsArray = [[NSMutableArray alloc] init];
    NSString *error = [self runQuery:theQuery withParamValues:nil withResultsArray:resultsArray withOperationResult:nil];
    if (result != nil) result(error.length != 0 ? NO:YES,error,resultsArray);
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
    }else{
        [self createFunctions:database];
    }
}

- (void) closeDB {
    if (database) sqlite3_close(database);
    database = NULL;
}

-(NSString*)runQuery:(NSString*)query withParamValues:(NSArray*)paramValues withResultsArray:(NSMutableArray*)resultsArray withOperationResult:(operationResult)opCallback{
    
    // Initialize.
    NSString *error = @"";
    
    // Load all data from database to memory.
    sqlite3_stmt *statement;
    int prepareStatementResult = sqlite3_prepare_v2(database, [query UTF8String], -1, &statement, NULL);
    if(prepareStatementResult == SQLITE_OK) {
        [self bindParameterValues:paramValues forStatement:statement];
        // Check if the query is non-executable.
        int rc = sqlite3_step(statement);
        if (rc == SQLITE_ROW) {
            // In this case data must be loaded from the database.
            //Since we already made a step to check if the query was executable or not we need to fetch the first row
            [self addRowToResultsArrayWithStatement:statement withResultsArray:resultsArray];
            
            // Loop through the results and add them to the results array row by row.
            while(sqlite3_step(statement) == SQLITE_ROW) {
                [self addRowToResultsArrayWithStatement:statement withResultsArray:resultsArray];
            }
        }else if (rc == SQLITE_DONE){
            // Keep the affected rows.
            affectedRows = sqlite3_changes(database);
            
            // Keep the last inserted row ID.
            //                lastInsertedRowID = sqlite3_last_insert_rowid(database);
        }else{
            // If could not execute the query show the error message on the debugger.
            error = [error stringByAppendingFormat:@"DB Error: %s", sqlite3_errmsg(database)];
        }
    } else {
        // In the database cannot be opened then show the error message on the debugger.
        error = [error stringByAppendingFormat:@"%s", sqlite3_errmsg(database)];
    }
    
    // Release the compiled statement from memory.
    if(sqlite3_finalize(statement) == SQLITE_OK) {
        int numChanges = sqlite3_changes(database);
        if (numChanges > 0 && displayLogs) NSLog(@"%d Changes to databes from query %@ with params : %@",numChanges,query,paramValues);
    } else {
        error = [error stringByAppendingFormat:@"doQuery (%@) with params (%@) : sqlite3_finalize failed (%s)", query, paramValues, sqlite3_errmsg(database)];
    }
    
    if (error.length != 0) {
        NSLog(@"%@",error);
    }
    if (opCallback != nil) opCallback(error.length == 0 ? YES : NO,error);
    return error;
}

- (void)bindParameterValues:(NSArray*)values forStatement:(sqlite3_stmt*)statement{
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

- (id)columnValue:(int)columnIndex forStatement:(sqlite3_stmt*)statement{
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

- (void)addRowToResultsArrayWithStatement:(sqlite3_stmt*)statement withResultsArray:(NSMutableArray*)resultsArray{
    // Initialize the mutable dictionary that will contain the data of a fetched row.
     NSMutableDictionary *dicDataRow = [[NSMutableDictionary alloc] init];
    
    // Get the total number of columns.
    int totalColumns = sqlite3_column_count(statement);
    
    // Go through all columns and fetch each column data.
    for (int i=0; i<totalColumns; i++){
        NSString * columnName = [NSString stringWithUTF8String:sqlite3_column_name(statement, i)];
        [dicDataRow setObject:[self columnValue:i forStatement:statement] forKey:columnName];
    }
    
    // Store each fetched data row in the results array, but first check if there is actually data.
    if (dicDataRow.count > 0) {
        [resultsArray addObject:dicDataRow];
        //NSLog(@"Added to result array %lu",(unsigned long)resultsArray.count);
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
    NSMutableArray *resultsArray = [[NSMutableArray alloc] init];
    NSString *query = [NSString stringWithFormat:@"pragma table_info (%@)",Table];
    [self runQuery:query withParamValues:nil withResultsArray:resultsArray withOperationResult:nil];
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
    NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ TEXT",table,columnName];
    if ([defaultValue isKindOfClass:[NSString class]] || [defaultValue isKindOfClass:[NSNumber class]]) {
        [self runQuery:query withParamValues:nil withResultsArray:nil withOperationResult:nil];
        return;
    }
    NSLog(@"addColumn on BWDB does not support the class : %@",NSStringFromClass([defaultValue class]));
}

-(void)DisplayinLogContentofTable:(NSString*)tableName{
    NSLog(@"All Values For Table %@",tableName);
    NSMutableArray *resultsArray = [[NSMutableArray alloc] init];
    NSString *query = [NSString stringWithFormat:@"select * from %@", tableName];
    [self runQuery:query withParamValues:nil withResultsArray:resultsArray withOperationResult:nil];
    for (NSDictionary *row in resultsArray) {
        NSLog(@"%@",row);
    }
}

- (void) insertRow:(NSDictionary *)record forTable:(NSString*)tableName withOperationResult:(operationResult)opCallback{
    
    record = [self checkForNulls:record];
    
    // construct the query
    NSMutableArray * placeHoldersArray = [NSMutableArray arrayWithCapacity:record.count];
    for (int i = 0; i < record.count; i++)  // array of ? markers for placeholders in query
        [placeHoldersArray addObject:@"?"];
    
    NSString *query = [NSString stringWithFormat:@"insert into %@ (%@) values (%@)",
                            tableName,
                            [[record allKeys] componentsJoinedByString:@","],
                            [placeHoldersArray componentsJoinedByString:@","]];
    
    [self runQuery:query withParamValues:[record allValues] withResultsArray:nil withOperationResult:opCallback];
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

- (void) updateRow:(NSDictionary *)record forTable:(NSString*)tableName rowID:(NSString*)rowID withOperationResult:(operationResult)opCallback{
    
    record = [self checkForNulls:record];
    
    NSString *query = [NSString stringWithFormat:@"update %@ set %@ = ? where id = ?",
                            tableName,
                            [[record allKeys] componentsJoinedByString:@" = ?, "]];
    
    NSMutableArray *params = [NSMutableArray arrayWithArray:[record allValues]];
    [params addObject:rowID];
    
    [self runQuery:query withParamValues:params withResultsArray:nil withOperationResult:opCallback];
}

- (void) insertIfNotUpdateRow:(NSDictionary *)record forTable:(NSString*)tableName withOperationResult:(operationResult)opCallback{
    
    record = [self checkForNulls:record];
    
    // construct the query
    NSMutableArray * placeHoldersArray = [NSMutableArray arrayWithCapacity:record.count];
    NSMutableArray * updateSetArray = [NSMutableArray arrayWithCapacity:record.count];
    for (int i = 0; i < record.count; i++) {
        // array of ? markers for placeholders in query
        [placeHoldersArray addObject:@"?"];
        
        NSString* columnName = record.allKeys[i];
        if (![columnName isEqualToString:@"BWRowId"] && ![columnName isEqualToString:@"Id"]) {
            [updateSetArray addObject:[NSString stringWithFormat:@"%@=excluded.%@",columnName,columnName]];
        }
    }
    
    NSString *query = [NSString stringWithFormat:@"insert into %@ (%@) values (%@) ON CONFLICT(Id) DO UPDATE SET %@",
                            tableName,
                            [[record allKeys] componentsJoinedByString:@","],
                            [placeHoldersArray componentsJoinedByString:@","],
                            [updateSetArray componentsJoinedByString:@","]];
    
    [self runQuery:query withParamValues:[record allValues] withResultsArray:nil withOperationResult:opCallback];
}

- (NSDictionary *)getRow:(NSString*)rowID forTable:(NSString*)tableName {
    NSMutableArray *resultsArray = [[NSMutableArray alloc] init];
    NSString *query = [NSString stringWithFormat:@"select * from %@ where id = ?", tableName];
    [self runQuery:query withParamValues:@[rowID] withResultsArray:resultsArray withOperationResult:nil];
    NSDictionary *resultDictionary = [resultsArray lastObject];
    return resultDictionary;
}

- (NSInteger)getRowsCountForTable:(NSString*)tableName{
    NSString *query = [NSString stringWithFormat:@"select count(*) from %@", tableName];
    
    NSInteger rows = 0;
    // Load all data from database to memory.
    sqlite3_stmt *statement;
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
        if (displayLogs) NSLog(@"%@ Changes to database from query %@",[NSNumber numberWithInt: sqlite3_changes(database)],query);
    } else {
        NSLog(@"doQuery (%@) : sqlite3_finalize failed (%s)", query, sqlite3_errmsg(database));
    }
    
    return rows;
}

#pragma mark - CRUD Methods

- (void)performSqliteOperationWithType:(sqliteOperation)operation forDataModel:(BWDataModel*)dataModel withResult:(operationResult)result{
    switch (operation) {
        case sqliteOperationCreate:
            [self insertRowFromDataModel:dataModel withOperationResult:result];
            break;
        case sqliteOperationDelete:
            [self deleteRowFromDataModel:dataModel withOperationResult:result];
            break;
        case sqliteOperationInsertIfNotUpdate:
            [self insertIfNotUpdateRowFromDataModel:dataModel withOperationResult:result];
            break;
        case sqliteOperationUpdate:
        default:
            [self updateRowFromDataModel:dataModel withOperationResult:result];
            break;
    }
}

- (void)performSqliteOperationWithType:(sqliteOperation)operation forDataModel:(BWDataModel *)dataModel recursive:(BOOL)recursive isRootObject:(BOOL)isRoot withResult:(operationResult)result{
    if (recursive) {
        if (operation == sqliteOperationCreate || operation == sqliteOperationUpdate) {
            operation = sqliteOperationInsertIfNotUpdate;
        }
        if (isRoot) sqlite3_exec(database, "BEGIN TRANSACTION", NULL, NULL, NULL);
        NSDictionary *propsAndTypes = [BWDataModel classPropsFor:[dataModel class]];
        for (NSString* key in propsAndTypes.allKeys) {
            NSString *type = propsAndTypes[key];
            if ([type isEqualToString:@"NSArray"] || [type isEqualToString:@"NSMutableArray"]) {
                NSArray *objects = [dataModel valueForKey:key];
                if (objects != nil && ![objects.class isKindOfClass:[NSNull class]] && objects.count != 0) {
                    if ([objects[0] isKindOfClass:[BWDataModel class]]) {
                        for (BWDataModel *model in objects) {
                            [self performSqliteOperationWithType:operation forDataModel:model recursive:recursive isRootObject:NO withResult:nil];
                        }
                    }
                }
            }
            
            BOOL nestedProp = NO;
            for (NSString* nestedType in [dataModel BWNestedModelsStringNamesOrSufix]) {
                if ([type rangeOfString:nestedType].location != NSNotFound) {
                    nestedProp = YES;
                }
            }
            
            if (nestedProp) {
                BWDataModel *model = [dataModel valueForKey:key];
                if (model != nil && ![model.class isKindOfClass:[NSNull class]] && [model shouldPerformRecursiveOperation:operation onPropType:type] && [model isKindOfClass:[BWDataModel class]]) {
                    [self performSqliteOperationWithType:operation forDataModel:model recursive:recursive isRootObject:NO withResult:nil];
                }
            }
        }
        [self performSqliteOperationWithType:operation forDataModel:dataModel withResult:result];
        if (isRoot) sqlite3_exec(database, "END TRANSACTION", NULL, NULL, NULL);
    }else{
        [self performSqliteOperationWithType:operation forDataModel:dataModel withResult:result];
    }
}

- (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels withResult:(operationResult)result{
    
    NSMutableArray *filteredModels = [[NSMutableArray alloc] init];
    for (int x = 0; x < dataModels.count; x++) {
        if ([self checkClassForBWDataModel:[dataModels[x] class]]) {
            [filteredModels addObject:dataModels[x]];
        }else{
            NSLog(@"Filtered class %@ from transaction because it's not a BWDataModel Subclass", NSStringFromClass([dataModels[x] class]));
        }
    }
    
    sqlite3_exec(database, "BEGIN TRANSACTION", NULL, NULL, NULL);
    for (BWDataModel *model in filteredModels) {
        switch (operation) {
            case sqliteOperationCreate:
                [self insertRowFromDataModel:model withOperationResult:result];
                break;
            case sqliteOperationDelete:
                [self deleteRowFromDataModel:model withOperationResult:result];
                break;
            case sqliteOperationInsertIfNotUpdate:
                [self insertIfNotUpdateRowFromDataModel:model withOperationResult:result];
                break;
            case sqliteOperationUpdate:
            default:
                [self updateRowFromDataModel:model withOperationResult:result];
                break;
        }
    }
    sqlite3_exec(database, "END TRANSACTION", NULL, NULL, NULL);
}

- (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels recursive:(BOOL)recursive withResult:(operationResult)result{
    
    if (recursive) {
        NSMutableArray *filteredModels = [[NSMutableArray alloc] init];
        for (int x = 0; x < dataModels.count; x++) {
            if ([self checkClassForBWDataModel:[dataModels[x] class]]) {
                [filteredModels addObject:dataModels[x]];
            }else{
                NSLog(@"Filtered class %@ from transaction because it's not a BWDataModel Subclass", NSStringFromClass([dataModels[x] class]));
            }
        }
        
        sqlite3_exec(database, "BEGIN TRANSACTION", NULL, NULL, NULL);
        for (BWDataModel *model in filteredModels) {
            [self performSqliteOperationWithType:operation forDataModel:model recursive:true isRootObject:NO withResult:result];
        }
        sqlite3_exec(database, "END TRANSACTION", NULL, NULL, NULL);
    }else{
        [self performTransactionSqliteOperationWithType:operation forDataModels:dataModels withResult:result];
    }
    
}

- (NSDictionary*)getMutateOnlyFieldsDictionaryFromDataModel:(BWDataModel*)dataModel{
    NSMutableDictionary *modelDict = [[NSMutableDictionary alloc] initWithDictionary:[dataModel getParseDictionaryValues]];
    if (dataModel.mutateOnlyFields != nil) {
        NSMutableDictionary *mutableModelDict = [[NSMutableDictionary alloc] init];
        for (NSString *field in dataModel.mutateOnlyFields) {
            if (modelDict[field] != nil) {
                [mutableModelDict setValue:modelDict[field]  forKey:field];
            }
        }
        if (modelDict[@"id"] != nil) {
            [mutableModelDict setValue:modelDict[@"id"]  forKey:@"id"];
        }
        if (modelDict[@"Id"] != nil) {
            [mutableModelDict setValue:modelDict[@"Id"]  forKey:@"Id"];
        }
        modelDict = mutableModelDict;
    }
    dataModel.mutateOnlyFields = nil;
    if (modelDict[@"id"] == nil && modelDict[@"Id"] == nil) {
        if (dataModel.BWRowId == nil) {
            dataModel.BWRowId = [[NSUUID UUID] UUIDString];
        }
        modelDict[@"id"] = dataModel.BWRowId;
    }
    return modelDict;
}

- (void)insertRowFromDataModel:(BWDataModel*)dataModel withOperationResult:(operationResult)opCallback{
    if (!allTablesInitialized) [self createTableWithDataModel:[dataModel class]];
    
    [self insertRow:[self getMutateOnlyFieldsDictionaryFromDataModel:dataModel] forTable:NSStringFromClass([dataModel class]) withOperationResult:opCallback];
}

- (void)updateRowFromDataModel:(BWDataModel*)dataModel withOperationResult:(operationResult)opCallback{
    if (dataModel.BWRowId == nil) {
        NSLog(@"You are trying to update a row that you didnt fetch from sqlite or something went wrong, BWRowId is nil in data model %@",dataModel);
        return;
    }
    [self updateRow:[self getMutateOnlyFieldsDictionaryFromDataModel:dataModel] forTable:NSStringFromClass([dataModel class]) rowID:dataModel.BWRowId withOperationResult:opCallback];
}

- (void)deleteRowFromDataModel:(BWDataModel*)dataModel withOperationResult:(operationResult)opCallback{
    if (dataModel.BWRowId == nil) {
        NSDictionary *classProps = [BWDataModel classPropsFor:[dataModel class]];
        if (classProps[@"id"]) {
            if ([classProps[@"id"] isEqualToString:@"NSString"]) {
                if ([dataModel valueForKey:@"id"] != nil && ![[dataModel valueForKey:@"id"] isKindOfClass:[NSNull class]]) {
                    dataModel.BWRowId = [dataModel valueForKey:@"id"];
                }
            }
        }
        if (classProps[@"Id"]) {
            if ([classProps[@"Id"] isEqualToString:@"NSString"]) {
                if ([dataModel valueForKey:@"Id"] != nil && ![[dataModel valueForKey:@"Id"] isKindOfClass:[NSNull class]]) {
                    dataModel.BWRowId = [dataModel valueForKey:@"Id"];
                }
            }
        }
        if (dataModel.BWRowId == nil) {
            NSString *error = [NSString stringWithFormat:@"You are trying to delete a row that you didnt fetch from sqlite or something went wrong, BWRowId is nil in data model %@",dataModel];
            if (opCallback != nil) opCallback(NO,error);
            NSLog(@"%@",error);
            return;
        }
    }
    NSString *query = [NSString stringWithFormat:@"delete from %@ where id = ?", NSStringFromClass([dataModel class])];
    [self runQuery:query withParamValues:@[dataModel.BWRowId] withResultsArray:nil withOperationResult:opCallback];
}

- (void)insertIfNotUpdateRowFromDataModel:(BWDataModel*)dataModel withOperationResult:(operationResult)opCallback{
    if (!allTablesInitialized) [self createTableWithDataModel:[dataModel class]];
    [self insertIfNotUpdateRow:[self getMutateOnlyFieldsDictionaryFromDataModel:dataModel] forTable:NSStringFromClass([dataModel class]) withOperationResult:opCallback];
}

#pragma mark - Custom Functions

double bw_radians(double degrees)
{
    return degrees * M_PI / 180.0;
}

void bw_sqlite_distance(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    double values[4];
    
    // get the double values for the four arguments
    
    for (int i = 0; i < 4; i++) {
        int dataType = sqlite3_value_numeric_type(argv[i]);
        
        if (dataType == SQLITE_INTEGER || dataType == SQLITE_FLOAT) {
            values[i] = sqlite3_value_double(argv[i]);
        } else {
            sqlite3_result_null(context);
            return;
        }
    }
    
    // let's give those values meaningful variable names
    
    double lat  = bw_radians(values[0]);
    double lng  = bw_radians(values[1]);
    double lat2 = bw_radians(values[2]);
    double lng2 = bw_radians(values[3]);
    
    // calculate the distance
    
    double result = 6371.0 * acos(cos(lat2) * cos(lat) * cos(lng - lng2) + sin(lat2) * sin(lat));
    
    sqlite3_result_double(context, result);
    //NSLog(@"distance function: %f,%f,%f,%f = %f",lat,lng,lat2,lng2, result);
}

void bw_sqlite_acos(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    int dataType = sqlite3_value_numeric_type(argv[0]);
    
    if (dataType == SQLITE_INTEGER || dataType == SQLITE_FLOAT) {
        double value = sqlite3_value_double(argv[0]);
        sqlite3_result_double(context, acos(value));
    } else {
        sqlite3_result_null(context);
    }
}

void bw_sqlite_cos(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    int dataType = sqlite3_value_numeric_type(argv[0]);
    
    if (dataType == SQLITE_INTEGER || dataType == SQLITE_FLOAT) {
        double value = sqlite3_value_double(argv[0]);
        sqlite3_result_double(context, cos(value));
    } else {
        sqlite3_result_null(context);
    }
}

void bw_sqlite_sin(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    int dataType = sqlite3_value_numeric_type(argv[0]);
    
    if (dataType == SQLITE_INTEGER || dataType == SQLITE_FLOAT) {
        double value = sqlite3_value_double(argv[0]);
        sqlite3_result_double(context, sin(value));
    } else {
        sqlite3_result_null(context);
    }
}
//
void bw_sqlite_radians(sqlite3_context *context, int argc, sqlite3_value **argv)
{
    int dataType = sqlite3_value_numeric_type(argv[0]);
    
    if (dataType == SQLITE_INTEGER || dataType == SQLITE_FLOAT) {
        double value = sqlite3_value_double(argv[0]);
        sqlite3_result_double(context, bw_radians(value));
    } else {
        sqlite3_result_null(context);
    }
}

- (BOOL)createFunctions:(sqlite3 *)db
{
    int rc;
    
    if ((rc = sqlite3_create_function(db, "acos", 1, SQLITE_ANY, NULL, bw_sqlite_acos, NULL, NULL)) != SQLITE_OK) {
        NSLog(@"%s: sqlite3_create_function acos error: %s (%d)", __FUNCTION__, sqlite3_errmsg(db), rc);
    }
    if ((rc = sqlite3_create_function(db, "sin", 1, SQLITE_ANY, NULL, bw_sqlite_sin, NULL, NULL)) != SQLITE_OK) {
        NSLog(@"%s: sqlite3_create_function sin error: %s (%d)", __FUNCTION__, sqlite3_errmsg(db), rc);
    }
    if ((rc = sqlite3_create_function(db, "cos", 1, SQLITE_ANY, NULL, bw_sqlite_cos, NULL, NULL)) != SQLITE_OK) {
        NSLog(@"%s: sqlite3_create_function cos error: %s (%d)", __FUNCTION__, sqlite3_errmsg(db), rc);
    }
    if ((rc = sqlite3_create_function(db, "radians", 1, SQLITE_ANY, NULL, bw_sqlite_radians, NULL, NULL)) != SQLITE_OK) {
        NSLog(@"%s: sqlite3_create_function radians error: %s (%d)", __FUNCTION__, sqlite3_errmsg(db), rc);
    }
    if ((rc = sqlite3_create_function(db, "distance", 4, SQLITE_ANY, NULL, bw_sqlite_distance, NULL, NULL)) != SQLITE_OK) {
        NSLog(@"%s: sqlite3_create_function distance error: %s (%d)", __FUNCTION__, sqlite3_errmsg(db), rc);
    }
    // repeat this for all of the other functions you define
    
    return rc;
}

@end
