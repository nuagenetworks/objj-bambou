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
    CPDate          _creationDate       @accessors(property=creationDate);
    CPString        _externalID         @accessors(property=externalID);
    CPString        _ID                 @accessors(property=ID);
    CPString        _localID            @accessors(property=localID);
    CPString        _owner              @accessors(property=owner);
    CPString        _parentID           @accessors(property=parentID);
    CPString        _parentType         @accessors(property=parentType);
    CPString        _validationMessage  @accessors(property=validationMessage);

    CPDictionary    _restAttributes     @accessors(property=RESTAttributes);
    CPArray         _bindableAttributes @accessors(property=bindableAttributes);

    NURESTObject    _parentObject       @accessors(property=parentObject);

    CPArray         _childrenLists;
}


#pragma mark -
#pragma mark Initialization

/*! Initialize the NURESTObject
*/
- (id)init
{
    if (self = [super init])
    {
        _restAttributes = [CPDictionary dictionary];
        _bindableAttributes = [CPArray array];
        _localID = [CPString UUID];

        [self exposeLocalKeyPathToREST:@"ID"];
        [self exposeLocalKeyPathToREST:@"externalID"];
        [self exposeLocalKeyPathToREST:@"parentID"];
        [self exposeLocalKeyPathToREST:@"parentType"];
        [self exposeLocalKeyPathToREST:@"owner"];
        [self exposeLocalKeyPathToREST:@"creationDate"];
    }

    return self;
}


#pragma mark -
#pragma mark  Memory Management

- (void)discard
{
    [self discardChildren];
    _parentObject = nil;
    _childrenLists = nil;

    delete self;
}

- (void)discardChildren
{
    for (var i = [_childrenLists count] - 1; i >= 0; i--)
    {
        var children = _childrenLists[i];
        [children makeObjectsPerformSelector:@selector(discard)];
    }
}

- (void)registerChildrenList:(CPArray)aList
{
    [_childrenLists addObject:aList];
}

#pragma mark -
#pragma mark REST configuration

/*! Builds the base query URL to manage this object
    this must be overiden by subclasses
    @return a CPURL representing the REST endpoint to manage this object
*/
- (CPURL)RESTQueryURL
{
    return [[NURESTLoginController defaultController] URL];
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
    [_restAttributes setObject:aRestKeyPath forKey:aKeyPath];
}

/*! Same as exposeLocalKeyPath:toRESTKeyPath:. Difference is that the rest keypath
    will be the same than the local key path
    @param aKeyPath the local key path to expose
*/
- (void)exposeLocalKeyPathToREST:(CPString)aKeyPath
{
    [self exposeLocalKeyPath:aKeyPath toRESTKeyPath:aKeyPath];
}

/*! Expose some property that are bindable, but not from the model.
    This is usefull when you want to automatize binding of transformed properties.
*/
- (void)exposeBindableAttribute:(CPString)aKeyPath
{
    [_bindableAttributes addObject:aKeyPath];
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
- (void)objectFromJSON:(CPString)aJSONObject
{
    var obj = aJSONObject,
        keys = [_restAttributes allKeys];

    for (var i = [keys count] - 1; i >= 0; i--)
    {
        var attribute = keys[i],
            restPath = [_restAttributes objectForKey:attribute],
            restValue;

        if (attribute == "creationDate")
            restValue = [CPDate dateWithTimeIntervalSince1970:(parseInt(obj[restPath]) / 1000)];
        else
            restValue = obj[restPath];
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

- (BOOL)isEqual:(NURESTObject)anEntity
{
    if (_ID)
        return ([self ID] == [anEntity ID]);
    else if (_localID)
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
    var request = [CPURLRequest requestWithURL:[self RESTQueryURL]];

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
        [[CPNotificationCenter defaultCenter] postNotificationName:NURESTConnectionFailureNotification
                                                            object:self
                                                          userInfo:aConnection];
         return;
    }

    var url            = [[[aConnection request] URL] absoluteString],
        HTTPMethod     = [[aConnection request] HTTPMethod],
        responseObject = [[aConnection responseData] JSONObject],
        rawString      = [[aConnection responseData] rawString],
        responseCode   = [aConnection responseCode],
        localTarget    = [aConnection internalUserInfo]["localTarget"],
        localSelector  = [aConnection internalUserInfo]["localSelector"],
        remoteTarget    = [aConnection internalUserInfo]["remoteTarget"],
        remoteSelector  = [aConnection internalUserInfo]["remoteSelector"],
        localyManagedConflict = NO;

    CPLog.trace("RESTCAPPUCCINO: <<<< Response for\n\n%@ %@ (%@):\n\n%@", HTTPMethod, url, responseCode, _format_log_json(rawString));

    switch (responseCode)
    {
        case NURESTConnectionResponseCodeEmpty:
        case NURESTConnectionResponseCodeSuccess:
        case NURESTConnectionResponseCodeCreated:
            [localTarget performSelector:localSelector withObject:aConnection];
            break;

        case NURESTConnectionResponseCodeMultipleChoices:
            var confirmName = responseObject.errors[0].descriptions[0].title,
                confirmDescription = responseObject.errors[0].descriptions[0].description,
                confirmChoices = responseObject.choices;

            [NURESTConfirmation postRESTConfirmationWithName:confirmName description:confirmDescription choices:confirmChoices connection:aConnection];
            break;

        case NURESTConnectionResponseCodeUnauthorized:
            [localTarget performSelector:localSelector withObject:aConnection];
            break;

        case NURESTConnectionResponseCodeConflict:
            // Here is a little bit of assumption. We received a conflict, but we have no remote selector to call
            // This certainly means that this error will remain unknown to the user. So we take the call, and
            // we push a NURESTError about it. Because we are cool guys. And we love you. Don't thank us, it's natural
            if (!remoteTarget || !remoteSelector)
                localyManagedConflict = YES; // as we don't break here, it will trigger the next test case.
            else
            {
                [localTarget performSelector:localSelector withObject:aConnection];
                break;
            }

        case localyManagedConflict:
        case NURESTConnectionResponseCodeNotFound:
        case NURESTConnectionResponseCodeMethodNotAllowed:
        case NURESTConnectionResponseCodePreconditionFailed:
        case NURESTConnectionResponseBadRequest:
        case NURESTConnectionResponseCodeInternalServerError:
            var containsInfo = (responseObject && responseObject.errors),
                errorName = containsInfo? responseObject.errors[0].descriptions[0].title : @"Unknown error",
                errorDescription = containsInfo ? responseObject.errors[0].descriptions[0].description : @"Please check the log for more information about this error";

            [NURESTError postRESTErrorWithName:errorName description:errorDescription connection:aConnection];

            [localTarget performSelector:localSelector withObject:aConnection];
            break;

        case NURESTConnectionResponseCodeZero:
            CPLog.error("RESTCAPPUCCINO: Connection error with code 0. Sending NURESTConnectionFailureNotification notification and exiting.");
            [[CPNotificationCenter defaultCenter] postNotificationName:NURESTConnectionFailureNotification
                                                                object:self
                                                              userInfo:nil];
            break;

        default:
            CPLog.error(@"RESTCAPPUCCINO: Report this error, because this should not happen:\n\n%@", [[aConnection responseData] rawString]);
    }
}


#pragma mark -
#pragma mark REST CRUD Operations

/*! Create object and call given selector
*/
- (void)createAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:self intoResource:nil method:@"POST" andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didCreateObject:)];
}

/*! Delete object and call given selector
*/
- (void)deleteAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:self intoResource:nil method:@"DELETE" andCallSelector:aSelector ofObject:anObject];
}

/*! Update object and call given selector
*/
- (void)saveAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:self intoResource:nil method:@"PUT" andCallSelector:aSelector ofObject:anObject];
}


#pragma mark -
#pragma mark Advanced REST Operations

/*! Add given entity into given ressource of current object
    for example, to add a NUGroup into a NUEnterprise, you can call
     [anEnterpriese addChildEntity:aGroup intoResource:@"groups" andCallSelector:nil ofObject:nil]

    @param anEntity the NURESTObject object of add
    @param aResource the destination REST resource
    @param aSelector the selector to call when complete
    @param anObject the target object
*/
- (void)addChildEntity:(NURESTObject)anEntity intoResource:(CPString)aResource andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:anEntity intoResource:aResource method:@"POST" andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didAddChildObject:)];
}

/*! Remove given entity from given ressource of current object
    for example, to remove a NUGroup into a NUEnterprise, you can call
     [anEnterpriese removeChildEntity:aGroup fromResource:@"groups" andCallSelector:nil ofObject:nil]

    @param anEntity the NURESTObject object of add
    @param aResource the destination REST resource
    @param aSelector the selector to call when complete
    @param anObject the target object
*/
- (void)removeChildEntity:(NURESTObject)anEntity fromResource:(CPString)aResource andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:anEntity intoResource:aResource method:@"DELETE" andCallSelector:aSelector ofObject:anObject];
}

/*! Low level child manegement. Send given HTTP method with given entity to given ressource of current object
    for example, to remove a NUGroup into a NUEnterprise, you can call
     [anEnterpriese removeChildEntity:aGroup fromResource:@"groups" method:NURESTObjectMethodDelete andCallSelector:nil ofObject:nil]

    @param anEntity the NURESTObject object of add
    @param aResource the destination REST resource
    @param aMethod HTTP method
    @param aSelector the selector to call when complete
    @param anObject the target object
*/
- (void)manageChildEntity:(NURESTObject)anEntity intoResource:(CPString)aResource method:(CPString)aMethod andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self manageChildEntity:anEntity intoResource:aResource method:aMethod andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didPerformStandardOperation:)];
}

/*! Low level child manegement. Send given HTTP method with given entity to given ressource of current object
    for example, to remove a NUGroup into a NUEnterprise, you can call
     [anEnterpriese removeChildEntity:aGroup fromResource:@"groups" method:NURESTObjectMethodDelete andCallSelector:nil ofObject:nil]

    @param anEntity the NURESTObject object of add
    @param aResource the destination REST resource
    @param aMethod HTTP method
    @param aSelector the selector to call when complete
    @param anObject the target object
    @param aCustomHandler custom handler to call when complete
*/
- (void)manageChildEntity:(NURESTObject)anEntity intoResource:(CPString)aResource method:(CPString)aMethod andCallSelector:(SEL)aSelector ofObject:(id)anObject customConnectionHandler:(SEL)aCustomHandler
{
    var URLRequest = [CPURLRequest requestWithURL:aResource ? [CPURL URLWithString:aResource relativeToURL:[self RESTQueryURL]] : [self RESTQueryURL]],
        body = [anEntity objectToJSON];

    [URLRequest setHTTPMethod:aMethod];
    [URLRequest setHTTPBody:body];

    [self sendRESTCall:URLRequest performSelector:aCustomHandler ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:anEntity];
}

/*! Uses this to reference given objects into the given resource of the actual object.
    @param someEntities CPArray containing any subclass of NURESTObject
    @param aResource the destination REST resource
    @param aSelector the selector to call when complete
    @param anObject the target object
*/
- (void)setEntities:(CPArray)someEntities intoResource:(CPString)aResource andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    var IDsList = [];

    for (var i = [someEntities count] - 1; i >= 0; i--)
        [IDsList addObject:[someEntities[i] ID]];

    var URLRequest = [CPURLRequest requestWithURL:aResource ? [CPURL URLWithString:aResource relativeToURL:[self RESTQueryURL]] : [self RESTQueryURL]],
        body = JSON.stringify(IDsList, null, 4);

    [URLRequest setHTTPMethod:@"PUT"];
    [URLRequest setHTTPBody:body];

    [self sendRESTCall:URLRequest performSelector:@selector(_didPerformStandardOperation:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:someEntities];
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
    if (self = [super init])
    {
        _bindableAttributes = [aCoder decodeObjectForKey:@"_bindableAttributes"];
        _externalID         = [aCoder decodeObjectForKey:@"_externalID"];
        _ID                 = [aCoder decodeObjectForKey:@"_ID"];
        _localID            = [aCoder decodeObjectForKey:@"_localID"];
        _parentID           = [aCoder decodeObjectForKey:@"_parentID"];
        _parentObject       = [aCoder decodeObjectForKey:@"_parentObject"];
        _parentType         = [aCoder decodeObjectForKey:@"_parentType"];
        _restAttributes     = [aCoder decodeObjectForKey:@"_restAttributes"];
        _validationMessage  = [aCoder decodeObjectForKey:@"_validationMessage"];
        _owner              = [aCoder decodeObjectForKey:@"_owner"];
    }

    return self;
}

/*! CPCoder compliance
*/
- (void)encodeWithCoder:(CPCoder)aCoder
{
    [aCoder encodeObject:_bindableAttributes forKey:@"_bindableAttributes"];
    [aCoder encodeObject:_externalID forKey:@"_externalID"];
    [aCoder encodeObject:_ID forKey:@"_ID"];
    [aCoder encodeObject:_localID forKey:@"_localID"];
    [aCoder encodeObject:_parentID forKey:@"_parentID"];
    [aCoder encodeObject:_parentObject forKey:@"_parentObject"];
    [aCoder encodeObject:_parentType forKey:@"_parentType"];
    [aCoder encodeObject:_restAttributes forKey:@"_restAttributes"];
    [aCoder encodeObject:_validationMessage forKey:@"_validationMessage"];
    [aCoder encodeObject:_owner forKey:@"_owner"];
}

@end


@implementation NURESTObject (EXPERIMENTAL)

/*! Create object and call given function
*/
- (void)saveAndCallFunction:(function)aFunction
{
    var URLRequest = [CPURLRequest requestWithURL:[self RESTQueryURL]],
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
    var URLRequest = [CPURLRequest requestWithURL:[self RESTQueryURL]],
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
    var URLRequest = [CPURLRequest requestWithURL:[CPURL URLWithString:[aChildObject RESTName] + 's' relativeToURL:[self RESTQueryURL]]],
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
