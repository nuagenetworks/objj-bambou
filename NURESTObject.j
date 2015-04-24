/*
*   Filename:         NURESTObject.j
*   Created:          Tue Oct  9 11:49:46 PDT 2012
*   Author:           Antoine Mercadal <antoine.mercadal@alcatel-lucent.com>
*   Description:      VSA
*   Project:          Cloud Network Automation - Nuage - Data Center Service Delivery - IPD
*
* Copyright (c) 2011-2012 Alcatel, Alcatel-Lucent, Inc. All Rights Reserved.
*
* This source code contains confidential information which is proprietary to Alcatel.
* No part of its contents may be used, copied, disclosed or conveyed to any party
* in any manner whatsoever without prior written permission from Alcatel.
*
* Alcatel-Lucent is a trademark of Alcatel-Lucent, Inc.
*
*/

@import <Foundation/Foundation.j>

@import "NURESTConfirmation.j"
@import "NURESTConnection.j"
@import "NURESTError.j"
@import "NURESTLoginController.j"
@import "NURESTModelController.j"

NURESTObjectStatusTypeSuccess   = @"SUCCESS";
NURESTObjectStatusTypeWarning   = @"WARNING";
NURESTObjectStatusTypeFailed    = @"FAILED";

NURESTObjectAttributeAllowedValuesKey   = @"allowedValues";
NURESTObjectAttributeDisplayNameKey     = @"displayName";

@class NURESTAbstractUser
@global CPCriticalAlertStyle
@global CPWarningAlertStyle
@global NUDataTransferController
@global NURESTConnectionFailureNotification

@global NURESTConnectionMethodDelete
@global NURESTConnectionMethodGet
@global NURESTConnectionMethodPost
@global NURESTConnectionMethodPut

@global NURESTConnectionResponseBadRequest
@global NURESTConnectionResponseCodeConflict
@global NURESTConnectionResponseCodeCreated
@global NURESTConnectionResponseCodeEmpty
@global NURESTConnectionResponseCodeInternalServerError
@global NURESTConnectionResponseCodeMultipleChoices
@global NURESTConnectionResponseCodeNotFound
@global NURESTConnectionResponseCodePreconditionFailed
@global NURESTConnectionResponseCodeSuccess
@global NURESTConnectionResponseCodeUnauthorized
@global NURESTConnectionResponseCodeZero
@global NURESTErrorNotification


NURESTOBJECT_ICONS_CACHE = @{};

function _format_log_json(string)
{
    if (!string || !string.length)
        return "";

    try
    {
        return JSON.stringify(JSON.parse(string), null, 4);
    }
    catch(e)
    {
        return string
    };
}

/*!
    Basic object with REST saving/fetching utilities
*/
@implementation NURESTObject : CPObject
{
    BOOL            _dirty                          @accessors(getter=isDirty);
    CPArray         _bindableAttributes             @accessors(property=bindableAttributes);
    CPDate          _creationDate                   @accessors(property=creationDate);
    CPDate          _lastUpdatedDate                @accessors(property=lastUpdatedDate);
    CPDictionary    _restAttributes                 @accessors(property=RESTAttributes);
    CPDictionary    _searchAttributes               @accessors(getter=searchAttributes);
    CPString        _externalID                     @accessors(property=externalID);
    CPString        _ID                             @accessors(property=ID);
    CPString        _lastUpdatedBy                  @accessors(property=lastUpdatedBy);
    CPString        _localID                        @accessors(property=localID);
    CPString        _owner                          @accessors(property=owner);
    CPString        _parentID                       @accessors(property=parentID);
    CPString        _parentType                     @accessors(property=parentType);
    NURESTObject    _parentObject                   @accessors(property=parentObject);

    CPDictionary    _fetchersRegistry;
    CPString        _chachedFullTextPredicateFormat;
}


#pragma mark -
#pragma mark Class Methods

/*! Returns the REST base URL.
*/
+ (CPURL)RESTBaseURL
{
    return [[NURESTLoginController defaultController] URL];
}

/*! REST name of the object
*/
+ (CPString)RESTName
{
    return "object";
}

/*! REST resource name of the object.
    It will compute the plural if needed
*/
+ (CPString)RESTResourceName
{
    var queryName = [self RESTName];

    if ([self RESTResourceNameFixed])
        return queryName;

    switch (queryName.slice(-1))
    {
        case @"s":
            break;

        case @"y":
            if (queryName.slice(-2) == @"ry" || queryName.slice(-2) == @"cy")
            {
                queryName = queryName.substr(0, queryName.length - 1);
                queryName += @"ies";
                break;
            }

        default:
            queryName += @"s";
    }

    return queryName;
}

/*! If overriden to return YES, RESTResourceName will not be called
    to make the resource plural
*/
+ (BOOL)RESTResourceNameFixed
{
    return NO
}

+ (NURESTObject)RESTObjectWithID:(CPString)anID
{
    var newObject = [self new];
    [newObject setID:anID];

    return newObject;
}

+ (CPImage)icon
{
    if (![NURESTOBJECT_ICONS_CACHE containsKey:[self RESTName]])
        [NURESTOBJECT_ICONS_CACHE setObject:CPImageInBundle("icon-" + [self RESTName] + ".png") forKey:[self RESTName]];

    return [NURESTOBJECT_ICONS_CACHE objectForKey:[self RESTName]];
}


#pragma mark -
#pragma mark Initialization

/*! Initialize the NURESTObject
*/
- (id)init
{
    if (self = [super init])
    {
        _bindableAttributes       = [];
        _fetchersRegistry         = @{};
        _localID                  = [CPString UUID];
        _restAttributes           = @{};
        _searchAttributes         = @{};

        [self exposeLocalKeyPathToREST:@"creationDate" displayName:@"creation date"];
        [self exposeLocalKeyPathToREST:@"externalID" searchable:NO];
        [self exposeLocalKeyPathToREST:@"ID" searchable:NO];
        [self exposeLocalKeyPathToREST:@"lastUpdatedBy" searchable:NO];
        [self exposeLocalKeyPathToREST:@"lastUpdatedDate" displayName:@"last update date"];
        [self exposeLocalKeyPathToREST:@"owner" searchable:NO];
        [self exposeLocalKeyPathToREST:@"parentID" searchable:NO];
        [self exposeLocalKeyPathToREST:@"parentType" searchable:NO];
    }

    return self;
}


#pragma mark -
#pragma mark Fetchers Registry

/*! @ignore
    Register a fetcher for a given RESTName. You must not call this by yourself
    This will be done when creating a fetcher in [self init]
*/
- (void)registerFetcher:(NURESTFetcher)aFetcher forRESTName:(CPString)aRESTName
{
    [_fetchersRegistry setObject:aFetcher forKey:aRESTName];
}

/*! Return the children fetcher for the given RESTName
*/
- (NURESTFetcher)fetcherForRESTName:(CPString)aRESTName
{
    return [_fetchersRegistry objectForKey:aRESTName];
}

/*! Return the list of all registered childen fetchers
*/
- (CPArray)fetchers
{
    return [[_fetchersRegistry allValues] copy];
}


#pragma mark -
#pragma mark Children Registry

/*! Return the list of all registered children RESTNames
*/
- (CPArray)childrenRESTNames
{
    var names = [],
        fetchers = [self fetchers];

    for (var i = [fetchers count] - 1; i >= 0; i--)
        [names addObject:[[fetchers[i] class] managedObjectRESTName]];

    return names;
}


#pragma mark -
#pragma mark Memory Management

- (void)discard
{
    // no need to go over another discard
    if (_dirty)
        return;

    _dirty = YES;

    [self willDiscard];

    CPLog.debug("RESTCAPPUCCINO: discarding object " + _ID + " of type " + [self RESTName]);

    [self discardAllFetchers];

    _parentObject       = nil;
    _fetchersRegistry   = nil;

    delete self;
}

- (void)willDiscard
{

}

- (void)discardFetcherForRESTName:(CPString)aRESTName
{
    CPLog.debug("RESTCAPPUCCINO: " + [self RESTName] + " with ID " + _ID + " is discarding children list " + aRESTName);

    [[self fetcherForRESTName:aRESTName] flush];
}

- (void)discardAllFetchers
{
    var names = [self childrenRESTNames];

    for (var i = [names count] - 1; i >= 0; i--)
        [self discardFetcherForRESTName:names[i]];
}

- (void)addChild:(NURESTObject)aChildObject
{
    var fetcher = [self fetcherForRESTName:[aChildObject RESTName]];

    if (!fetcher)
        [CPException raise:CPInternalInconsistencyException reason:@"Cannot insert object with REST Name " + [aChildObject RESTName] + " in any local fetcher."];

    if (![fetcher containsObject:aChildObject])
        [fetcher addObject:aChildObject];
}

- (void)removeChild:(NURESTObject)aChildObject
{
    var fetcher = [self fetcherForRESTName:[aChildObject RESTName]];

    if (!fetcher)
        [CPException raise:CPInternalInconsistencyException reason:@"Cannot remove object with REST Name " + [aChildObject RESTName] + " from any local fetcher."];

    [fetcher removeObject:aChildObject];
}

- (void)updateChild:(NURESTObject)aChildObject
{
    var fetcher = [self fetcherForRESTName:[aChildObject RESTName]];

    if (!fetcher)
        [CPException raise:CPInternalInconsistencyException reason:@"Cannot update object with REST Name " + [aChildObject RESTName] + " from any local fetcher."];

    [fetcher replaceObjectAtIndex:[fetcher indexOfObject:aChildObject] withObject:aChildObject];
}


#pragma mark -
#pragma mark REST configuration

/*! Returns the class icon (just wrapping + (CPString)icon)
*/
- (CPImage)icon
{
    return [[self class] icon];
}

/*! Returns the RESTName name of the object (just wrapping + (CPString)RESTName)
*/
- (CPString)RESTName
{
    return [[self class] RESTName];
}

/*! Builds the base query URL to manage this object
    this must be overiden by subclasses
    @return a CPURL representing the REST endpoint to manage this object
*/
- (CPURL)RESTResourceURL
{
    return [CPURL URLWithString:[[self class] RESTResourceName] + @"/" + [self ID] + "/" relativeToURL:[[self class] RESTBaseURL]];
}

/*! Returns the base rest resource URL for accessing children
    By default it uses the childrenClass RESTResourceName appeneded to the current RESTResourceURL
*/
- (CPURL)RESTResourceURLForChildrenClass:(Class)aChildrenClass
{
    return [CPURL URLWithString:[aChildrenClass RESTResourceName] relativeToURL:[self RESTResourceURL]];
}

/*! Exposes new attribute for REST managing
    for example, if subclass has an attribute "name" and you want to be able to save it
    in REST data model, use
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"name" allowedValues:[@"A", @"B", @"C", @"D"]];
    You can also save the attribute to another leaf, like
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"basicattributes.name" allowedValues:[@"A", @"B", @"C", @"D"]];
    @param aKeyPath the local key path to expose
    @param aRestKeyPath the destination key path of the REST object
    @param aName the name that should be used displayed to the end user
    @param searchable a bool saying wether or not the key path can be used for advanced search
    @param allowedValues a list of the valid allowed values for the rest API
*/
- (void)exposeLocalKeyPath:(CPString)aKeyPath toRESTKeyPath:(CPString)aRestKeyPath displayName:(CPString)aName searchable:(BOOL)aBool allowedValues:(CPArray)someChoices
{
    if (aBool)
    {
        var attributeInfo = [CPDictionary dictionary];

        if (someChoices)
            [attributeInfo setObject:someChoices forKey:NURESTObjectAttributeAllowedValuesKey];

        if (!aName)
            aName = aKeyPath;

        [attributeInfo setObject:aName forKey:NURESTObjectAttributeDisplayNameKey];

        [_searchAttributes setObject:attributeInfo forKey:aKeyPath];
    }

    [_restAttributes setObject:aRestKeyPath forKey:aKeyPath];
}

/*! Exposes new attribute for REST managing
    for example, if subclass has an attribute "name" and you want to be able to save it
    in REST data model, use
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"name"];
    You can also save the attribute to another leaf, like
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"basicattributes.name"];
    @param aKeyPath the local key path to expose
    @param aRestKeyPath the destination key path of the REST object
    @param allowedValues a list of the valid allowed values for the rest API
*/
- (void)exposeLocalKeyPath:(CPString)aKeyPath toRESTKeyPath:(CPString)aRestKeyPath allowedValues:(CPArray)someChoices
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aRestKeyPath displayName:aKeyPath searchable:YES allowedValues:someChoices];
}

/*! Exposes new attribute for REST managing
    for example, if subclass has an attribute "name" and you want to be able to save it
    in REST data model, use
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"name"];
    You can also save the attribute to another leaf, like
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"basicattributes.name"];
    @param aKeyPath the local key path to expose
    @param aRestKeyPath the destination key path of the REST object
    @param aName the name that should be used displayed to the end user
    @param allowedValues a list of the valid allowed values for the rest API
*/
- (void)exposeLocalKeyPath:(CPString)aKeyPath toRESTKeyPath:(CPString)aRestKeyPath displayName:(CPString)aName allowedValues:(CPArray)someChoices
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aRestKeyPath displayName:aName searchable:YES allowedValues:someChoices];
}

/*! Exposes new attribute for REST managing
    for example, if subclass has an attribute "name" and you want to be able to save it
    in REST data model, use
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"name"];
    You can also save the attribute to another leaf, like
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"basicattributes.name"];
    @param aKeyPath the local key path to expose
    @param aRestKeyPath the destination key path of the REST object
    @param searchable a bool saying wether or not the key path can be used for advanced search
*/
- (void)exposeLocalKeyPath:(CPString)aKeyPath toRESTKeyPath:(CPString)aRestKeyPath searchable:(BOOL)aBool
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aRestKeyPath displayName:aKeyPath searchable:aBool allowedValues:nil];
}

/*! Exposes new attribute for REST managing
    for example, if subclass has an attribute "name" and you want to be able to save it
    in REST data model, use
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"name"];
    You can also save the attribute to another leaf, like
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"basicattributes.name"];
    @param aKeyPath the local key path to expose
    @param aRestKeyPath the destination key path of the REST object
*/
- (void)exposeLocalKeyPath:(CPString)aKeyPath toRESTKeyPath:(CPString)aRestKeyPath
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aRestKeyPath displayName:aKeyPath searchable:YES allowedValues:nil];
}

/*! Exposes new attribute for REST managing
    for example, if subclass has an attribute "name" and you want to be able to save it
    in REST data model, use
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"name"];
    You can also save the attribute to another leaf, like
        - [self exposeLocalKeyPath:@"name" toRESTKeyPath:@"basicattributes.name"];
    @param aKeyPath the local key path to expose
    @param aRestKeyPath the destination key path of the REST object
    @param aName the name that should be used displayed to the end user
*/
- (void)exposeLocalKeyPath:(CPString)aKeyPath toRESTKeyPath:(CPString)aRestKeyPath displayName:(CPString)aName
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aRestKeyPath displayName:aName searchable:YES allowedValues:nil];
}

/*! Same as exposeLocalKeyPath:toRESTKeyPath:. Difference is that the rest keypath
    will be the same than the local key path
    @param aKeyPath the local key path to expose
    @param allowedValues a list of the valid allowed values for the rest API
*/
- (void)exposeLocalKeyPathToREST:(CPString)aKeyPath allowedValues:(CPArray)someChoices
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aKeyPath displayName:aKeyPath searchable:YES allowedValues:someChoices];
}

/*! Same as exposeLocalKeyPath:toRESTKeyPath:. Difference is that the rest keypath
    will be the same than the local key path
    @param aKeyPath the local key path to expose
    @param aName the name that should be used displayed to the end user
    @param allowedValues a list of the valid allowed values for the rest API
*/
- (void)exposeLocalKeyPathToREST:(CPString)aKeyPath displayName:(CPString)aName allowedValues:(CPArray)someChoices
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aKeyPath displayName:aName searchable:YES allowedValues:someChoices];
}

/*! Same as exposeLocalKeyPath:toRESTKeyPath:. Difference is that the rest keypath
    will be the same than the local key path
    @param aKeyPath the local key path to expose
    @param searchable a bool saying wether or not the key path can be used for advanced search
*/
- (void)exposeLocalKeyPathToREST:(CPString)aKeyPath searchable:(BOOL)aBool
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aKeyPath displayName:aKeyPath searchable:aBool allowedValues:nil];
}

/*! Same as exposeLocalKeyPath:toRESTKeyPath:. Difference is that the rest keypath
    will be the same than the local key path
    @param aKeyPath the local key path to expose
*/
- (void)exposeLocalKeyPathToREST:(CPString)aKeyPath
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aKeyPath displayName:aKeyPath searchable:YES allowedValues:nil];
}

/*! Same as exposeLocalKeyPath:toRESTKeyPath:. Difference is that the rest keypath
    will be the same than the local key path
    @param aKeyPath the local key path to expose
    @param aName the name that should be used displayed to the end user
*/
- (void)exposeLocalKeyPathToREST:(CPString)aKeyPath displayName:(CPString)aName
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aKeyPath displayName:aName searchable:YES allowedValues:nil];
}

/*! Expose some property that are bindable, but not from the model.
    This is usefull when you want to automatize binding of transformed properties.
*/
- (void)exposeBindableAttribute:(CPString)aKeyPath
{
    [_bindableAttributes addObject:aKeyPath];
}

/*! Returns the local key path according to the resgitered given REST attribute
*/
- (CPString)localKeyPathForRESTKeyPath:(CPString)aKeyPath
{
    return [[_restAttributes allKeysForObject:aKeyPath] firstObject];
}


/*! Returns the list of bindable attributes
*/
- (CPArray)bindableAttributes
{
    return [[_restAttributes allKeys] arrayByAddingObjectsFromArray:_bindableAttributes];
}

/*! Return the type name of a given local key path
*/
- (CPString)typeOfLocalKeyPath:(CPString)aKeyPath
{
    var methodInfo = self.isa.method_dtable[aKeyPath];

    if (!methodInfo)
        [CPException raise:CPInvalidArgumentException reason:@"Cannot find method named " + aKeyPath];

    return methodInfo.types[0];
}


#pragma mark -
#pragma mark JSON Management

/*! Build current object with given JSONObject
    @param aJSONObject the JSON structure to parse
*/
- (void)objectFromJSON:(id)aJSONObject
{
    var keys = [[_restAttributes allKeys] copy];

    // set the mandatory attributes first
    [self setID:aJSONObject.ID];

    if (aJSONObject.creationDate)
        [self setCreationDate:[CPDate dateWithTimeIntervalSince1970:(parseInt(aJSONObject.creationDate) / 1000)]];

    if (aJSONObject.lastUpdatedDate)
        [self setLastUpdatedDate:[CPDate dateWithTimeIntervalSince1970:(parseInt(aJSONObject.lastUpdatedDate) / 1000)]];

    // cleanup these keys
    [keys removeObject:@"ID"];
    [keys removeObject:@"creationDate"];
    [keys removeObject:@"lastUpdatedDate"];

    for (var i = [keys count] - 1; i >= 0; i--)
    {
        var attribute = keys[i],
            restPath = [_restAttributes objectForKey:attribute],
            restValue =  aJSONObject[restPath];

        [self setValue:restValue forKeyPath:attribute];
    }
}

/*! Build a JSON  structure with current object state
    @returns JSON structure representing the object
*/
- (CPString)objectToJSON
{
    var json = {},
        keys = [_restAttributes allKeys];

    for (var i = [keys count] - 1; i >= 0; i--)
    {
        var attribute = keys[i],
            restPath = [_restAttributes objectForKey:attribute],
            value = [self valueForKeyPath:attribute];

        if (attribute == "creationDate" || attribute == "lastUpdatedDate")
            continue;

        if (typeof(value) == "string" && value.length  == 0)
            value = nil;

        json[restPath] = value;
    }

    return json;
}


#pragma mark -
#pragma mark Comparison

- (BOOL)isRESTEqual:(NURESTObject)anObject
{
    if ([anObject RESTName] != [self RESTName])
        return NO;

    var attributes = [[self RESTAttributes] allKeys];

    for (var i = [attributes count] - 1; i >= 0; i--)
    {
        var attribute = attributes[i];

        if (attribute == "creationDate" || attribute == "lastUpdatedDate")
            continue;

        var localValue = [self valueForKeyPath:attribute],
            remoteValue = [anObject valueForKeyPath:attribute];

        if ([localValue isKindOfClass:CPString] && ![localValue length])
            localValue = nil;

        if ([remoteValue isKindOfClass:CPString] && ![remoteValue length])
            remoteValue = nil;

        if (localValue != remoteValue)
            return NO;
    }

    return YES;
}

- (BOOL)isEqual:(NURESTObject)anObject
{
    if (![anObject respondsToSelector:@selector(ID)])
        return NO;

    var ID = [self ID];
    if (ID)
        return (ID == [anObject ID]);

    var localID = [self localID];
    if (localID)
        return (localID == [anObject localID]);
}

- (BOOL)isOwnedByCurrentUser
{
    return _owner == [[NURESTAbstractUser defaultUser] ID];
}


#pragma mark -
#pragma mark Genealogy

- (BOOL)isCurrentUserOwnerOfAnyParentMatchingTypes:(CPArray)someRESTNames
{
    var parent = self;

    while (parent = [parent parentObject])
        if ([someRESTNames containsObject:[parent RESTName]] && [parent isOwnedByCurrentUser])
            return YES;

    return NO;
}

- (NURESTObject)parentForMatchingRESTName:(CPArray)someRESTNames
{
    var parent = self;

    while (parent = [parent parentObject])
        if ([someRESTNames containsObject:[parent RESTName]])
            return parent;

    return nil;
}

- (BOOL)genealogicTypes
{
    var types = [],
        parent = self;

    while (parent)
    {
        [types addObject:[parent RESTName]];
        parent = [parent parentObject];
    }

    return types;
}

- (BOOL)genealogicIDs
{
    var IDs = [],
        parent = self;

    while (parent)
    {
        [IDs addObject:[parent ID]];
        parent = [parent parentObject];
    }

    return IDs;
}

- (BOOL)genealogyContainsType:(CPString)aType
{
    return [[self genealogicTypes] containsObject:aType];
}

- (BOOL)genealogyContainsID:(CPString)anID
{
    return [[self genealogicIDs] containsObject:anID];
}


#pragma mark -
#pragma mark Custom accessors

- (void)setCreationDate:(CPDate)aDate
{
    if ([aDate isEqual:_creationDate])
        return;

    [self willChangeValueForKey:@"creationDate"];
    [self willChangeValueForKey:@"formatedCreationDate"];
    _creationDate = aDate;
    [self didChangeValueForKey:@"creationDate"];
    [self didChangeValueForKey:@"formatedCreationDate"];
}

- (CPString)formatedCreationDate
{
    if (!_creationDate)
        return "No date";

    return _creationDate.format("mmm dd yyyy HH:MM:ss");
}

- (void)setLastUpdatedDate:(CPDate)aDate
{
    if ([aDate isEqual:_lastUpdatedDate])
        return;

    [self willChangeValueForKey:@"lastUpdatedDate"];
    [self willChangeValueForKey:@"formatedLastUpdatedDate"];
    _lastUpdatedDate = aDate;
    [self didChangeValueForKey:@"lastUpdatedDate"];
    [self didChangeValueForKey:@"formatedLastUpdatedDate"];
}

- (CPString)formatedLastUpdatedDate
{
    if (!_lastUpdatedDate)
        return "No date";

    return _lastUpdatedDate.format("mmm dd yyyy HH:MM:ss");
}

- (CPString)description
{
    return "<" + [self className] + "> " + [self ID];
}

- (CPString)alternativeDescription
{
    return [self description];
}


#pragma mark -
#pragma mark Key Value Coding

- (id)valueForUndefinedKey:(CPString)aKey
{
    return nil;
}


#pragma mark -
#pragma mark Copy

- (void)prepareForCopy
{
    [self setID:nil];
    [self setParentID:nil];
    [self setLocalID:nil];
}


#pragma mark -
#pragma mark Predicate Generation

- (CPPredicate)fullTextSearchPredicate:(CPString)aString
{
    if (!_chachedFullTextPredicateFormat)
    {
        var attributes = [_searchAttributes allKeys],
            subpredicates = [];

        for (var i = [attributes count] - 1; i >= 0; i--)
        {
            var attribute = attributes[i],
                info = [_searchAttributes objectForKey:attribute],
                allowedValues = [info objectForKey:NURESTObjectAttributeAllowedValuesKey],
                RESTAttribute = [_restAttributes objectForKey:attribute];

            if (allowedValues)
            {
                if (![allowedValues containsObject:aString])
                    continue;

                [subpredicates addObject:[CPPredicate predicateWithFormat:RESTAttribute + " == %@", @"--TOKEN--"]];
            }
            else
            {
                if ([self typeOfLocalKeyPath:attribute] == "CPString")
                    [subpredicates addObject:[CPPredicate predicateWithFormat:RESTAttribute + " contains %@", @"--TOKEN--"]];
            }
        }

        _chachedFullTextPredicateFormat = [[[CPCompoundPredicate alloc] initWithType:CPOrPredicateType subpredicates:subpredicates] predicateFormat];
    }

    return [CPPredicate predicateWithFormat:_chachedFullTextPredicateFormat.replace(/--TOKEN--/g, aString)];
}


#pragma mark -
#pragma mark REST Low Level communication

/*! Send a REST request and perform given selector of given object
    @param aRequest random CPURLRequest
    @param aSelector the selector to execute when complete
    @param anObject the target object
    @return a unique transaction ID
*/
- (CPString)sendRESTCall:(CPURLRequest)aRequest performSelector:(SEL)aSelector ofObject:(id)aLocalObject andPerformRemoteSelector:(SEL)aRemoteSelector ofObject:(id)anObject userInfo:(id)someUserInfo
{
    // be sure to set the content-type as application/json
    [aRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    var connection = [NURESTConnection connectionWithRequest:aRequest target:self selector:@selector(_didReceiveRESTReply:)];

    [connection setUserInfo:someUserInfo];

    [connection setInternalUserInfo:{   "localTarget": aLocalObject,
                                        "localSelector": aSelector,
                                        "remoteTarget": anObject,
                                        "remoteSelector": aRemoteSelector}];

    CPLog.trace("RESTCAPPUCCINO: >>>> Sending\n\n%@ %@:\n\n%@", [aRequest HTTPMethod], [aRequest URL], _format_log_json([aRequest HTTPBody]));

    [connection start];

    return [connection transactionID];
}

/*! @ignore
*/
- (void)_didReceiveRESTReply:(NURESTConnection)aConnection
{
    if ([aConnection hasTimeouted])
    {
        CPLog.error("RESTCAPPUCCINO: Connection timeouted. Sending NURESTConnectionFailureNotification notification and exiting.");
        [[CPNotificationCenter defaultCenter] postNotificationName:NURESTConnectionFailureNotification object:self userInfo:aConnection];
         return;
    }

    var url            = [[[aConnection request] URL] absoluteString],
        HTTPMethod     = [[aConnection request] HTTPMethod],
        rawString      = [[aConnection responseData] rawString],
        responseCode   = [aConnection responseCode],
        localTarget    = [aConnection internalUserInfo]["localTarget"],
        localSelector  = [aConnection internalUserInfo]["localSelector"],
        remoteTarget   = [aConnection internalUserInfo]["remoteTarget"],
        remoteSelector = [aConnection internalUserInfo]["remoteSelector"],
        hasHandlers    = !!(remoteTarget && remoteSelector);

    CPLog.trace("RESTCAPPUCCINO: <<<< Response for\n\n%@ %@ (%@):\n\n%@", HTTPMethod, url, responseCode, _format_log_json(rawString));

    var shouldProceed = [NURESTConnection handleResponseForConnection:aConnection postErrorMessage:!hasHandlers];

    if (shouldProceed)
        [localTarget performSelector:localSelector withObject:aConnection];
}


#pragma mark -
#pragma mark REST CRUD Operations

/*! Fetchs object attributes. This requires that the Cappuccino object has a valid ID
    @param aSelector the selector to use when fetching is ok
    @param anObject the target to send the selector
    @return a unique transaction ID
*/
- (CPString)fetchAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    return [self _manageChildObject:self method:NURESTConnectionMethodGet andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didFetchObject:)];
}

/*! Create object and call given selector
    @param aSelector the creation is complete
    @param anObject the target to send the selector
    @return a unique transaction ID
*/
- (CPString)createAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    return [self _manageChildObject:self method:NURESTConnectionMethodPost andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didCreateObject:)];
}

/*! Delete object and call given selector
    @param aSelector the deletion is complete
    @param anObject the target to send the selector
    @return a unique transaction ID
*/
- (CPString)deleteAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    return [self _manageChildObject:self method:NURESTConnectionMethodDelete andCallSelector:aSelector ofObject:anObject customConnectionHandler:nil];
}

/*! Update object and call given selector
    @param aSelector the saving is complete
    @param anObject the target to send the selector
    @return a unique transaction ID
*/
- (CPString)saveAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    return [self _manageChildObject:self method:NURESTConnectionMethodPut andCallSelector:aSelector ofObject:anObject customConnectionHandler:nil];
}


#pragma mark -
#pragma mark Advanced REST Operations

/*! Add given object into given ressource of current object
    for example, to add a NUGroup into a NUEnterprise, you can call
     [anObject createChildObject:aGroup resource:@"groups" andCallSelector:nil ofObject:nil]

    @param anChildObject the NURESTObject object of add
    @param aSelector the selector to call when complete
    @param aChildObject the target object
    @return a unique transaction ID
*/
- (CPString)createChildObject:(NURESTObject)aChildObject andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    return [self _manageChildObject:aChildObject method:NURESTConnectionMethodPost andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didcreateChildObject:)];
}

/*! Instantiate a given object from a given template
    @param anChildObject the NURESTObject object of add
    @param aTemplate the original template
    @param aSelector the selector to call when complete
    @param aChildObject the target object
    @return a unique transaction ID
*/
- (CPString)instantiateChildObject:(NURESTObject)aChildObject fromTemplate:(NURESTObject)aTemplate andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [aChildObject setTemplateID:[aTemplate ID]];

    return [self _manageChildObject:aChildObject method:NURESTConnectionMethodPost andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didcreateChildObject:)];
}

/*! Low level child manegement. Send given HTTP method with given object to given ressource of current object
    for example, to remove a NUGroup into a NUEnterprise, you can call
     [anEnterpriese removeChildEntity:aGroup method:NURESTObjectMethodDelete andCallSelector:nil ofObject:nil]

    @param aChildObject the NURESTObject object of add
    @param aMethod HTTP method
    @param aSelector the selector to call when complete
    @param anObject the target object
    @param aCustomHandler custom handler to call when complete
    @return a unique transaction ID
*/
- (CPString)_manageChildObject:(NURESTObject)aChildObject method:(CPString)aMethod andCallSelector:(SEL)aSelector ofObject:(id)anObject customConnectionHandler:(SEL)aCustomHandler
{
    var body = JSON.stringify([aChildObject objectToJSON]),
        URL;

    switch (aMethod)
    {
        case NURESTConnectionMethodPut:
        case NURESTConnectionMethodDelete:
        case NURESTConnectionMethodGet:
            URL = [aChildObject RESTResourceURL];
            break;

        case NURESTConnectionMethodPost:
            URL = [self RESTResourceURLForChildrenClass:[aChildObject class]];
            break;
    }

    var request = [CPURLRequest requestWithURL:URL];
    [request setHTTPMethod:aMethod];

    if (aMethod == NURESTConnectionMethodPost || aMethod == NURESTConnectionMethodPut)
        [request setHTTPBody:body];

    var handlerSelector = aCustomHandler || @selector(_didPerformStandardOperation:);

    return [self sendRESTCall:request performSelector:handlerSelector ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:aChildObject];
}

/*! Uses this to reference given objects into the given resource of the actual object.
    @param someEntities CPArray containing any subclass of NURESTObject
    @param aSelector the selector to call when complete
    @param anObject the target object
*/
- (CPString)assignEntities:(CPArray)someEntities ofClass:(Class)aClass andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    var IDsList = [];

    for (var i = [someEntities count] - 1; i >= 0; i--)
        [IDsList addObject:[someEntities[i] ID]];

    var request = [CPURLRequest requestWithURL:[self RESTResourceURLForChildrenClass:aClass]],
        body = JSON.stringify(IDsList, null, 4);

    [request setHTTPMethod:NURESTConnectionMethodPut];
    [request setHTTPBody:body];

    return [self sendRESTCall:request performSelector:@selector(_didPerformStandardOperation:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:someEntities];
}


#pragma mark -
#pragma mark REST Operation handlers

- (void)_didFetchObject:(NURESTConnection)aConnection
{
    var JSONData = [[aConnection responseData] JSONObject],
        target   = [aConnection internalUserInfo]["remoteTarget"],
        selector = [aConnection internalUserInfo]["remoteSelector"];

    try {[self objectFromJSON:JSONData[0]];} catch(e) {}

    if (target && selector)
        [target performSelector:selector withObjects:self, aConnection];
}

/*! Called as a custom handler when creating a new object
*/
- (void)_didCreateObject:(NURESTConnection)aConnection
{
    var JSONData = [[aConnection responseData] JSONObject];

    try {[self objectFromJSON:JSONData[0]];} catch(e) {}

    [self _didPerformStandardOperation:aConnection];
}

/*! Called as a custom handler when creating a child object
*/
- (void)_didcreateChildObject:(NURESTConnection)aConnection
{
    var JSONData = [[aConnection responseData] JSONObject];

    try {[[aConnection userInfo] objectFromJSON:JSONData[0]];} catch(e) {}

    [self _didPerformStandardOperation:aConnection];
}

/*! Standard handler called when managing a child object
*/
- (void)_didPerformStandardOperation:(NURESTConnection)aConnection
{
    var target = [aConnection internalUserInfo]["remoteTarget"],
        selector = [aConnection internalUserInfo]["remoteSelector"],
        userInfo = [aConnection userInfo];

    if (target && selector && userInfo)
        [target performSelector:selector withObjects:self, userInfo, aConnection];
    else if (target && selector)
        [target performSelector:selector withObjects:self, aConnection];
}


#pragma mark -
#pragma mark CPCoding

/*! CPCoder compliance
*/
- (id)initWithCoder:(CPCoder)aCoder
{
    if (self = [self init])
    {
        _localID                      = [aCoder decodeObjectForKey:@"_localID"];
        _parentObject                 = [aCoder decodeObjectForKey:@"_parentObject"];

        var encodedKeys = [aCoder._plistObject allKeys];

        for (var i = [encodedKeys count] - 1; i >= 0; i--)
        {
            var key = encodedKeys[i],
                splitedInfo = key.split("@");

            if ([splitedInfo count] != 2)
                continue;

            var localKeyPath = splitedInfo[0],
                encodedYype = splitedInfo[1];

            switch (encodedYype)
            {
                case "boolean":
                    [self setValue:[aCoder decodeBoolForKey:key] forKeyPath:localKeyPath];
                    break;

                case "number":
                    [self setValue:[aCoder decodeFloatForKey:key] forKeyPath:localKeyPath];
                    break;

                default:
                    [self setValue:[aCoder decodeObjectForKey:key] forKeyPath:localKeyPath];
            }
        }
    }

    return self;
}

/*! CPCoder compliance
*/
- (void)encodeWithCoder:(CPCoder)aCoder
{
    [aCoder encodeObject:_localID forKey:@"_localID"];
    [aCoder encodeObject:_parentObject forKey:@"_parentObject"];

    var bindableAttributes = [self bindableAttributes];
    for (var i = [bindableAttributes count] - 1; i >= 0; i--)
    {
        var attr = bindableAttributes[i],
            key = attr;

        switch (typeof(attr))
        {
            case "boolean":
                key += "@bool";
                [aCoder encodeBool:[self valueForKeyPath:attr] forKey:key];
                break;

            case "number":
                key += "@number";
                [aCoder encodeFloat:[self valueForKeyPath:attr] forKey:key];
                break;

            default:
                key += "@object";
                [aCoder encodeObject:[self valueForKeyPath:attr] forKey:key];
        }
    }
}

@end
