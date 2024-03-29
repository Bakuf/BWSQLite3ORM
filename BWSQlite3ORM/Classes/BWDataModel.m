//
//  BWDataModel.m
//  
//
//  Created by Bakuf on 7/3/14.
//  Copyright (c) 2014 Rodrigo Galvez. All rights reserved.
//

#import "BWDataModel.h"
#import <objc/runtime.h>
#import "BWDataBaseManager.h"

#define sqliteContextObserver @"BWDataModel-PropChangeObserver"

#define databaseLockQueries @"BWDatabase-Lock-Queries"
#define databaseLockOp @"BWDatabase-Lock-Operations"


//TODO CHANGE QUEUES TO BE DEFINED BY USERS
//#define defaultQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul)
//#define backgroundQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0ul)
//#define BWQueue dispatch_queue_create_with_target("bw.sqlite3.ORM", DISPATCH_QUEUE_CONCURRENT,backgroundQueue)
//#define BWQueueQuery dispatch_queue_create_with_target("bw.sqlite3.ORM.Queries", DISPATCH_QUEUE_SERIAL,defaultQueue)
//#define BWQueueOp dispatch_queue_create_with_target("bw.sqlite3.ORM.Operation", DISPATCH_QUEUE_CONCURRENT,defaultQueue)

@interface BWDataModel (){
    NSDictionary* parsedDict;
}

@end

@implementation BWDataModel

static const char *getPropertyType(objc_property_t property) {
    const char *attributes = property_getAttributes(property);
    //printf("attributes=%s\n", attributes);
    char buffer[1 + strlen(attributes)];
    strcpy(buffer, attributes);
    char *state = buffer, *attribute;
    while ((attribute = strsep(&state, ",")) != NULL) {
        if (attribute[0] == 'T' && attribute[1] != '@') {
            // it's a C primitive type:
            /*
             if you want a list of what will be returned for these primitives, search online for
             "objective-c" "Property Attribute Description Examples"
             apple docs list plenty of examples of what you get for int "i", long "l", unsigned "I", struct, etc.
             */
            NSString *name = [[NSString alloc] initWithBytes:attribute + 1 length:strlen(attribute) - 1 encoding:NSASCIIStringEncoding];
            return (const char *)[name cStringUsingEncoding:NSASCIIStringEncoding];
        }
        else if (attribute[0] == 'T' && attribute[1] == '@' && strlen(attribute) == 2) {
            // it's an ObjC id type:
            return "id";
        }
        else if (attribute[0] == 'T' && attribute[1] == '@') {
            // it's another ObjC object type:
            NSString *name = [[NSString alloc] initWithBytes:attribute + 3 length:strlen(attribute) - 4 encoding:NSASCIIStringEncoding];
            return (const char *)[name cStringUsingEncoding:NSASCIIStringEncoding];
        }
    }
    return "";
}


+ (NSDictionary *)classPropsFor:(Class)klass
{
    if (klass == NULL) {
        return nil;
    }
    
    NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
    
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(klass, &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if(propName) {
            const char *propType = getPropertyType(property);
            if (propType) {
                NSString *propertyName = [NSString stringWithUTF8String:propName];
                NSString *propertyType = [NSString stringWithUTF8String:propType];
                if (!([propertyName isEqualToString:@"description"] || [propertyName isEqualToString:@"debugDescription"])) {
                    [results setObject:propertyType forKey:propertyName];
                }
            }
        }
    }
    free(properties);
    
    // returning a copy here to make sure the dictionary is immutable
    return [NSDictionary dictionaryWithDictionary:results];
}

+ (NSString*)allPropertiesSeparatedByComa{
    NSDictionary *propsAndTypes = [BWDataModel classPropsFor:[self class]];
    NSString* allProperties = @"";
    for (NSString* key in propsAndTypes.allKeys) {
        if (![key isEqualToString:@"Id"]) {
            allProperties = [allProperties stringByAppendingString:[NSString stringWithFormat:@", %@",key]];
        }
    }
    return allProperties;
}

+ (NSDictionary*)getDefaultDictionaryValues{
    NSDictionary *propsAndTypes = [BWDataModel classPropsFor:[self class]];
    NSMutableDictionary *defaultDictionary = [[NSMutableDictionary alloc] init];
    for (NSString* key in propsAndTypes.allKeys) {
        id value = @"unsupported format";
        NSString *type = propsAndTypes[key];
        
        if ([type isEqualToString:@"NSString"]) {
            value = @"";
        }
        
        if ([type isEqualToString:@"NSDate"]) {
            value = @0.0;
        }
        
        if ([type isEqualToString:@"NSArray"] || [type isEqualToString:@"NSMutableArray"] || [type isEqualToString:@"NSDictionary"] || [type isEqualToString:@"NSMutableDictionary"]) {
            //since we store these on json serialized strings it has to be a deafult string
            value = @"";
        }
        
        if ([type isEqualToString:@"i"]) {
            value = @0;
        }
        
        if ([type isEqualToString:@"d"] || [type isEqualToString:@"f"]) {
            value = @"";
        }
        
        if ([type isEqualToString:@"c"]) {
            value = @0;
        }
        
        [defaultDictionary setValue:value forKey:key];
    }
    return defaultDictionary;
}

- (NSDictionary*)getParseDictionaryValues{
    NSDictionary *propsAndTypes = [BWDataModel classPropsFor:[self class]];
    NSMutableDictionary *defaultDictionary = [[NSMutableDictionary alloc] init];
    for (NSString* key in propsAndTypes.allKeys) {
        id value = [self getSQLFormatedValueForKey:key withType:propsAndTypes[key]];
        if ([value isKindOfClass:[NSString class]]) {
            NSString *stringValue = value;
            if ([key isEqualToString:@"Id"]) {
                if (![stringValue isKindOfClass:[NSNull class]] && stringValue != nil) {
                    self.BWRowId = stringValue;
                }
            }
            if (![stringValue isEqualToString:@"Unsupported Format"]) {
                [defaultDictionary setValue:value forKey:key];
            }
        }else{
            [defaultDictionary setValue:value forKey:key];
        }
    }
    return defaultDictionary;
}

- (instancetype)setBasicDataModelValuesFromDictionary:(NSDictionary*)dict{
    parsedDict = dict;
    if (dict[@"id"]) {
        self.BWRowId = dict[@"id"];
        NSMutableDictionary *mutDict = [[NSMutableDictionary alloc] initWithDictionary:dict];
        mutDict[@"Id"] = dict[@"id"];
        dict = mutDict;
    }
    
    NSDictionary *propsAndTypes = [BWDataModel classPropsFor:[self class]];
    for (NSString* key in dict.allKeys) {
        NSString *type = propsAndTypes[key];
        if ([type isEqualToString:@"NSString"]) {
            id object = dict[key];
            if ([object isKindOfClass:[NSNull class]]) {
                object = @"";
            }
            [self setValue:object forKey:key];
        }
        
        if ([type isEqualToString:@"NSDate"]) {
            NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:[dict[key] doubleValue]];
            [self setValue:date forKey:key];
        }
        
        if ([type isEqualToString:@"NSArray"] || [type isEqualToString:@"NSMutableArray"] || [type isEqualToString:@"NSDictionary"] || [type isEqualToString:@"NSMutableDictionary"]) {
//            [self setValue:[self getObjectFromJSON:dict[key]] forKey:key];
        }
        
        if ([type isEqualToString:@"i"] || [type isEqualToString:@"l"] || [type isEqualToString:@"q"]) {
            if ([dict[key] respondsToSelector:@selector(intValue)] && ![dict[key] isKindOfClass:[NSNull class]]){
                [self setValue:[NSNumber numberWithLongLong:[dict[key] longLongValue]] forKey:key];
            }
        }
        
        if ([type isEqualToString:@"d"] || [type isEqualToString:@"f"]) {
            if (dict[key] != nil && ![dict[key] isKindOfClass:[NSNull class]]) {
                [self setValue:[NSNumber numberWithDouble:[dict[key] doubleValue]] forKey:key];
            }
        }
        
        if ([type isEqualToString:@"c"] || [type isEqualToString:@"B"]) {
            if (dict[key] != nil && ![dict[key] isKindOfClass:[NSNull class]]) {
                [self setValue:dict[key] forKey:key];
            }
        }
        
    }
    
    return self;
}

- (instancetype)setDataModelValuesFromDictionary:(NSDictionary*)dict{
    parsedDict = dict;
    if (dict[@"id"]) {
        self.BWRowId = dict[@"id"];
        NSMutableDictionary *mutDict = [[NSMutableDictionary alloc] initWithDictionary:dict];
        mutDict[@"Id"] = dict[@"id"];
        dict = mutDict;
    }
    
    NSDictionary *propsAndTypes = [BWDataModel classPropsFor:[self class]];
    for (NSString* key in dict.allKeys) {
        NSString *type = propsAndTypes[key];
        if ([type isEqualToString:@"NSString"]) {
            if (dict[key]) {
                id object = dict[key];
                if ([object isKindOfClass:[NSNull class]] || object == nil) {
                    object = @"";
                }
                [self setValue:object forKey:key];
            }
        }
        
        if ([type isEqualToString:@"NSDate"]) {
            NSDate *date = [[NSDate alloc] initWithTimeIntervalSince1970:[dict[key] doubleValue]];
            [self setValue:date forKey:key];
        }
        
        if ([type isEqualToString:@"NSArray"] || [type isEqualToString:@"NSMutableArray"] || [type isEqualToString:@"NSDictionary"] || [type isEqualToString:@"NSMutableDictionary"]) {
            NSLog(@"%@",dict[key]);
            if ([dict[key] isKindOfClass:[NSString class]]) {
                NSString *string = (NSString*)dict[key];
                if (string.length > 0) {
                    [self setValue:[self getObjectFromJSON:dict[key]] forKey:key];
                }
            }
        }
        
        if ([type isEqualToString:@"i"] || [type isEqualToString:@"l"] || [type isEqualToString:@"q"]) {
            if ([dict[key] respondsToSelector:@selector(intValue)] && ![dict[key] isKindOfClass:[NSNull class]]){
                [self setValue:[NSNumber numberWithLongLong:[dict[key] longLongValue]] forKey:key];
            }
        }
        
        if ([type isEqualToString:@"d"] || [type isEqualToString:@"f"]) {
            if (dict[key] != nil && ![dict[key] isKindOfClass:[NSNull class]]) {
                [self setValue:[NSNumber numberWithDouble:[dict[key] doubleValue]] forKey:key];
            }
        }
        
        if ([type isEqualToString:@"c"] || [type isEqualToString:@"B"]) {
            if (dict[key] != nil && ![dict[key] isKindOfClass:[NSNull class]]) {
                [self setValue:dict[key] forKey:key];
            }
        }
        
        BOOL nestedProp = NO;
        for (NSString* nestedType in [self BWNestedModelsStringNamesOrSufix]) {
            if ([type rangeOfString:nestedType].location != NSNotFound) {
                nestedProp = YES;
            }
        }
        if (nestedProp) {
            NSString *connectionProp = [self getConnectionPropIfExistFor:key with:propsAndTypes];
            if (connectionProp != nil) {
                Class bwClass = NSClassFromString(type);
                NSString *keyValue = dict[connectionProp];
                if (keyValue != nil && ![keyValue isKindOfClass:[NSNull class]] && ![keyValue isEqualToString:@""]) {
                    NSString *queryString = [NSString stringWithFormat:@"where Id = '%@'",keyValue];
                    [[BWDataBaseManager sharedInstance] getRowsFromQuery:queryString forDataModel:bwClass WithResult:^(BOOL success, NSString *error, NSMutableArray *results) {
                        if (success && results.count != 0) {
                            [self setValue:results[0] forKey:key];
                        }else{
                            //NSLog(@"No luck for prop %@ with query %@",key,queryString);
                        }
                    }];
                }
            }
        }
    }
    
    NSDictionary *customProps = [self BWCustomParsingPropertiesInfo];
    for (NSString *key in customProps.allKeys) {
        if (propsAndTypes[key] != nil) {
            NSString *type = propsAndTypes[key];
            NSDictionary *info = customProps[key];
            if (([type isEqualToString:@"NSArray"] || [type isEqualToString:@"NSMutableArray"]) && info != nil) {
                NSString *className = info[BWCustomPropInfoClass];
                NSString *classProp = info[BWCustomPropInfoName];
                NSString *classId = info[BWCustomPropInfoId];
                NSString *customQuery = info[BWCustomPropInfoQuery];
                if (customQuery != nil) {
                    if (className != nil) {
                        Class bwClass = NSClassFromString(className);
                        [[BWDataBaseManager sharedInstance] getRowsFromQuery:customQuery forDataModel:bwClass WithResult:^(BOOL success, NSString *error, NSMutableArray *results) {
                            if (success && results.count != 0) {
                                [self setValue:results forKey:key];
                            }else{
                                //NSLog(@"No luck for prop %@ with query %@",key,queryString);
                            }
                        }];
                    }
                }else{
                    if (className != nil && classProp != nil && classId != nil) {
                        Class bwClass = NSClassFromString(className);
                        NSString *queryString = [NSString stringWithFormat:@"where %@ = '%@'",classProp,classId];
                        [[BWDataBaseManager sharedInstance] getRowsFromQuery:queryString forDataModel:bwClass WithResult:^(BOOL success, NSString *error, NSMutableArray *results) {
                            if (success && results.count != 0) {
                                [self setValue:results forKey:key];
                            }else{
                                //NSLog(@"No luck for prop %@ with query %@",key,queryString);
                            }
                        }];
                    }
                }
            }
        }
    }
    
    self.createdFromSQLite = YES;
    self.wasModifiedAfterFetch = NO;
    [self modelValuesWereSetFromSQLite:dict];
    [self subscribeToMyChanges];
    
    return self;
}

- (NSString*)getConnectionPropIfExistFor:(NSString*)property with:(NSDictionary*)propsAndTypes{
    for (NSString *prop in propsAndTypes.allKeys) {
        NSString *selfClassName = NSStringFromClass([self class]);
        NSRange classNameRange = [prop rangeOfString:selfClassName options:NSCaseInsensitiveSearch];
        if ( classNameRange.location != NSNotFound) {
            NSString *result = [prop stringByReplacingCharactersInRange:classNameRange withString:@""];
            NSRange idRange = [result rangeOfString:@"Id" options:NSCaseInsensitiveSearch];
            if (idRange.location != NSNotFound) {
                //we got a connection property
                result = [result stringByReplacingCharactersInRange:idRange withString:@""];
                if ([result rangeOfString:property options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    return prop;
                }
            }
        }
    }
    NSString *propId = [NSString stringWithFormat:@"%@Id",property];
    if (propsAndTypes[propId]) {
        return propId;
    }
    return nil;
}

+ (NSArray*)parseResultsArray:(NSArray*)resultsArray{
    NSMutableArray *parsedArray = [[NSMutableArray alloc] init];
    for (NSDictionary *tmpDict in resultsArray) {
        BWDataModel *model =(BWDataModel*)[[[self class] alloc] init];
        [parsedArray addObject:[model setDataModelValuesFromDictionary:tmpDict]];
    }
    return parsedArray;
}

- (id)getSQLFormatedValueForKey:(NSString*)key withType:(NSString*)type{
    if ([type isEqualToString:@"NSString"]) {
        return [self valueForKey:key];
    }
    
    if ([type isEqualToString:@"NSDate"]) {
        NSDate *tmpDate = [self valueForKey:key];
        if ([[self class] saveDateWithOutTime]){
            tmpDate = [[self class] dateWithOutTime:tmpDate];
        }
        return [NSNumber numberWithDouble:[tmpDate timeIntervalSince1970]];
    }
    
    if ([type isEqualToString:@"NSArray"] || [type isEqualToString:@"NSMutableArray"] || [type isEqualToString:@"NSDictionary"] || [type isEqualToString:@"NSMutableDictionary"]) {
        id value = [self valueForKey:key];
        BOOL canSerialize = [self canSerialize:value];
        if (canSerialize) {
            return [self serializeArrayOrDictionary:value];
        }else{
            return value = @"";
        }
    }
    
    if ([type isEqualToString:@"i"] || [type isEqualToString:@"l"] || [type isEqualToString:@"q"]) {
        return [NSString stringWithFormat:@"%lld",[[self valueForKey:key] longLongValue]];
    }
    
    if ([type isEqualToString:@"d"] || [type isEqualToString:@"f"]) {
        return [NSString stringWithFormat:@"%f",[[self valueForKey:key] doubleValue]];
    }
    
    if ([type isEqualToString:@"c"] || [type isEqualToString:@"B"]) {
        return [NSNumber numberWithInt:(int)[[self valueForKey:key] integerValue]];
    }
    
    return @"Unsupported Format";
    
}

- (BOOL)canSerialize:(id)object{
    BOOL can = NO;
    //If array
    if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = (NSArray*)object;
        if (array.count != 0) {
            can = ![array[0] isKindOfClass:[BWDataModel class]];
        }
    }else if ([object isKindOfClass:[NSMutableArray class]]){
        NSMutableArray *array = (NSMutableArray*)object;
        if (array.count != 0) {
            can = ![array[0] isKindOfClass:[BWDataModel class]];
        }
    }
    
    //If dictionary
    if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary*)object;
        if (dict.allKeys.count != 0) {
            can = ![dict[dict.allKeys[0]] isKindOfClass:[BWDataModel class]];
        }
    }else if ([object isKindOfClass:[NSMutableDictionary class]]){
        NSMutableDictionary *dict = (NSMutableDictionary*)object;
        if (dict.allKeys.count != 0) {
            can = ![dict[dict.allKeys[0]] isKindOfClass:[BWDataModel class]];
        }
    }
    return can;
}

- (NSString *)description{
    NSDictionary *propsAndTypes = [BWDataModel classPropsFor:[self class]];
    NSString *description = @"";
    for (NSString* key in propsAndTypes.allKeys) {
        description = [description stringByAppendingString:[NSString stringWithFormat:@"%@ : %@\n",key,[self valueForKey:key]]];
    }
    
    return [NSString stringWithFormat:@"\n********%@********\n%@**********************\n"
            ,NSStringFromClass([self class])
            ,description];
}

#pragma mark Observer Methods

- (void)subscribeToMyChanges{
    NSDictionary *propInfo = [self BWCustomParsingPropertiesInfo];
    for (NSString* key in propInfo.allKeys) {
        [self addObserver:self forKeyPath:key options:NSKeyValueObservingOptionNew context:sqliteContextObserver];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self && context == sqliteContextObserver ) {
        self.wasModifiedAfterFetch = YES;
    }
}

#pragma mark Settings Methods

+ (BOOL)absoluteRow{
    return NO;
}

+ (void (^)(bool))initBlockCompletition{
    return nil;
}

+ (BOOL)saveDateWithOutTime{
    return NO;
}

+ (BOOL)MonthlyTable{
    return NO;
}

- (NSDictionary*)BWCustomParsingPropertiesInfo{
    return @{};
}

- (NSArray*)BWNestedModelsStringNamesOrSufix{
    return @[@"BW"];
}

- (BOOL)shouldPerformRecursiveOperation:(sqliteOperation)operation onPropType:(NSString*)type{
    return YES;
}

- (void)modelValuesWereSetFromSQLite:(NSDictionary*)dict{
    
}

#pragma mark NSDate Helpers

+ (NSDate *)dateWithOutTime:(NSDate *)datDate {
    if( datDate == nil ) {
        datDate = [NSDate date];
    }
    NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:datDate];
    return [[NSCalendar currentCalendar] dateFromComponents:comps];
}

+ (NSString *)dateStringFromDate:(NSDate *)datDate {
    if( datDate == nil ) {
        datDate = [NSDate date];
    }
    NSDateComponents* comps = [[NSCalendar currentCalendar] components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:datDate];
    return [NSString stringWithFormat:@"%i/%i/%i",(int)comps.day,(int)comps.month,(int)comps.year];
}

#pragma mark Array and Dictionary Parse Helpers

- (NSString*)serializeArrayOrDictionary:(id)info{
    NSError *parsingError = nil;
    NSData *serializedData = Nil;
    
    serializedData = [NSJSONSerialization dataWithJSONObject:info options:NSJSONWritingPrettyPrinted error:&parsingError];
    
    NSString *stringData = [[NSString alloc] initWithData:serializedData encoding:NSUTF8StringEncoding];
    
    return stringData;
}

- (id)getObjectFromJSON:(NSString*)json{
    NSError *parsingError = nil;
    return [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                           options:NSJSONReadingAllowFragments
                                             error:&parsingError];
}

#pragma mark NSCoding Methods

- (void) encodeWithCoder:(NSCoder *)encoder {
    NSDictionary *propsAndTypes = [BWDataModel classPropsFor:[self class]];
    for (NSString* key in propsAndTypes.allKeys) {
        [encoder encodeObject:[self getSQLFormatedValueForKey:key withType:propsAndTypes[key]] forKey:key];
    }
}

- (id)initWithCoder:(NSCoder *)decoder {
    NSDictionary *propsAndTypes = [BWDataModel classPropsFor:[self class]];
    NSMutableDictionary *decodedValues = [[NSMutableDictionary alloc] init];
    for (NSString* key in propsAndTypes.allKeys) {
        [decodedValues setValue:[decoder decodeObjectForKey:key] forKey:key];
    }
    return [self setDataModelValuesFromDictionary:decodedValues];
}

#pragma CRUD Methods

+ (void)uniqueRowWithResult:(queryResult)result{
    [[BWDataBaseManager sharedInstance] getLastInsertedRowForDataModel:[self class]];
}

+ (void)getAllRowsWithResult:(queryResult)result{
    [BWDataModel runInReadBWThread:^{
        [[BWDataBaseManager sharedInstance] getAllRowsForDataModel:[self class] WithResult:[BWDataModel encapsulateQuery:result]];
    }];
}

+ (void)getAllRowsWithResult:(queryResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType{
    [BWDataModel runInBWCustomQueue:identifier withSyncType:syncType completion:^{
        [[BWDataBaseManager sharedInstance] getAllRowsForDataModel:[self class] WithResult:[BWDataModel encapsulateQuery:result]];
    }];
}

+ (void)getAllRowsOrderedBy:(NSString*)orderedBy withResult:(queryResult)result{
    [BWDataModel runInReadBWThread:^{
        [[BWDataBaseManager sharedInstance] getAllRowsForDataModel:[self class] orderedBy:orderedBy WithResult:[BWDataModel encapsulateQuery:result]];
    }];
}

+ (void)getAllRowsOrderedBy:(NSString*)orderedBy withResult:(queryResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType{
    [BWDataModel runInBWCustomQueue:identifier withSyncType:syncType completion:^{
        [[BWDataBaseManager sharedInstance] getAllRowsForDataModel:[self class] orderedBy:orderedBy WithResult:[BWDataModel encapsulateQuery:result]];
    }];
}

+ (void)makeSelectQuery:(NSString*)query withResult:(queryResult)result{
    [BWDataModel runInReadBWThread:^{
        [[BWDataBaseManager sharedInstance] getRowsFromQuery:query forDataModel:[self class] WithResult:[BWDataModel encapsulateQuery:result]];
    }];
}

+ (void)makeSelectQuery:(NSString*)query withResult:(queryResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType{
    [BWDataModel runInBWCustomQueue:identifier withSyncType:syncType completion:^{
        [[BWDataBaseManager sharedInstance] getRowsFromQuery:query forDataModel:[self class] WithResult:[BWDataModel encapsulateQuery:result]];
    }];
}

+ (void)rawQuery:(NSString*)query withResult:(queryResult)result{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] getRawDataFromQuery:query makeFromClass:[self class] withResult:[BWDataModel encapsulateQuery:result]];
    }];
}

+ (void)rawQuery:(NSString*)query withResult:(queryResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType{
    [BWDataModel runInBWCustomQueue:identifier withSyncType:syncType completion:^{
        [[BWDataBaseManager sharedInstance] getRawDataFromQuery:query makeFromClass:[self class] withResult:[BWDataModel encapsulateQuery:result]];
    }];
}

- (void)swapOrderWithDataModel:(BWDataModel*)otherDataModel{
    if ([self class] != [otherDataModel class]) {
        NSLog(@"To make a swap both datamodels have to be of the same class!");
        return;
    }
    
    NSString *swapId = otherDataModel.BWRowId;
    otherDataModel.BWRowId = self.BWRowId;
    self.BWRowId = swapId;
    
    [self updateRow];
    [otherDataModel updateRow];
}

+ (void)runInWriteBWThread:(void(^)(void))block{
    [BWDataModel runInBWCustomQueue:BWOperationsIdentifier withSyncType:BWSyncTypeAsync completion:block];
}

+ (void)runInReadBWThread:(void(^)(void))block{
    [BWDataModel runInBWCustomQueue:BWQueriesIdentifier withSyncType:BWSyncTypeAsync completion:block];
}

+ (void)runInBWCustomQueue:(NSString*)identifier withSyncType:(BWSyncType)type completion:(void(^)(void))block{
    
    if (type == BWSyncTypeMainSync || type == BWSyncTypeMainAsync) {
        //Main thread
        if ([NSThread isMainThread]) {
            block();
        } else {
            if (type == BWSyncTypeMainSync) {
                dispatch_sync(dispatch_get_main_queue(), block);
            }else{
                dispatch_async(dispatch_get_main_queue(), block);
            }
        }
        return;
    }
    
    //Background thread
    dispatch_queue_t customQueue = [[BWDataBaseManager sharedInstance] getQueueWithIdentifier:identifier];
    if (customQueue == nil) {
        NSLog(@"BWDataModel - runInBWThreadOnCustomQueue : Could not find queue with name %@, will use defatul queue\nTo use custom queue you need to register them first with the method [[BWDataBaseManager SharedInstance] registerCustomQueueWithQualityOfService:(BWQueueQOS)qos andType:(BWQueueType)type withIdentifier:(NSString* _Nonnull)idetifier]",identifier);
        customQueue = [[BWDataBaseManager sharedInstance] getQueueWithIdentifier:BWOperationsIdentifier];
    }
    
    
    if (type == BWSyncTypeSync) {
        dispatch_sync(customQueue, ^{
            block();
        });
    }else{
        dispatch_async(customQueue, ^{
            block();
        });
    }
}

+ (NSString *)getPrettyCurrentThreadDescription {
    NSString *raw = [NSString stringWithFormat:@"%@", [NSThread currentThread]];

    NSArray *firstSplit = [raw componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"{"]];
    if ([firstSplit count] > 1) {
        NSArray *secondSplit     = [firstSplit[1] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"}"]];
        if ([secondSplit count] > 0) {
            NSString *numberAndName = secondSplit[0];
            return numberAndName;
        }
    }

    return raw;
}

+ (operationResult)encapsulateOperation:(operationResult)result{
    if (result != nil) {
        return ^(BOOL success, NSString *error){
            if ([NSThread isMainThread]) {
                result(success, error);
            }else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    result (success, error);
                });
            }
        };
    }else{
        return result;
    }
}

+ (queryResult)encapsulateQuery:(queryResult)result{
    if (result) {
        return ^(BOOL success, NSString *error,NSMutableArray *results){
            if ([NSThread isMainThread]) {
                result (success, error, results);
            }else{
                dispatch_async(dispatch_get_main_queue(), ^{
                    result (success, error, results);
                });
            }
        };
    }else{
        return result;
    }
}

- (void)insertRow{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] insertRowFromDataModel:self withOperationResult:nil];
    }];
}

- (void)updateRow{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] updateRowFromDataModel:self withOperationResult:nil];
    }];
}

- (void)deleteRow{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] deleteRowFromDataModel:self withOperationResult:nil];
    }];
}

- (void)insertIfNotUpdateRow{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] insertIfNotUpdateRowFromDataModel:self withOperationResult:nil];
    }];
}

+ (void)deleteTable{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] dropTableForDataModelClass:[self class]];
    }];
}

+ (void)deleteDatabase{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] deleteDataBase];
    }];
}

- (void)performSqliteOperationWithType:(sqliteOperation)operation withResult:(operationResult)result{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] performSqliteOperationWithType:operation forDataModel:self recursive:NO isRootObject:YES withResult:[BWDataModel encapsulateOperation:result]];
    }];
}

- (void)performSqliteOperationWithType:(sqliteOperation)operation recursive:(BOOL)recursive withResult:(operationResult)result{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] performSqliteOperationWithType:operation forDataModel:self recursive:recursive isRootObject:YES withResult:[BWDataModel encapsulateOperation:result]];
    }];
}

- (void)performSqliteOperationWithType:(sqliteOperation)operation recursive:(BOOL)recursive withResult:(operationResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType{
    [BWDataModel runInBWCustomQueue:identifier withSyncType:syncType completion:^{
        [[BWDataBaseManager sharedInstance] performSqliteOperationWithType:operation forDataModel:self recursive:recursive isRootObject:YES withResult:[BWDataModel encapsulateOperation:result]];
    }];
}

//- (void)performSqliteOperationWithType:(sqliteOperation)operation withResult:(operationResult)result recursive:(BOOL)recursive{
//    [BWDataModel runInBWThread:^{
//        [[BWDataBaseManager sharedInstance] performSqliteOperationWithType:operation forDataModel:self withResult:[BWDataModel encapsulateOperation:result]];
//        if (recursive) {
//            
//        }
//    }];
//}

+ (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels withResult:(operationResult)result{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] performTransactionSqliteOperationWithType:operation forDataModels:dataModels recursive:NO withResult:[BWDataModel encapsulateOperation:result]];
    }];
}

+ (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels recursive:(BOOL)recursive withResult:(operationResult)result{
    [BWDataModel runInWriteBWThread:^{
        [[BWDataBaseManager sharedInstance] performTransactionSqliteOperationWithType:operation forDataModels:dataModels recursive:recursive withResult:[BWDataModel encapsulateOperation:result]];
    }];
}

+ (void)performTransactionSqliteOperationWithType:(sqliteOperation)operation forDataModels:(NSMutableArray*)dataModels recursive:(BOOL)recursive withResult:(operationResult)result onCustomQueue:(NSString*)identifier withQueueSyncType:(BWSyncType)syncType{
    [BWDataModel runInBWCustomQueue:identifier withSyncType:syncType completion:^{
        [[BWDataBaseManager sharedInstance] performTransactionSqliteOperationWithType:operation forDataModels:dataModels recursive:recursive    withResult:[BWDataModel encapsulateOperation:result]];
    }];
}

@end
