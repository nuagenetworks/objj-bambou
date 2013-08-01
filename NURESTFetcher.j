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

@implementation NURESTFetcher : CPObject
{
    CPNumber            _latestLoadedPage       @accessors(property=latestLoadedPage);
    CPNumber            _pageSize               @accessors(property=pageSize);
    CPNumber            _totalCount             @accessors(property=totalCount);
    CPObject            _entity                 @accessors(property=entity);
    CPString            _destinationKeyPath     @accessors(property=destinationKeyPath);
    CPString            _restName               @accessors(property=restName);
    CPString            _transactionID          @accessors(property=transactionID);
    NURESTConnection    _lastConnection         @accessors(property=lastConnection);

    CPString            _orderedBy;
}

- (void)flush
{
    [[_entity valueForKey:_destinationKeyPath] removeAllObjects];
}

- (id)newObject
{
    return nil;
}

- (void)fetchObjectsAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self fetchObjectsMatchingFilter:nil page:nil andCallSelector:aSelector ofObject:anObject];
}

- (void)fetchObjectsMatchingFilter:(id)aFilter page:(CPNumber)aPage andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    var request = [CPURLRequest requestWithURL:[CPURL URLWithString:_restName relativeToURL:[_entity RESTQueryURL]]];

    [request setHTTPMethod:@"GET"];

    if ([aFilter isKindOfClass:CPPredicate])
        [request setValue:[aFilter predicateFormat] forHTTPHeaderField:@"X-Nuage-Filter"];
    else if ([aFilter isKindOfClass:CPString])
        [request setValue:aFilter forHTTPHeaderField:@"X-Nuage-Filter"];

    if (aPage !== nil)
        [request setValue:aPage forHTTPHeaderField:@"X-Nuage-Page"];

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

    for (var i = [JSONObject count] - 1; i >= 0; i--)
    {
        var newObject = [self newObject];

        [newObject objectFromJSON:JSONObject[i]];
        [newObject setParentObject:_entity];
        [dest addObject:newObject];
        [newlyFetchedObjects addObject:newObject];
    }

    [self _sendContent:newlyFetchedObjects usingConnection:aConnection];
}

- (void)_sendContent:(CPArray)someContent usingConnection:(NURESTConnection)aConnection
{
    if (aConnection)
    {
        var target = [aConnection internalUserInfo]["remoteTarget"],
            selector = [aConnection internalUserInfo]["remoteSelector"];

        // should be - (void)didFetcher:ofObject:countContent: or something like that
        [target performSelector:selector withObjects:self, _entity, someContent];
    }
}

- (CPArray)latestSortDescriptors
{
    if (!_orderedBy)
        return;

    var descriptors = [CPArray array],
        elements = _orderedBy.split(",");

    for (var i = 0; i < [elements count]; i++)
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
    var request = [CPURLRequest requestWithURL:[CPURL URLWithString:_restName relativeToURL:[_entity RESTQueryURL]]];

    [request setHTTPMethod:@"HEAD"];

    [_entity sendRESTCall:request performSelector:@selector(_didCountObjects:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:nil];
}

- (void)_didCountObjects:(NURESTConnection)aConnection
{
    var count = parseInt([aConnection nativeRequest].getResponseHeader("X-Nuage-Count")),
        target = [aConnection internalUserInfo]["remoteTarget"],
        selector = [aConnection internalUserInfo]["remoteSelector"];

    // should be - (void)didFetcher:ofObject:countContent: or something like that
    [target performSelector:selector withObjects:self, _entity, count];
}

@end
