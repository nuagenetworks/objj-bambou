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
@global NURESTConnectionMethodGet

NURESTFetcherPageSize = 50;


@implementation NURESTFetcher : CPObject
{
    CPNumber            _latestLoadedPage       @accessors(property=latestLoadedPage);
    CPNumber            _totalCount             @accessors(property=totalCount);
    CPString            _destinationKeyPath     @accessors(property=destinationKeyPath);
    CPString            _queryString            @accessors(property=queryString);
    CPString            _transactionID          @accessors(property=transactionID);
    id                  _parentObject           @accessors(property=parentObject);
    NURESTConnection    _currentConnection      @accessors(property=currentConnection);

    CPString            _orderedBy;
}


#pragma mark -
#pragma mark Class Methods

+ (Class)managedObjectClass
{
    [CPException raise:CPInternalInconsistencyException reason:"NURESTFetcher subclasses must implement managedObjectClass"];
}

+ (CPString)managedObjectRESTName
{
    return [[self managedObjectClass] RESTName];
}

+ (NURESTFetcher)fetcherWithParentObject:(NURESTObject)aParentObject destinationKeyPath:(CPString)aDestinationKeyPath
{
    var fetcher = [[self class] new];
    [fetcher setParentObject:aParentObject];
    [fetcher setDestinationKeyPath:aDestinationKeyPath];

    var RESTName = [self managedObjectRESTName];
    [aParentObject setValue:[] forKeyPath:aDestinationKeyPath];
    [aParentObject registerChildrenList:[aParentObject valueForKeyPath:aDestinationKeyPath] forRESTName:RESTName];
    [aParentObject registerChildrenFetcher:fetcher forRESTName:RESTName];

    return fetcher;
}


#pragma mark -
#pragma mark Initialization

- (void)flush
{
    _currentConnection = nil;
    [[_parentObject valueForKeyPath:_destinationKeyPath] removeAllObjects];
}

- (id)newManagedObject
{
    return [[[self class] managedObjectClass] new];
}


#pragma mark -
#pragma mark Utiltities

- (CPString)managedObjectClass
{
    return [[self class] managedObjectClass];
}

- (id)_RESTFilterFromFilter:(id)aFilter masterFilter:(id)aMasterFilter
{
    // if no filter is set, return nil
    if (!aFilter && !aMasterFilter)
        return nil;

    // if no user user is set  but we have a master filter, return the master filter
    if (!aFilter && aMasterFilter)
        return aMasterFilter;

    // if user filter is set, but no master filter, return the user filter as it is.
    if (aFilter && !aMasterFilter)
        return aFilter;

    if (aFilter && aMasterFilter)
    {
        var userPredicate;
        // try to make a predicate from the given filter
        if ([aFilter isKindOfClass:CPPredicate])
            userPredicate = aFilter;
        else
            userPredicate = [CPPredicate predicateWithFormat:aFilter];

        // if it didn't work, create full text search predicate
        if (!userPredicate)
            userPredicate = [[self newManagedObject] fullTextSearchPredicate:aFilter];

        return [[CPCompoundPredicate alloc] initWithType:CPAndPredicateType subpredicates:[aMasterFilter, userPredicate]];
    }

    // we should never reach here
    [CPException raise:CPInternalInconsistencyException reason:"NURESTFetcher cannot prepare filter"];
}


#pragma mark -
#pragma mark Request Management

- (void)_prepareHeadersForRequest:(CPURLRequest)aRequest withFilter:(id)aFilter masterFilter:(id)aMasterFilter orderBy:(CPString)anOrder groupBy:(CPArray)aGrouping page:(CPNumber)aPage pageSize:(int)aPageSize
{
    var filter = [self _RESTFilterFromFilter:aFilter masterFilter:aMasterFilter];

    if (filter)
        [aRequest setValue:[filter isKindOfClass:CPPredicate] ? [filter predicateFormat] : filter forHTTPHeaderField:@"X-Nuage-Filter"];

    if (aPage !== nil)
        [aRequest setValue:aPage forHTTPHeaderField:@"X-Nuage-Page"];

    if (aPageSize)
        [aRequest setValue:aPageSize forHTTPHeaderField:@"X-Nuage-PageSize"];

    if (anOrder)
        [aRequest setValue:anOrder forHTTPHeaderField:@"X-Nuage-OrderBy"];

    if (aGrouping)
    {
        var headerString = @"";
        for (var i = 0, c = [aGrouping count]; i < c; i++)
        {
            headerString += aGrouping[i];
            if (i + 1 < c)
                headerString += @", ";
        }

        [aRequest setValue:@"true" forHTTPHeaderField:@"X-Nuage-GroupBy"];
        [aRequest setValue:headerString forHTTPHeaderField:@"X-Nuage-Attributes"];
    }
}

- (CPURL)_prepareURL
{
    var url = [_parentObject RESTResourceURLForChildrenClass:[self managedObjectClass]];

    if (_queryString)
        url = [CPURL URLWithString:[url absoluteString] + "?" + _queryString];

    return url;
}

- (CPString)retrieveObjectsAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    return [self retrieveObjectsMatchingFilter:nil
                                  masterFilter:nil
                                     orderedBy:nil
                                     groupedBy:nil
                                          page:nil
                                      pageSize:nil
                                        commit:YES
                               andCallSelector:aSelector
                                      ofObject:anObject
                                         block:nil];
}

- (CPString)retrieveObjectsAndCallBlock:(Function)aFunction
{
    return [self retrieveObjectsMatchingFilter:nil
                                  masterFilter:nil
                                     orderedBy:nil
                                     groupedBy:nil
                                          page:nil
                                      pageSize:nil
                                        commit:YES
                               andCallSelector:nil
                                      ofObject:nil
                                         block:aFunction];
}

- (CPString)retrieveObjectsMatchingFilter:(id)aFilter
                             masterFilter:(id)aMasterFilter
                                orderedBy:(CPString)anOrder
                                groupedBy:(CPArray)aGrouping
                                     page:(CPNumber)aPage
                                 pageSize:(CPNumber)aPageSize
                                   commit:(BOOL)shouldCommit
                                    andCallBlock:(Function)aFunction
{
    return [self retrieveObjectsMatchingFilter:aFilter
                                  masterFilter:aMasterFilter
                                     orderedBy:anOrder
                                     groupedBy:aGrouping
                                          page:aPage
                                      pageSize:aPageSize
                                        commit:shouldCommit
                               andCallSelector:nil
                                      ofObject:nil
                                         block:aFunction];
}


- (CPString)retrieveObjectsMatchingFilter:(id)aFilter
                             masterFilter:(id)aMasterFilter
                                orderedBy:(CPString)anOrder
                                groupedBy:(CPArray)aGrouping
                                     page:(CPNumber)aPage
                                 pageSize:(CPNumber)aPageSize
                                   commit:(BOOL)shouldCommit
                          andCallSelector:(SEL)aSelector
                                 ofObject:(id)anObject
                                    block:(Function)aFunction
{
    var request = [CPURLRequest requestWithURL:[self _prepareURL]];
    [request setHTTPMethod:NURESTConnectionMethodGet];

    [self _prepareHeadersForRequest:request withFilter:aFilter masterFilter:aMasterFilter orderBy:anOrder groupBy:aGrouping page:aPage pageSize:aPageSize];

    _transactionID = [CPString UUID];
    [_parentObject sendRESTCall:request performSelector:@selector(_didRetrieveObjects:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:{"commit": shouldCommit, "block": aFunction}];

    return _transactionID;
}

/*! @ignore
*/
- (void)_didRetrieveObjects:(NURESTConnection)aConnection
{
    _currentConnection = aConnection;

    var commitInfo = [aConnection userInfo]["commit"],
        shouldCommit = commitInfo === nil || commitInfo === YES;

    if ([_currentConnection responseCode] != 200) // @TODO: server sends 200, but if there is an empty list we should have the empty code...
    {
        if (shouldCommit)
        {
            _totalCount       = 0;
            _latestLoadedPage = 0;
            _orderedBy        = @"";
        }

        [self _sendContent:nil usingConnection:_currentConnection];
        return;
    }

    var JSONObject     = [[_currentConnection responseData] JSONObject],
        dest           = [_parentObject valueForKey:_destinationKeyPath],
        retrievedObjects = [];

    if (shouldCommit)
    {
        _totalCount       = parseInt([_currentConnection nativeRequest].getResponseHeader("X-Nuage-Count"));
        _latestLoadedPage = parseInt([_currentConnection nativeRequest].getResponseHeader("X-Nuage-Page"));
        _orderedBy        = [_currentConnection nativeRequest].getResponseHeader("X-Nuage-OrderBy");
    }

    for (var i = 0, c = [JSONObject count]; i < c; i++)
    {
        var newObject = [self newManagedObject];

        [newObject objectFromJSON:JSONObject[i]];
        [newObject setParentObject:_parentObject];

        [retrievedObjects addObject:newObject];

        if (!shouldCommit)
            continue;

        if (![dest containsObject:newObject])
            [dest addObject:newObject];
    }

    // @TODO: wy sending a copy? I should be better to directly pass the dest. It should be working by now.
    // @EDIT: Actually, I'm not sure. This is used as datasource content, and removing stuff from datasource
    // will remove it from the RESTObject array, and that could cause some weird error. I need to deeply check
    // if it is safe or not to simply give the destination array... wait and see
    // @EDIT: I think the second message is right. using pagination will completely screw up things.
    [self _sendContent:retrievedObjects usingConnection:_currentConnection];
}

- (void)countObjectsAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self countObjectsMatchingFilter:nil
                        masterFilter:nil
                           groupedBy:nil
                     andCallSelector:aSelector
                            ofObject:anObject
                               block:nil];
}

- (void)countObjectsAndCallBlock:(Function)aFunction
{
    [self countObjectsMatchingFilter:nil
                        masterFilter:nil
                           groupedBy:nil
                     andCallSelector:nil
                            ofObject:nil
                               block:aFunction];
}

- (CPString)countObjectsMatchingFilter:(CPPredicate)aFilter
                          masterFilter:(CPPredicate)aMasterFilter
                             groupedBy:(CPArray)aGrouping
                       andCallSelector:(SEL)aSelector
                              ofObject:(id)anObject
                                 block:(Function)aFunction
{
    var request = [CPURLRequest requestWithURL:[self _prepareURL]];
    [request setHTTPMethod:@"HEAD"];

    [self _prepareHeadersForRequest:request withFilter:aFilter masterFilter:aMasterFilter orderBy:nil groupBy:aGrouping page:nil pageSize:nil];

    _transactionID = [CPString UUID];
    [_parentObject sendRESTCall:request performSelector:@selector(_didCountObjects:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:{"block": aFunction}];

    return _transactionID;
}

- (void)_didCountObjects:(NURESTConnection)aConnection
{
    if (!aConnection)
        return;

    var count = parseInt([aConnection nativeRequest].getResponseHeader("X-Nuage-Count")),
        target = [aConnection internalUserInfo]["remoteTarget"],
        selector = [aConnection internalUserInfo]["remoteSelector"],
        block = [aConnection userInfo]["block"];

    if (block)
        block(self, _parentObject, count);

    [target performSelector:selector withObjects:self, _parentObject, count];

    [_currentConnection reset];
    _currentConnection = nil;
}

- (void)_sendContent:(CPArray)someContent usingConnection:(NURESTConnection)aConnection
{
    if (!aConnection)
        return;

    var target = [aConnection internalUserInfo]["remoteTarget"],
        selector = [aConnection internalUserInfo]["remoteSelector"],
        block = [aConnection userInfo]["block"];

    [target performSelector:selector withObjects:self, _parentObject, someContent];

    if (block)
        block(self, _parentObject, someContent);

    [_currentConnection reset];
    _currentConnection = nil;
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

@end
