/*
*   Filename:         NURESTFetcher.j
*   Created:          Tue Oct  9 11:49:36 PDT 2012
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

@import <Foundation/CPURLConnection.j>


@implementation NURESTFetcher : CPObject
{
    CPObject    _entity      @accessors(property=entity);

    CPString    _destinationKeyPath;
    CPArray     _restName;
}

- (void)newObject
{
    return nil;
}

- (void)fetchObjectsAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self fetchObjectsMatchingFilter:nil andCallSelector:aSelector ofObject:anObject userInfo:nil];
}

- (void)fetchObjectsMatchingFilter:(id)aFilter andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self fetchObjectsMatchingFilter:aFilter andCallSelector:aSelector ofObject:anObject userInfo:nil];
}

- (void)fetchObjectsMatchingFilter:(id)aFilter andCallSelector:(SEL)aSelector ofObject:(id)anObject userInfo:(id)someUserInfo
{
    var request = [CPURLRequest requestWithURL:[CPURL URLWithString:_restName relativeToURL:[_entity RESTQueryURL]]],
        someUserInfo = (aSelector && anObject) ? [anObject, aSelector, someUserInfo] : nil;

    [request setHTTPMethod:@"GET"];

    if ([aFilter isKindOfClass:CPPredicate])
    {
        [request setValue:@"predicate" forHTTPHeaderField:@"X-Nuage-FilterType"];
        [request setValue:[aFilter predicateFormat] forHTTPHeaderField:@"X-Nuage-Filter"];
    }
    else if ([aFilter isKindOfClass:CPString])
    {
        [request setValue:@"plain" forHTTPHeaderField:@"X-Nuage-FilterType"];
        [request setValue:aFilter forHTTPHeaderField:@"X-Nuage-Filter"];
    }

    [_entity sendRESTCall:request andPerformSelector:@selector(_didFetchObjects:) ofObject:self userInfo:someUserInfo];
}

/*! @ignore
*/
- (void)_didFetchObjects:(CPURLConnection)aConnection
{
    var JSONObject = [[aConnection responseData] JSONObject],
        dest = [_entity valueForKey:_destinationKeyPath];

    [dest removeAllObjects];

    for (var i = 0; i < [JSONObject count]; i++)
    {
        var newObject = [self newObject];
        [newObject objectFromJSON:JSONObject[i]];
        [dest addObject:newObject];
    }

    if ([aConnection userInfo])
        [[aConnection userInfo][0] performSelector:[aConnection userInfo][1] withObject:_entity withObject:[aConnection userInfo][2] ? [aConnection userInfo][2] : dest];
}

@end
