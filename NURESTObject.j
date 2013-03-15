/*
*   Filename:         NURESTObject.j
*   Created:          Tue Oct  9 11:49:46 PDT 2012
*   Author:           Antoine Mercadal <antoine.mercadal@alcatel-lucent.com>
*   Description:      CNA Dashboard
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

NURESTObjectStatusTypeSuccess   = @"SUCCESS";
NURESTObjectStatusTypeWarning   = @"WARNING";
NURESTObjectStatusTypeFailed    = @"FAILED";

@global NUDataTransferController
@global TNAlert
@global CPCriticalAlertStyle
@global NURESTConnectionFailureNotification
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
    CPString        _ID                 @accessors(property=ID);
    CPString        _localID            @accessors(property=localID);
    CPString        _owner              @accessors(property=owner);
    CPString        _parentID           @accessors(property=parentID);
    CPString        _parentType         @accessors(property=parentType);
    CPString        _validationMessage  @accessors(property=validationMessage);

    CPDictionary    _restAttributes     @accessors(property=RESTAttributes);
    CPArray         _bindableAttributes @accessors(property=bindableAttributes);

    NURESTObject    _parentObject       @accessors(property=parentObject);
}


#pragma mark -
#pragma mark Initialization

/*! Initialize the NURESTObject
*/
- (NURESTObject)init
{
    if (self = [super init])
    {
        _restAttributes = [CPDictionary dictionary];
        _bindableAttributes = [CPArray array];
        _localID = [CPString UUID];

        [self exposeLocalKeyPathToREST:@"ID"];
        [self exposeLocalKeyPathToREST:@"parentID"];
        [self exposeLocalKeyPathToREST:@"parentType"];
        [self exposeLocalKeyPathToREST:@"owner"];
        [self exposeLocalKeyPathToREST:@"creationDate"];
    }

    return self;
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
- (void)bindableAttributes
{
    return [[_restAttributes allKeys] arrayByAddingObjectsFromArray:_bindableAttributes];
}

/*! Build current object with given JSONObject
    @param aJSONObject the JSON structure to parse
*/
- (void)objectFromJSON:(CPString)aJSONObject
{
    var obj = aJSONObject;

    for (var i = 0; i < [[_restAttributes allKeys] count]; i++)
    {
        var attribute = [[_restAttributes allKeys] objectAtIndex:i],
            restPath = [_restAttributes objectForKey:attribute],
            restValue;

        // @TODO: this info should come with the HTTP metadata
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
    var json = {};

    for (var i = 0; i < [[_restAttributes allKeys] count]; i++)
    {
        var attribute = [[_restAttributes allKeys] objectAtIndex:i],
            restPath = [_restAttributes objectForKey:attribute],
            value = [self valueForKeyPath:attribute];

        // @TODO: this info should come with the HTTP metadata
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
        [self objectFromJSON:JSONObject[0]];

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

    var connection = [NURESTConnection connectionWithRequest:aRequest
                                                      target:self
                                                    selector:@selector(_didReceiveRESTReply:)];

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

    var url = [[[aConnection request] URL] absoluteString],
        HTTPMethod = [[aConnection request] HTTPMethod],
        responseObject = [[aConnection responseData] JSONObject],
        rawString = [[aConnection responseData] rawString],
        responseCode = [aConnection responseCode],
        localTarget = [aConnection internalUserInfo]["localTarget"],
        localSelector = [aConnection internalUserInfo]["localSelector"];

    CPLog.trace("RESTCAPPUCCINO: <<<< Response for\n\n%@ %@ (%@):\n\n%@", HTTPMethod, url, responseCode, _format_log_json(rawString));

    switch (responseCode)
    {
        // ok or empty
        case NURESTConnectionResponseCodeEmpty:
        case NURESTConnectionResponseCodeSuccess:
        case NURESTConnectionResponseCodeCreated:
            [localTarget performSelector:localSelector withObject:aConnection];
            break;

        // resource not found
        case NURESTConnectionResponseCodeNotFound:
            if (responseObject && responseObject.errors)
            {
                [TNAlert showAlertWithMessage:responseObject.errors[0].descriptions[0].title
                                                  informative:responseObject.errors[0].descriptions[0].description
                                                        style:CPCriticalAlertStyle];
            }
            else
            {
                // [TNAlert showAlertWithMessage:@"404 Error"
                //                   informative:@"URL " + url + " not found."
                //                         style:CPCriticalAlertStyle];
                [localTarget performSelector:localSelector withObject:aConnection];
            }
            break;

        case NURESTConnectionResponseCodePreconditionFailed:
            [TNAlert showAlertWithMessage:@"412 Error"
                              informative:@"Header precondition failed for " + url + ". Please report this error back."
                                    style:CPCriticalAlertStyle];
            [localTarget performSelector:localSelector withObject:aConnection];
            break;

        // Bad request
        case NURESTConnectionResponseBadRequest:
        [TNAlert showAlertWithMessage:@"400 Error"
                          informative:@"Server responded with a bad request for " + url + ". Please report this error back."
                                style:CPCriticalAlertStyle];
        [localTarget performSelector:localSelector withObject:aConnection];
        break;

        // internal server error
        case NURESTConnectionResponseCodeInternalServerError:
            [TNAlert showAlertWithMessage:responseObject.errors[0].descriptions[0].title
                              informative:responseObject.errors[0].descriptions[0].description
                                    style:CPCriticalAlertStyle];
            CPLog.error("RESTCAPPUCCINO: Stack Trace (%@): %@", responseObject.internalErrorCode, responseObject.stackTrace);
            break;

        // multiple choice
        case NURESTConnectionResponseCodeMultipleChoices:
            var availableChoices = [];

            for (var i = 0; i < responseObject.choices.length; i++)
                [availableChoices addObject:[responseObject.choices[i].label, nil]];

            var confirmAlert = [TNAlert alertWithMessage:responseObject.errors[0].descriptions[0].title
                                      informative:responseObject.errors[0].descriptions[0].description
                                           target:self
                                          actions:availableChoices];

            [confirmAlert setUserInfo:{"connection": aConnection, "choices": responseObject.choices}];
            [confirmAlert setDelegate:self];
            [confirmAlert runModal];
            break;

        // Not authorized
        case NURESTConnectionResponseCodeUnauthorized:
            // in that case we just forward the connection to let traget deal with it
            [localTarget performSelector:localSelector withObject:aConnection];
            break;

        // Server Validation Error
        case NURESTConnectionResponseCodeConflict:
            // in that case we just forward the connection to let login manager deal with it
            [localTarget performSelector:localSelector withObject:aConnection];
            break;

        // XMLHTTPREQUEST error
        case NURESTConnectionResponseCodeZero:
            CPLog.error("RESTCAPPUCCINO: Connection error with code 0. Sending NURESTConnectionFailureNotification notification and exiting.");
            [[CPNotificationCenter defaultCenter] postNotificationName:NURESTConnectionFailureNotification
                                                        object:self
                                                     userInfo:nil];
            break;

        default:
            var title = @"Unknown response code",
                informative = @"The server send an unknown response code:  " + responseCode;
            [TNAlert showAlertWithMessage:title informative:informative style:CPCriticalAlertStyle];
            CPLog.error(@"RESTCAPPUCCINO: %@: %@\n\n%@", title, informative, [[aConnection responseData] rawString]);
    }
}

/*! @ignore
    Reprocess the URL to add ?validate=false if needed
*/
- (void)alertDidEnd:(CPAlert)theAlert returnCode:(int)returnCode
{
    var connection = [theAlert userInfo].connection,
        choices = [theAlert userInfo].choices,
        request = [[CPURLRequest alloc] init],
        selectedChoiceID = [choices objectAtIndex:returnCode].id;

    if (!selectedChoiceID)
        return;

    [request setURL:[CPURL URLWithString:[[[connection request] URL] absoluteString] + "?responseChoice=" + selectedChoiceID]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:[[connection request] HTTPMethod]];
    [request setHTTPBody:[[connection request] HTTPBody]];

    [connection setRequest:request];
    [connection reset];
    [connection start];
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
    for (var i = 0 ; i < [someEntities count]; i++)
        [IDsList addObject:[[someEntities objectAtIndex:i] ID]];

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
        _restAttributes     = [aCoder decodeObjectForKey:@"_restAttributes"];
        _bindableAttributes = [aCoder decodeObjectForKey:@"_bindableAttributes"];
        _ID                 = [aCoder decodeObjectForKey:@"_ID"];
        _localID            = [aCoder decodeObjectForKey:@"_localID"];
        _parentID           = [aCoder decodeObjectForKey:@"_parentID"];
        _parentType         = [aCoder decodeObjectForKey:@"_parentType"];
        _validationMessage  = [aCoder decodeObjectForKey:@"_validationMessage"];
        _parentObject       = [aCoder decodeObjectForKey:@"_parentObject"];
    }

    return self;
}

/*! CPCoder compliance
*/
- (void)encodeWithCoder:(CPCoder)aCoder
{
    [aCoder encodeObject:_restAttributes forKey:@"_restAttributes"];
    [aCoder encodeObject:_bindableAttributes forKey:@"_bindableAttributes"];
    [aCoder encodeObject:_ID forKey:@"_ID"];
    [aCoder encodeObject:_localID forKey:@"_localID"];
    [aCoder encodeObject:_parentID forKey:@"_parentID"];
    [aCoder encodeObject:_parentType forKey:@"_parentType"];
    [aCoder encodeObject:_validationMessage forKey:@"_validationMessage"];
    [aCoder encodeObject:_parentObject forKey:@"_parentObject"];
}

@end

