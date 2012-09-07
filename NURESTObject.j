/*
****************************************************************************
*
*   Filename:         NURESTObject.j
*
*   Created:          Mon Apr  2 11:23:45 PST 2012
*
*   Description:      Cappuccino UI
*
*   Project:          Cloud Network Automation - Nuage - Data Center Service Delivery - IPD
*
*
***************************************************************************
*
*                 Source Control System Information
*
*   $Id: something $
*
*
*
****************************************************************************
*
* Copyright (c) 2011-2012 Alcatel, Alcatel-Lucent, Inc. All Rights Reserved.
*
* This source code contains confidential information which is proprietary to Alcatel.
* No part of its contents may be used, copied, disclosed or conveyed to any party
* in any manner whatsoever without prior written permission from Alcatel.
*
* Alcatel-Lucent is a trademark of Alcatel-Lucent, Inc.
*
*
*****************************************************************************
*/

@import <Foundation/CPURLConnection.j>

NURESTObjectStatusTypeSuccess   = @"SUCCESS";
NURESTObjectStatusTypeWarning   = @"WARNING";
NURESTObjectStatusTypeFailed    = @"FAILED";

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

    CPDictionary    _restAttributes     @accessors(property=RESTAttributes);
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

        [self exposeLocalKeyPath:@"ID" toRESTKeyPath:@"id"];
        [self exposeLocalKeyPath:@"parentID" toRESTKeyPath:@"parentId"];
        [self exposeLocalKeyPath:@"parentType" toRESTKeyPath:@"parentType"];
        [self exposeLocalKeyPath:@"owner" toRESTKeyPath:@"createdBy"];
        [self exposeLocalKeyPath:@"creationDate" toRESTKeyPath:@"creationDate"];
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
            restValue = [CPDate dateWithTimeIntervalSince1970:obj[restPath]];
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

    return JSON.stringify(json);
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
    [self fetchAndCallSelector:nil ofObject:nil userInfo:nil]
}

/*! Fetchs object attributes. This requires that the Cappuccino object has a valid ID
    @param aSelector the selector to use when fetching is ok
    @param anObject the target to send the selector
*/
- (void)fetchAndCallSelector:(SEL)aSelector ofObject:(id)anObject userInfo:(id)someUserInfo
{
    if (!_ID)
        [CPException raise:CPInvalidArgumentException reason:@"Cannot fetch object if not ID is set"];

    var request = [CPURLRequest requestWithURL:[self RESTQueryURL]],
        someUserInfo = (aSelector && anObject) ? [anObject, aSelector, someUserInfo] : nil;

    [self sendRESTCall:request andPerformSelector:@selector(_didFetchMySelf:) ofObject:self userInfo:someUserInfo];
}

/*! @ignore
*/
- (void)_didFetchMySelf:(CPURLConnection)aConnection
{
    var JSONObject = [[aConnection responseData] JSONObject];

    [self objectFromJSON:JSONObject[0]];

    if ([aConnection userInfo])
        [[aConnection userInfo][0] performSelector:[aConnection userInfo][1] withObject:self withObject:[aConnection userInfo][2]];
}


#pragma mark -
#pragma mark REST Low Level communication

/*! Send a REST request and perform given selector of given object
    @param aRequest random CPURLRequest
    @param aSelector the selector to execute when complete
    @param anObject the target object
*/
- (void)sendRESTCall:(CPURLRequest)aRequest andPerformSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self sendRESTCall:aRequest andPerformSelector:aSelector ofObject:anObject userInfo:nil];
}

/*! Send a REST request and perform given selector of given object
    @param aRequest random CPURLRequest
    @param aSelector the selector to execute when complete
    @param anObject the target object
    @param userInfo random userInfo
*/
- (void)sendRESTCall:(CPURLRequest)aRequest andPerformSelector:(SEL)aSelector ofObject:(id)anObject userInfo:(id)someUserInfo
{
    var connection = [NURESTConnection connectionWithRequest:aRequest
                                                     target:self
                                                     selector:@selector(_didReceiveRESTReply:)];
    [connection setInternalUserInfo:[anObject, aSelector]];
    [connection setUserInfo:someUserInfo];
    if (typeof(NUDataTransferController) != "undefined")
        [[NUDataTransferController defaultDataTransferController] showDataTransfer];

    CPLog.debug(">>>> Sending " + [[aRequest URL] absoluteString] + " (" + [aRequest HTTPMethod] + ")");
    [connection start];
}

/*! @ignore
*/
- (void)_didReceiveRESTReply:(NURESTConnection)aConnection
{
    // @TODO, send a notification instead
    if (typeof(NUDataTransferController) != "undefined")
        [[NUDataTransferController defaultDataTransferController] hideDataTransfer];

    var url = [[[aConnection request] URL] absoluteString],
        HTTPMethod = [[aConnection request] HTTPMethod],
        responseObject = [[aConnection responseData] JSONObject],
        rawString = [[aConnection responseData] rawString],
        responseCode = [aConnection responseCode];

    CPLog.debug("<<<< Response for %@ %@ (%@): %@", HTTPMethod, url, responseCode, rawString);

    switch (responseCode)
    {
        // ok or empty
        case NURESTConnectionResponseCodeEmpty:
        case NURESTConnectionResponseCodeSuccess:
        case NURESTConnectionResponseCodeCreated:
            [[aConnection internalUserInfo][0] performSelector:[aConnection internalUserInfo][1] withObject:aConnection];
            break;

        // resource not found
        case NURESTConnectionResponseCodeNotFound:
            [TNAlert showAlertWithMessage:@"404 Error"
                              informative:@"URL " + url + " not found."
                                    style:CPCriticalAlertStyle];
            break;

        // internal server error
        case NURESTConnectionResponseCodeInternalServerError:
            [TNAlert showAlertWithMessage:responseObject.title
                              informative:responseObject.description
                                    style:CPCriticalAlertStyle];
            CPLog.error("Stack Trace (%@): %@", responseObject.internalErrorCode, responseObject.stackTrace);
            break;

        // multiple choice
        case NURESTConnectionResponseCodeMultipleChoices:
            var availableChoices = [];

            for (var i = 0; i < responseObject.choices.length; i++)
                [availableChoices addObject:[responseObject.choices[i].label, nil]];

            var confirmAlert = [TNAlert alertWithMessage:responseObject.title
                                      informative:responseObject.description
                                           target:self
                                          actions:availableChoices];

            [confirmAlert setUserInfo:{"connection": aConnection, "choices": responseObject.choices}];
            [confirmAlert setDelegate:self];
            [confirmAlert runModal];
            break;

        // Not authorized
        case NURESTConnectionResponseCodeUnauthorized:
            // in that case we just forward the connection to let login manager deal with it
            [[aConnection internalUserInfo][0] performSelector:[aConnection internalUserInfo][1] withObject:aConnection];
            break;

        // XMLHTTPREQUEST error
        case NURESTConnectionResponseCodeZero:
            // do nothing.
            break;

        default:
            var title = @"Unknown response code",
                informative = @"The server send an unknown response code:  " + responseCode;
            [TNAlert showAlertWithMessage:title informative:informative style:CPCriticalAlertStyle];
            CPLog.error(title + " : " + informative + " :" +[[aConnection responseData] JSONObject].status.detailedMessage);
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

    [request setHTTPMethod:[[connection request] HTTPMethod]];
    if (typeof(NUDataTransferController) != "undefined")
        [[NUDataTransferController defaultDataTransferController] showDataTransfer];
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
    [self manageChildEntity:anEntity intoResource:aResource method:@"POST" andCallSelector:aSelector ofObject:anObject];
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
    var URLRequest = [CPURLRequest requestWithURL:[CPURL URLWithString:aResource relativeToURL:[self RESTQueryURL]]],
        body = [anEntity objectToJSON];

    [URLRequest setHTTPMethod:aMethod];
    [URLRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [URLRequest setHTTPBody:body];

    CPLog.debug("Sending method %s to URL %s: %s ", aMethod, [URLRequest URL], body);

    [self sendRESTCall:URLRequest andPerformSelector:aCustomHandler ofObject:self userInfo:[anObject, aSelector]];
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

    var URLRequest = [CPURLRequest requestWithURL:[CPURL URLWithString:aResource relativeToURL:[self RESTQueryURL]]],
        body = JSON.stringify(IDsList);

    [URLRequest setHTTPMethod:@"PUT"];
    [URLRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [URLRequest setHTTPBody:body];

    CPLog.debug("Sending method PUT to URL %s: %s ", [URLRequest URL], body);

    [self sendRESTCall:URLRequest andPerformSelector:@selector(_didPerformStandardOperation:) ofObject:self userInfo:[anObject, aSelector]];
}


#pragma mark -
#pragma mark REST Operation handlers

/*! Called as a custom handler when creating a new object
*/
- (void)_didCreateObject:(NURESTConnection)aConnection
{
    var JSONData = [[aConnection responseData] JSONObject];
    try
    {
        [self objectFromJSON:JSONData[0]];
    }
    catch(e)
    {
        var title = "Error while creating object of kind " + [self class],
            informative = [[aConnection responseData] rawString];
        CPLog.error(title + " : " + informative + " - EXCEPTION " + e);
        [TNAlert showAlertWithMessage:title informative:informative style:CPCriticalAlertStyle];
        return;
    }
    CPLog.debug("Creation complete. Object is now: " + [self objectToJSON]);

    [self _didPerformStandardOperation:aConnection];
}

/*! Standard handler called when managing a child object
*/
- (void)_didPerformStandardOperation:(NURESTConnection)aConnection
{
    if ([aConnection userInfo][0] && [aConnection userInfo][1]);
        [[aConnection userInfo][0] performSelector:[aConnection userInfo][1] withObject:self];
}


#pragma mark -
#pragma mark CPCoding

/*! CPCoder compliance
*/
- (id)initWithCoder:(CPCoder)aCoder
{
    if (self = [super init])
    {
        _restAttributes = [aCoder decodeObjectForKey:@"_restAttributes"];
        _ID             = [aCoder decodeObjectForKey:@"_ID"];
        _localID        = [aCoder decodeObjectForKey:@"_localID"];
        _parentID       = [aCoder decodeObjectForKey:@"_parentID"];
        _parentType     = [aCoder decodeObjectForKey:@"_parentType"];

    }

    return self;
}

/*! CPCoder compliance
*/
- (void)encodeWithCoder:(CPCoder)aCoder
{
    [aCoder encodeObject:_restAttributes forKey:@"_restAttributes"];
    [aCoder encodeObject:_ID forKey:@"_ID"];
    [aCoder encodeObject:_localID forKey:@"_localID"];
    [aCoder encodeObject:_parentID forKey:@"_parentID"];
    [aCoder encodeObject:_parentType forKey:@"_parentType"];
}

@end

