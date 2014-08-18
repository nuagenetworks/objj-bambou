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

@import "NURESTConnection.j"
@import "NURESTLoginController.j"
@import "NURESTError.j"
@import "NURESTConfirmation.j"

NURESTObjectStatusTypeSuccess   = @"SUCCESS";
NURESTObjectStatusTypeWarning   = @"WARNING";
NURESTObjectStatusTypeFailed    = @"FAILED";

NURESTObjectAttributeAllowedValuesKey   = @"allowedValues";
NURESTObjectAttributeDisplayNameKey     = @"displayName";

@class NURESTBasicUser
@global NUDataTransferController
@global CPCriticalAlertStyle
@global CPWarningAlertStyle
@global NURESTConnectionFailureNotification
@global NURESTErrorNotification
@global NURESTConnectionResponseCodeZero
@global NURESTConnectionResponseCodeConflict
@global NURESTConnectionResponseCodeUnauthorized
@global NURESTConnectionResponseCodeMultipleChoices
@global NURESTConnectionResponseCodeInternalServerError
@global NURESTConnectionResponseBadRequest
@global NURESTConnectionResponseCodePreconditionFailed
@global NURESTConnectionResponseCodeNotFound
@global NURESTConnectionResponseCodeCreated
@global NURESTConnectionResponseCodeSuccess
@global NURESTConnectionResponseCodeEmpty


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
    CPDate          _creationDate                   @accessors(property=creationDate);
    CPString        _externalID                     @accessors(property=externalID);
    CPString        _ID                             @accessors(property=ID);
    CPString        _localID                        @accessors(property=localID);
    CPString        _owner                          @accessors(property=owner);
    CPString        _parentID                       @accessors(property=parentID);
    CPString        _parentType                     @accessors(property=parentType);

    CPDictionary    _restAttributes                 @accessors(property=RESTAttributes);
    CPDictionary    _searchAttributes               @accessors(getter=searchAttributes);
    CPArray         _bindableAttributes             @accessors(property=bindableAttributes);

    NURESTObject    _parentObject                   @accessors(property=parentObject);

    CPDictionary    _childrenRegistry;
}


#pragma mark -
#pragma mark Class Methods

+ (CPString)RESTName
{
    [CPException raise:CPInternalInconsistencyException reason:"Subclasses of NURESTObject must implement + (CPString)RESTName"];
}

/*! Returns the REST query name.
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

+ (BOOL)RESTResourceNameFixed
{
    return NO
}


#pragma mark -
#pragma mark Initialization

/*! Initialize the NURESTObject
*/
- (id)init
{
    if (self = [super init])
    {
        _bindableAttributes = [CPArray array];
        _childrenRegistry = @{};
        _localID = [CPString UUID];
        _restAttributes = [CPDictionary dictionary];
        _searchAttributes = [CPDictionary dictionary];

        [self exposeLocalKeyPathToREST:@"creationDate"];
        [self exposeLocalKeyPathToREST:@"externalID" searchable:NO];
        [self exposeLocalKeyPathToREST:@"ID" searchable:NO];
        [self exposeLocalKeyPathToREST:@"owner" searchable:NO];
        [self exposeLocalKeyPathToREST:@"parentID" searchable:NO];
        [self exposeLocalKeyPathToREST:@"parentType" searchable:NO];
    }

    return self;
}


#pragma mark -
#pragma mark  Memory Management

- (void)discard
{
    [self discardChildren];
    _parentObject = nil;

    [_childrenRegistry removeAllObjects];
    _childrenRegistry = nil;

    CPLog.debug("RESTCAPPUCCINO: discarding object " + [self ID] + " of type " + [self RESTName]);

    delete self;
}

- (void)discardChildren
{
    var children = [_childrenRegistry allValues];

    for (var i = [children count] - 1; i >= 0; i--)
        [children[i] makeObjectsPerformSelector:@selector(discard)];
}

- (void)registerChildrenList:(CPArray)aList forRESTName:(CPString)aRESTName
{
    [_childrenRegistry setObject:aList forKey:aRESTName];
}

- (CPArray)childrenListWithRESTName:(CPString)aRESTName
{
    return [_childrenRegistry objectForKey:aRESTName];
}

- (void)addChild:(NURESTObject)aChildObject
{
    [[self childrenListWithRESTName:[aChildObject RESTName]] addObject:aChildObject];
}

- (void)removeChild:(NURESTObject)aChildObject
{
    [[self childrenListWithRESTName:[aChildObject RESTName]] removeObject:aChildObject];
}

- (void)updateChild:(NURESTObject)aChildObject
{
    var children = [self childrenListWithRESTName:[aChildObject RESTName]],
        index = [children indexOfObject:aChildObject];

    [children replaceObjectAtIndex:index withObject:aChildObject];
}


#pragma mark -
#pragma mark REST configuration

/*! Returns the REST query name.
*/
- (CPString)RESTResourceName
{
    return [[self class] RESTResourceName];
}

/*! Builds the base query URL to manage this object
    this must be overiden by subclasses
    @return a CPURL representing the REST endpoint to manage this object
*/
- (CPURL)RESTResourceURL
{
    var queryName = [self RESTResourceName];

    if (!_ID)
        return [CPURL URLWithString:queryName + @"/" relativeToURL:[[NURESTLoginController defaultController] URL]];
    else
        return [CPURL URLWithString:queryName + @"/" + _ID + "/" relativeToURL:[[NURESTLoginController defaultController] URL]];
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

/*! Build current object with given JSONObject
    @param aJSONObject the JSON structure to parse
*/
- (void)objectFromJSON:(id)aJSONObject
{
    var keys = [_restAttributes allKeys];

    // set the mandatory attributes first
    [self setID:aJSONObject.ID];
    [self setCreationDate:[CPDate dateWithTimeIntervalSince1970:(parseInt(aJSONObject.creationDate) / 1000)]];

    // cleanup these keys
    [keys removeObject:@"ID"]
    [keys removeObject:@"creationDate"]

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

        if (attribute == "creationDate")
            continue;

        json[restPath] = value;
    }

    return JSON.stringify(json, null, 4);
}


#pragma mark -
#pragma mark Comparison

- (BOOL)isRESTEqual:(NURESTObject)anEntity
{
    if ([anEntity RESTName] != [self RESTName])
        return NO;

    var attributes = [[self RESTAttributes] allKeys];

    for (var i = [attributes count] - 1; i >= 0; i--)
    {
        var attribute = attributes[i];

        if (attribute == "creationDate")
            continue;

        var localValue = [self valueForKeyPath:attribute],
            remoteValue = [anEntity valueForKeyPath:attribute];

        if ([localValue isKindOfClass:CPString] && ![localValue length])
            localValue = nil;

        if ([remoteValue isKindOfClass:CPString] && ![remoteValue length])
            remoteValue = nil;

        if (localValue != remoteValue)
            return NO;
    }
    return YES;
}

- (BOOL)isEqual:(NURESTObject)anEntity
{
    if (![anEntity respondsToSelector:@selector(ID)])
        return NO;

    if (_ID)
        return ([self ID] == [anEntity ID]);

    if (_localID)
        return ([self localID] == [anEntity localID]);
}

- (CPString)description
{
    return "<" + [self className] + "> " + [self ID];
}

- (CPString)alternativeDescription
{
    return [self description];
}

- (CPString)RESTName
{
    return [[self class] RESTName];
}

- (BOOL)isOwnedByCurrentUser
{
    return _owner == [[NURESTBasicUser defaultUser] ID];
}

- (BOOL)isCurrentUserOwnerOfAnyParentMatchingTypes:(CPArray)someRESTNames
{
    var parent = self;

    while (parent = [parent parentObject])
        if ([someRESTNames containsObject:[parent RESTName]] && [parent isOwnedByCurrentUser])
            return YES;

    return NO;
}

- (NURESTObject)parentWithRESTNameMatching:(CPArray)someRESTNames
{
    var parent = self;

    while (parent = [parent parentObject])
        if ([someRESTNames containsObject:[parent RESTName]])
            return parent;

    return nil;
}


#pragma mark -
#pragma mark Custom accesors

- (CPString)formatedCreationDate
{
    return _creationDate.format("mmm dd yyyy HH:MM:ss");
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
#pragma mark Fetching

/*! Fetchs object attributes. This requires that the Cappuccino object has a valid ID
*/
- (void)fetch
{
    [self fetchAndCallSelector:nil ofObject:nil];
}

/*! Fetchs object attributes. This requires that the Cappuccino object has a valid ID
    @param aSelector the selector to use when fetching is ok
    @param anObject the target to send the selector
*/
- (void)fetchAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    var request = [CPURLRequest requestWithURL:[self RESTResourceURL]];

    [self sendRESTCall:request performSelector:@selector(_didFetch:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:nil];
}

/*! @ignore
*/
- (void)_didFetch:(NURESTConnection)aConnection
{
    var JSONObject = [[aConnection responseData] JSONObject];

    if (JSONObject)
        try { [self objectFromJSON:JSONObject[0]]; } catch (e){}

    [self _didPerformStandardOperation:aConnection];
}


#pragma mark -
#pragma mark REST Low Level communication

/*! Send a REST request and perform given selector of given object
    @param aRequest random CPURLRequest
    @param aSelector the selector to execute when complete
    @param anObject the target object
*/
- (void)sendRESTCall:(CPURLRequest)aRequest performSelector:(SEL)aSelector ofObject:(id)aLocalObject andPerformRemoteSelector:(SEL)aRemoteSelector ofObject:(id)anObject userInfo:(id)someUserInfo
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
        hasHandlers    = (remoteTarget && remoteSelector);

    CPLog.trace("RESTCAPPUCCINO: <<<< Response for\n\n%@ %@ (%@):\n\n%@", HTTPMethod, url, responseCode, _format_log_json(rawString));

    var shouldProceed = [NURESTConnection handleResponseForConnection:aConnection postErrorMessage:!hasHandlers];

    if (hasHandlers && shouldProceed)
        [localTarget performSelector:localSelector withObject:aConnection];
}


#pragma mark -
#pragma mark REST CRUD Operations

/*! Create object and call given selector
*/
- (void)createAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:self resource:nil method:@"POST" andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didCreateObject:)];
}

/*! Delete object and call given selector
*/
- (void)deleteAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:self resource:nil method:@"DELETE" andCallSelector:aSelector ofObject:anObject customConnectionHandler:nil];
}

/*! Update object and call given selector
*/
- (void)saveAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:self resource:nil method:@"PUT" andCallSelector:aSelector ofObject:anObject customConnectionHandler:nil];
}


#pragma mark -
#pragma mark Advanced REST Operations

/*! Add given entity into given ressource of current object
    for example, to add a NUGroup into a NUEnterprise, you can call
     [anEnterpriese addChildEntity:aGroup resource:@"groups" andCallSelector:nil ofObject:nil]

    @param anEntity the NURESTObject object of add
    @param aSelector the selector to call when complete
    @param anObject the target object
*/
- (void)addChildEntity:(NURESTObject)anEntity andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:anEntity resource:[anEntity RESTResourceName] method:@"POST" andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didAddChildObject:)];
}

/*! Remove given entity from given ressource of current object
    for example, to remove a NUGroup into a NUEnterprise, you can call
     [anEnterpriese removeChildEntity:aGroup andCallSelector:nil ofObject:nil]

    @param anEntity the NURESTObject object of add
    @param aSelector the selector to call when complete
    @param anObject the target object
*/
- (void)removeChildEntity:(NURESTObject)anEntity andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:anEntity resource:[anEntity RESTResourceName] method:@"DELETE" andCallSelector:aSelector ofObject:anObject customConnectionHandler:nil];
}

/*! Low level child manegement. Send given HTTP method with given entity to given ressource of current object
    for example, to remove a NUGroup into a NUEnterprise, you can call
     [anEnterpriese removeChildEntity:aGroup method:NURESTObjectMethodDelete andCallSelector:nil ofObject:nil]

    @param anEntity the NURESTObject object of add
    @param aResource the destination REST resource
    @param aMethod HTTP method
    @param aSelector the selector to call when complete
    @param anObject the target object
    @param aCustomHandler custom handler to call when complete
*/
- (void)manageChildEntity:(NURESTObject)anEntity resource:(CPString)aResource method:(CPString)aMethod andCallSelector:(SEL)aSelector ofObject:(id)anObject customConnectionHandler:(SEL)aCustomHandler
{
    var body = [anEntity objectToJSON],
        request;

    // if we are adding stuff under a NURESTBasicUser, then consider this as root
    if ([self isKindOfClass:NURESTBasicUser])
    {
        var rootURL = [[NURESTLoginController defaultController] URL];
        request = [CPURLRequest requestWithURL:aResource ? [CPURL URLWithString:aResource relativeToURL:rootURL] : rootURL];
    }
    else
        request = [CPURLRequest requestWithURL:aResource ? [CPURL URLWithString:aResource relativeToURL:[self RESTResourceURL]] : [self RESTResourceURL]];

    [request setHTTPMethod:aMethod];
    [request setHTTPBody:body];

    var handlerSelector = aCustomHandler || @selector(_didPerformStandardOperation:);
    [self sendRESTCall:request performSelector:handlerSelector ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:anEntity];
}

/*! Uses this to reference given objects into the given resource of the actual object.
    @param someEntities CPArray containing any subclass of NURESTObject
    @param aResource the destination REST resource
    @param aSelector the selector to call when complete
    @param anObject the target object
*/
- (void)setEntities:(CPArray)someEntities ofClass:(Class)aClass andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    var IDsList = [];

    for (var i = [someEntities count] - 1; i >= 0; i--)
        [IDsList addObject:[someEntities[i] ID]];

    var request = [CPURLRequest requestWithURL:[CPURL URLWithString:[aClass RESTResourceName] relativeToURL:[self RESTResourceURL]]],
        body = JSON.stringify(IDsList, null, 4);

    [request setHTTPMethod:@"PUT"];
    [request setHTTPBody:body];

    [self sendRESTCall:request performSelector:@selector(_didPerformStandardOperation:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:someEntities];
}


#pragma mark -
#pragma mark REST Operation handlers

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
- (void)_didAddChildObject:(NURESTConnection)aConnection
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


@implementation NURESTObject (EXPERIMENTAL)

/*! Create object and call given function
*/
- (void)saveAndCallFunction:(function)aFunction
{
    var URLRequest = [CPURLRequest requestWithURL:[self RESTResourceURL]],
        body = [self objectToJSON];

    [URLRequest setHTTPMethod:@"PUT"];
    [URLRequest setHTTPBody:body];

    [self sendRESTCall:URLRequest performSelector:@selector(_didSaveAndCallFunction:) ofObject:self andPerformRemoteSelector:nil ofObject:nil userInfo:aFunction];
}

- (void)_didSaveAndCallFunction:(NURESTConnection)aConnection
{
    var callback = [aConnection userInfo],
        JSONData = [[aConnection responseData] JSONObject];

    try {[self objectFromJSON:JSONData[0]];} catch(e) {}

    callback(self);
}



/*! Create object and call given function
*/
- (void)createAndCallFunction:(function)aFunction
{
    var URLRequest = [CPURLRequest requestWithURL:[self RESTResourceURL]],
        body = [self objectToJSON];

    [URLRequest setHTTPMethod:@"POST"];
    [URLRequest setHTTPBody:body];

    [self sendRESTCall:URLRequest performSelector:@selector(_didCreateAndCallFunction:) ofObject:self andPerformRemoteSelector:nil ofObject:nil userInfo:aFunction];
}

- (void)_didCreateAndCallFunction:(NURESTConnection)aConnection
{
    var callback = [aConnection userInfo],
        JSONData = [[aConnection responseData] JSONObject];

    try {[self objectFromJSON:JSONData[0]];} catch(e) {}

    callback(self);
}

/*! Create object and call given function
*/
- (void)addChild:(NURESTObject)aChildObject andCallFunction:(function)aFunction
{
    var URLRequest = [CPURLRequest requestWithURL:[CPURL URLWithString:[aChildObject RESTName] + 's' relativeToURL:[self RESTResourceURL]]],
        body = [aChildObject objectToJSON];

    [URLRequest setHTTPMethod:@"POST"];
    [URLRequest setHTTPBody:body];

    [self sendRESTCall:URLRequest performSelector:@selector(_didAddChildAndCallFunction:) ofObject:self andPerformRemoteSelector:nil ofObject:nil userInfo:{"function": aFunction, "child": aChildObject}];
}

- (void)_didAddChildAndCallFunction:(NURESTConnection)aConnection
{
    var callback = [aConnection userInfo]["function"],
        child  = [aConnection userInfo]["child"],
        JSONData = [[aConnection responseData] JSONObject];

    try {[child objectFromJSON:JSONData[0]];} catch(e) {}

    callback(child);
}

@end
