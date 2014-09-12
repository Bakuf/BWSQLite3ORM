//
//  BWDataModel.m
//  
//
//  Created by Bakuf on 7/3/14.
//  Copyright (c) 2014 Rodrigo Galvez. All rights reserved.
//

#import "BWDataModel.h"
#import "BWDataBaseManager.h"
#import <objc/runtime.h>

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
            NSString *propertyName = [NSString stringWithUTF8String:propName];
            NSString *propertyType = [NSString stringWithUTF8String:propType];
            [results setObject:propertyType forKey:propertyName];
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
         allProperties = [allProperties stringByAppendingString:[NSString stringWithFormat:@", %@",key]];
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
            value = @0.0;
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
        [defaultDictionary setValue:[self getFormatedValueForKey:key withType:propsAndTypes[key]] forKey:key];
    }
    return defaultDictionary;
}

- (instancetype)setDataModelValuesFromDictionary:(NSDictionary*)dict{
    if (dict[@"id"]) {
        self.BWRowId = dict[@"id"];
    }
    
    NSDictionary *propsAndTypes = [BWDataModel classPropsFor:[self class]];
    for (NSString* key in dict.allKeys) {
        NSString *type = propsAndTypes[key];
        if ([type isEqualToString:@"NSString"]) {
            [self setValue:dict[key] forKey:key];
        }
        
        if ([type isEqualToString:@"NSDate"]) {
            NSDate* date = [[NSDate alloc] initWithTimeIntervalSince1970:[dict[key] doubleValue]];
            [self setValue:date forKey:key];
        }
        
        if ([type isEqualToString:@"NSArray"] || [type isEqualToString:@"NSMutableArray"] || [type isEqualToString:@"NSDictionary"] || [type isEqualToString:@"NSMutableDictionary"]) {
            [self setValue:[self getObjectFromJSON:dict[key]] forKey:key];
        }
        
        if ([type isEqualToString:@"i"]) {
            [self setValue:dict[key] forKey:key];
        }
        
        if ([type isEqualToString:@"d"] || [type isEqualToString:@"f"]) {
            [self setValue:dict[key] forKey:key];
        }
        
        if ([type isEqualToString:@"c"]) {
            [self setValue:dict[key] forKey:key];
        }
    }
    
    return self;
}

- (id)getFormatedValueForKey:(NSString*)key withType:(NSString*)type{
    if ([type isEqualToString:@"NSString"]) {
        return [self valueForKey:key];
    }
    
    if ([type isEqualToString:@"NSDate"]) {
        NSDate *tmpDate = [self valueForKey:key];
        return [NSNumber numberWithDouble:[tmpDate timeIntervalSince1970]];
    }
    
    if ([type isEqualToString:@"NSArray"] || [type isEqualToString:@"NSMutableArray"] || [type isEqualToString:@"NSDictionary"] || [type isEqualToString:@"NSMutableDictionary"]) {
        id value = [self valueForKey:key];
        if (value != nil) {
            return [self serializeArrayOrDictionary:value];
        }else{
            value = @"";
        }
        
    }
    
    if ([type isEqualToString:@"i"]) {
        return [self valueForKey:key];
    }
    
    if ([type isEqualToString:@"d"] || [type isEqualToString:@"f"]) {
        return [self valueForKey:key];
    }
    
    if ([type isEqualToString:@"c"]) {
        return [NSNumber numberWithInt:(int)[[self valueForKey:key] integerValue]];
    }
    
    return @"Unsupported Format";
    
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

#pragma mark Settings Methos 

+ (BOOL)absoluteRow{
    return NO;
}

+ (void (^)(bool))initBlockCompletition{
    return nil;
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
        [encoder encodeObject:[self getFormatedValueForKey:key withType:propsAndTypes[key]] forKey:key];
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

+ (instancetype)uniqueRow{
    return [[BWDataBaseManager sharedInstance] getLastInsertedRowForDataModel:[self class]];
}

- (void)insertRow{
    [[BWDataBaseManager sharedInstance] insertRowFromDataModel:self];
}

- (void)updateRow{
    [[BWDataBaseManager sharedInstance] updateRowFromDataModel:self];
}

- (void)deleteRow{
    [[BWDataBaseManager sharedInstance] deleteRowFromDataModel:self];
}

+ (void)deleteTable{
    [[BWDataBaseManager sharedInstance] dropTableForDataModelClass:[self class]];
}

+ (void)deleteDatabase{
    [[BWDataBaseManager sharedInstance] deleteDataBase];
}

+ (NSMutableArray*)getAllRows{
    return [[BWDataBaseManager sharedInstance] getAllRowsForDataModel:[self class]];
}

+ (NSMutableArray*)makeQuery:(NSString*)query{
    return [[BWDataBaseManager sharedInstance] getRowsFromQuery:query forDataModel:[self class]];
}

+ (NSMutableArray*)rawQuery:(NSString*)query{
    return [[BWDataBaseManager sharedInstance] getRawDataFromQuery:query];
}

- (void)swapOrderWithDataModel:(BWDataModel*)otherDataModel{
    if ([self class] != [otherDataModel class]) {
        NSLog(@"To make a swap both datamodels have to be of the same class!");
        return;
    }
    
    NSNumber *swapId = otherDataModel.BWRowId;
    otherDataModel.BWRowId = self.BWRowId;
    self.BWRowId = swapId;
    
    [self updateRow];
    [otherDataModel updateRow];
}


@end
