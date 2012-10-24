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
    CPNumber    _totalCount             @accessors(property=totalCount);
    CPObject    _entity                 @accessors(property=entity);

    CPArray     _restName;
    CPString    _destinationKeyPath;
}

- (void)flush
{
    [[_entity valueForKey:_destinationKeyPath] removeAllObjects];
}

- (void)newObject
{
    return nil;
}

- (void)fetchObjectsAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self fetchObjectsMatchingFilter:nil page:nil andCallSelector:aSelector ofObject:anObject];
}

- (void)fetchObjectsMatchingFilter:(id)aFilter page:(CPNumber)aPage andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    var request = [CPURLRequest requestWithURL:[CPURL URLWithString:_restName relativeToURL:[_entity RESTQueryURL]]],
        someUserInfo = (aSelector && anObject) ? [anObject, aSelector] : nil;

    [request setHTTPMethod:@"GET"];

    if ([aFilter isKindOfClass:CPPredicate])
        [request setValue:[aFilter predicateFormat] forHTTPHeaderField:@"X-Nuage-Filter"];
    else if ([aFilter isKindOfClass:CPString])
        [request setValue:aFilter forHTTPHeaderField:@"X-Nuage-Filter"];

    if (aPage !== nil)
        [request setValue:aPage forHTTPHeaderField:@"X-Nuage-Page"];

    [_entity sendRESTCall:request andPerformSelector:@selector(_didFetchObjects:) ofObject:self userInfo:someUserInfo];
}

/*! @ignore
*/
- (void)_didFetchObjects:(CPURLConnection)aConnection
{
    var JSONObject = [[aConnection responseData] JSONObject],
        dest = [_entity valueForKey:_destinationKeyPath];

    _totalCount = [aConnection nativeRequest].getResponseHeader("X-Nuage-Count") || -1;

    for (var i = 0; i < [JSONObject count]; i++)
    {
        var newObject = [self newObject];
        [newObject objectFromJSON:JSONObject[i]];
        [dest addObject:newObject];
    }

    if ([aConnection userInfo])
    {
        var target = [aConnection userInfo][0],
            selector = [aConnection userInfo][1];

        [target performSelector:selector withObjects:self, _entity, dest];
    }
}

@end
