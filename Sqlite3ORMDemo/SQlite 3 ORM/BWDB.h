
#import <Foundation/Foundation.h>
#import <sqlite3.h>

//This Class handle all the sqlite database methods


static NSString * const kBWDBVersion = @"1.0.6";

@interface BWDB : NSObject <NSFastEnumeration> {
    sqlite3 *database;
    sqlite3_stmt *statement;
    NSString *tableName;
    NSString *databaseFileName;
    NSFileManager *filemanager;
    
    // for "fast enumeration" (iterator/generator pattern)
    NSDictionary * enumRows[1]; // enumerated (iterator) object(s) are passed in a C array
                                // we only ever pass one at a time
}

@property (nonatomic, retain) NSString *tableName;

// object management
- (BWDB *) initWithDBFilename: (NSString *) fn;
- (BWDB *) initWithDBFilename: (NSString *) fn andTableName: (NSString *) tn;
- (void) openDB;
- (void) closeDB;
- (NSString *) getVersion;
- (NSString *) getDBPath;

// SQL queries
- (NSNumber *) doQuery:(NSString *) query, ...;
- (BWDB *) getQuery:(NSString *) query, ...;
- (void) prepareQuery:(NSString *) query, ...;
- (id) valueFromQuery:(NSString *) query, ...;

// CRUD methods
- (NSMutableArray *) getRowsFromQuery: (NSString *)query;
- (NSNumber *) insertRow:(NSDictionary *) record;
- (void) updateRow:(NSDictionary *)record rowID:(NSNumber *)rowID;
- (void) deleteRow:(NSNumber *) rowID;
- (NSDictionary *) getRow: (NSNumber *) rowID;
- (NSMutableArray *) getRowsFromColumnName: (NSString *) ColumnName andValue:(NSString*)Value;
- (NSMutableArray *) getAllRowsFromTable;
- (NSNumber *) countRows;
- (BOOL)checkIfTableExists:(NSString*)Table;
- (BOOL)checkIfColumnExists:(NSString*)column InTable:(NSString*)Table;
- (void)addColumn:(NSString*)columnName andDefaultValue:(id)defaultValue inTable:(NSString*)table;

// Raw results
- (void) bindSQL:(const char *) cQuery arguments:(va_list)args;
- (NSDictionary *) getPreparedRow;
- (id) getPreparedValue;

// Utilities
- (id) columnValue:(int) columnIndex;
- (NSNumber *) lastInsertId;
-(void)DisplayinLogContentofTable:(NSString*)TableName;

@end
