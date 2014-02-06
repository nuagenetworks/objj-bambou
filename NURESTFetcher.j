/*
*   Filename:         NURESTFetcher.j
*   Created:          Tue Oct  9 11:49:36 PDT 2012
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

@global NURESTBasicUser
@global NURESTLoginController

@implementation NURESTFetcher : CPObject
{
    CPArray             _groupedBy              @accessors(property=groupedBy);
    CPNumber            _latestLoadedPage       @accessors(property=latestLoadedPage);
    CPNumber            _pageSize               @accessors(property=pageSize);
    CPNumber            _totalCount             @accessors(property=totalCount);
    CPPredicate         _masterFilter           @accessors(property=masterFilter);
    CPString            _destinationKeyPath     @accessors(property=destinationKeyPath);
    CPString            _restName               @accessors(property=restName);
    CPString            _transactionID          @accessors(property=transactionID);
    id                  _entity                 @accessors(property=entity);
    NURESTConnection    _lastConnection         @accessors(property=lastConnection);

    CPString            _orderedBy;
}

- (void)flush
{
    [[_entity valueForKeyPath:_destinationKeyPath] removeAllObjects];
}

- (id)newObject
{
    return nil;
}

- (void)_prepareHeadersForRequest:(CPURLRequest)aRequest withFilter:(id)aFilter page:(CPNumber)aPage
{
    if (_masterFilter)
        [aRequest setValue:[_masterFilter predicateFormat] forHTTPHeaderField:@"X-Nuage-Filter"];
    else if ([aFilter isKindOfClass:CPPredicate])
        [aRequest setValue:[aFilter predicateFormat] forHTTPHeaderField:@"X-Nuage-Filter"];
    else if ([aFilter isKindOfClass:CPString])
        [aRequest setValue:aFilter forHTTPHeaderField:@"X-Nuage-Filter"];

    if (aPage !== nil)
        [aRequest setValue:aPage forHTTPHeaderField:@"X-Nuage-Page"];

    if (_groupedBy)
    {
        var headerString = @"";
        for (var i = 0, c = [_groupedBy count]; i < c; i++)
        {
            headerString += _groupedBy[i];
            if (i + 1 < c)
                headerString += @", ";
        }

        [aRequest setValue:@"true" forHTTPHeaderField:@"X-Nuage-GroupBy"];
        [aRequest setValue:headerString forHTTPHeaderField:@"X-Nuage-Attributes"];
    }
}

- (void)fetchObjectsAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self fetchObjectsMatchingFilter:nil page:nil andCallSelector:aSelector ofObject:anObject];
}

- (void)fetchObjectsMatchingFilter:(id)aFilter page:(CPNumber)aPage andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    var request;
    if ([_entity isKindOfClass:NURESTBasicUser])
        request = [CPURLRequest requestWithURL:[CPURL URLWithString:_restName relativeToURL:[[NURESTLoginController defaultController] URL]]];
    else
        request = [CPURLRequest requestWithURL:[CPURL URLWithString:_restName relativeToURL:[_entity RESTResourceURL]]];

    [request setHTTPMethod:@"GET"];

    [self _prepareHeadersForRequest:request withFilter:aFilter page:aPage];

    _transactionID = [CPString UUID];
    [_entity sendRESTCall:request performSelector:@selector(_didFetchObjects:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:nil];

    return _transactionID;
}

/*! @ignore
*/
- (void)_didFetchObjects:(NURESTConnection)aConnection
{
    _lastConnection = aConnection;

    if ([aConnection responseCode] != 200)
    {
        _totalCount = 0;
        _pageSize = 0;
        _latestLoadedPage = 0;
        _orderedBy = @"";
        [self _sendContent:nil usingConnection:aConnection];
        return;
    }

    var JSONObject = [[aConnection responseData] JSONObject],
        dest = [_entity valueForKey:_destinationKeyPath],
        newlyFetchedObjects = [CPArray array];

    _totalCount = parseInt([aConnection nativeRequest].getResponseHeader("X-Nuage-Count"));
    _pageSize = parseInt([aConnection nativeRequest].getResponseHeader("X-Nuage-PageSize"));
    _latestLoadedPage = parseInt([aConnection nativeRequest].getResponseHeader("X-Nuage-Page"));
    _orderedBy = [aConnection nativeRequest].getResponseHeader("X-Nuage-OrderBy");

    for (var i = 0, c = [JSONObject count]; i < c; i++)
    {
        var newObject = [self newObject];

        [newObject objectFromJSON:JSONObject[i]];
        [newObject setParentObject:_entity];

        if (![dest containsObject:newObject])
            [dest addObject:newObject];

        [newlyFetchedObjects addObject:newObject];
    }

    // @TODO: wy sending a copy? I should be better to directly pass the dest. It should be working by now.
    // @EDIT: Actually, I'm not sure. This is used as datasource content, and removing stuff from datasource
    // will remove it from the RESTObject array, and that could cause some weird error. I need to deeply check
    // if it is safe or not to simply give the destination array... wait and see
    [self _sendContent:newlyFetchedObjects usingConnection:aConnection];
}

- (void)countObjectsAndCallSelector:(SEL)aSelector ofObject:(id)anObject matchingFilter:(CPPredicate)aFilter
{
    var request = [CPURLRequest requestWithURL:[CPURL URLWithString:_restName relativeToURL:[_entity RESTResourceURL]]];

    [request setHTTPMethod:@"HEAD"];

    [self _prepareHeadersForRequest:request withFilter:aFilter page:nil];

    [_entity sendRESTCall:request performSelector:@selector(_didCountObjects:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:nil];
}

- (void)_didCountObjects:(NURESTConnection)aConnection
{
    var count = parseInt([aConnection nativeRequest].getResponseHeader("X-Nuage-Count")),
        target = [aConnection internalUserInfo]["remoteTarget"],
        selector = [aConnection internalUserInfo]["remoteSelector"];

    // should be - (void)fetcher:ofObject:didCountContent: or something like that
    [target performSelector:selector withObjects:self, _entity, count];
}

- (void)_sendContent:(CPArray)someContent usingConnection:(NURESTConnection)aConnection
{
    if (aConnection)
    {
        var target = [aConnection internalUserInfo]["remoteTarget"],
            selector = [aConnection internalUserInfo]["remoteSelector"];

        // should be - (void)fetcher:ofObject:didCountContent: or something like that
        [target performSelector:selector withObjects:self, _entity, someContent];
    }
}

- (CPArray)latestSortDescriptors
{
    if (!_orderedBy)
        return;

    var descriptors = [CPArray array],
        elements = _orderedBy.split(",");

    for (var i = 0, c = [elements count]; i < c; i++)
    {
        var tokens = elements[i].split(" "),
            descriptor = [CPSortDescriptor sortDescriptorWithKey:tokens[0]
                                                       ascending:(tokens[1] == "ASC")
                                                        selector:@selector(caseInsensitiveCompare:)];

        [descriptors addObject:descriptor];
    }

    return descriptors;
}

- (void)countObjectsAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self countObjectsAndCallSelector:aSelector ofObject:anObject matchingFilter:nil];
}

@end
