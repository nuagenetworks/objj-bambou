/*
* Copyright (c) 2016, Alcatel-Lucent Inc
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of the copyright holder nor the names of its contributors
*       may be used to endorse or promote products derived from this software without
*       specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

@import <Foundation/Foundation.j>
@import "NURESTConnection.j"

NURESTFetcherPageSize = 50;


@implementation NURESTFetcher : CPObject
{
    CPNumber            _currentPage            @accessors(property=currentPage);
    CPNumber            _currentResponseCount   @accessors(property=currentResponseCount);
    CPNumber            _currentTotalCount      @accessors(property=currentTotalCount);
    CPString            _currentOrderedBy       @accessors(property=currentOrderedBy);
    CPString            _queryString            @accessors(property=queryString);
    CPString            _transactionID          @accessors(property=transactionID);
    id                  _parentObject           @accessors(property=parentObject);
    NURESTConnection    _currentConnection      @accessors(property=currentConnection);

    CPArray             _contents;
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

+ (NURESTFetcher)fetcherWithParentObject:(NURESTObject)aParentObject
{
    var fetcher = [self new];

    [fetcher setParentObject:aParentObject];

    [aParentObject registerFetcher:fetcher forRESTName:[self managedObjectRESTName]];

    return fetcher;
}


#pragma mark -
#pragma mark Initialization

- (id)init
{
    if (self = [super init]) 
    {
        _contents = [];
        _currentResponseCount = 0;
    }

    return self;
}


#pragma mark -
#pragma mark Message Forwarding

- (CPMethodSignature)methodSignatureForSelector:(SEL)aSelector
{
    return YES;
}

- (void)forwardInvocation:(CPInvocation)anInvocation
{
    if ([_contents respondsToSelector:[anInvocation selector]])
        [anInvocation invokeWithTarget:_contents];
    else
        [super forwardInvocation:anInvocation];
}


#pragma mark -
#pragma mark Getters

- (CPArray)array
{
    return _contents;
}

- (CPArray)currentSortDescriptors
{
    if (!_currentOrderedBy)
        return;

    var descriptors = [CPArray array],
        elements = _currentOrderedBy.split(",");

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

- (CPString)transactionID
{
    if (!_currentConnection)
        [CPException raise:CPInternalInconsistencyException reason:"NURESTConnection: trying to access the current transation ID, but there is no current connection"];

    return [_currentConnection transactionID];
}

- (CPString)managedObjectClass
{
    return [[self class] managedObjectClass];
}

- (id)newManagedObject
{
    return [[[self class] managedObjectClass] new];
}


#pragma mark -
#pragma mark Utiltities

- (void)flush
{
    [self _resetLastConnectionInformation];
    [_contents removeAllObjects];
    _currentResponseCount = 0;
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

- (void)_resetLastConnectionInformation
{
    [_currentConnection reset];
    _currentConnection = nil;
    // _currentOrderedBy  = nil;
    // _currentPage       = nil;
    // _currentTotalCount = nil;
}

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


#pragma mark -
#pragma mark Fetching Management

- (CPString)fetchAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    return [self fetchWithMatchingFilter:nil masterFilter:nil orderedBy:nil groupedBy:nil page:nil pageSize:nil commit:YES andCallSelector:aSelector ofObject:anObject block:nil];
}

- (CPString)fetchAndCallBlock:(Function)aFunction
{
    return [self fetchWithMatchingFilter:nil masterFilter:nil orderedBy:nil groupedBy:nil page:nil pageSize:nil commit:YES andCallSelector:nil ofObject:nil block:aFunction];
}

- (CPString)fetchWithMatchingFilter:(id)aFilter masterFilter:(id)aMasterFilter orderedBy:(CPString)anOrder groupedBy:(CPArray)aGrouping page:(CPNumber)aPage pageSize:(CPNumber)aPageSize commit:(BOOL)shouldCommit andCallBlock:(Function)aFunction
{
    return [self fetchWithMatchingFilter:aFilter masterFilter:aMasterFilter orderedBy:anOrder groupedBy:aGrouping page:aPage pageSize:aPageSize commit:shouldCommit andCallSelector:nil ofObject:nil block:aFunction];
}

- (CPString)fetchWithMatchingFilter:(id)aFilter masterFilter:(id)aMasterFilter orderedBy:(CPString)anOrder groupedBy:(CPArray)aGrouping page:(CPNumber)aPage pageSize:(CPNumber)aPageSize commit:(BOOL)shouldCommit andCallSelector:(SEL)aSelector ofObject:(id)anObject block:(Function)aFunction
{
    var request = [CPURLRequest requestWithURL:[self _prepareURL]];

    [request setHTTPMethod:NURESTConnectionMethodGet];
    [self _prepareHeadersForRequest:request withFilter:aFilter masterFilter:aMasterFilter orderBy:anOrder groupBy:aGrouping page:aPage pageSize:aPageSize];

    return [_parentObject sendRESTCall:request performSelector:@selector(_didFetchObjects:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject block:aFunction userInfo:{"commit": shouldCommit}];
}

- (void)_didFetchObjects:(NURESTConnection)aConnection
{
    var target       = [aConnection internalUserInfo]["remoteTarget"],
        selector     = [aConnection internalUserInfo]["remoteSelector"],
        block        = [aConnection internalUserInfo]["remoteBlock"],
        commitInfo   = [aConnection userInfo]["commit"],
        shouldCommit = commitInfo === nil || commitInfo === YES,
        fetchedObjects;

    _currentConnection = aConnection;

    if ([_currentConnection responseCode] != 200) // @TODO: server sends 200, but if there is an empty list we should have the empty code...
    {
        _currentTotalCount = 0;
        _currentPage       = 0;
        _currentResponseCount = 0;
        _currentOrderedBy  = @"";
        fetchedObjects     = nil;
    }
    else
    {
        _currentTotalCount = parseInt([_currentConnection valueForResponseHeader:@"X-Nuage-Count"]);
        _currentPage       = parseInt([_currentConnection valueForResponseHeader:@"X-Nuage-Page"]);
        _currentOrderedBy  = [_currentConnection valueForResponseHeader:@"X-Nuage-OrderBy"];
        fetchedObjects     = [];

        var JSONObject = [[_currentConnection responseData] JSONObject];

        _currentResponseCount += [JSONObject count];
        
        for (var i = 0, c = [JSONObject count]; i < c; i++)
        {
            var newObject = [self newManagedObject];
            [newObject objectFromJSON:JSONObject[i]];
            [newObject setParentObject:_parentObject];
            [fetchedObjects addObject:newObject];

            if (shouldCommit && ![_contents containsObject:newObject])
                [_contents addObject:newObject];
        }
    }

    [target performSelector:selector withObjects:self, _parentObject, fetchedObjects];

    if (block)
        (function(){block(self, _parentObject, fetchedObjects); [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];})();

    [self _resetLastConnectionInformation];
}


#pragma mark -
#pragma mark Counting Management

- (void)countAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    [self countWithMatchingFilter:nil masterFilter:nil groupedBy:nil andCallSelector:aSelector ofObject:anObject block:nil];
}

- (void)countObjectsAndCallBlock:(Function)aFunction
{
    [self countWithMatchingFilter:nil masterFilter:nil groupedBy:nil andCallSelector:nil ofObject:nil block:aFunction];
}

- (CPString)countWithMatchingFilter:(CPPredicate)aFilter masterFilter:(CPPredicate)aMasterFilter groupedBy:(CPArray)aGrouping andCallSelector:(SEL)aSelector ofObject:(id)anObject block:(Function)aFunction
{
    var request = [CPURLRequest requestWithURL:[self _prepareURL]];

    [request setHTTPMethod:@"HEAD"];
    [self _prepareHeadersForRequest:request withFilter:aFilter masterFilter:aMasterFilter orderBy:nil groupBy:aGrouping page:nil pageSize:nil];

    return [_parentObject sendRESTCall:request performSelector:@selector(_didCountObjects:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject block:aFunction userInfo:nil];
}

- (void)_didCountObjects:(NURESTConnection)aConnection
{
    var target   = [aConnection internalUserInfo]["remoteTarget"],
        selector = [aConnection internalUserInfo]["remoteSelector"],
        block    = [aConnection internalUserInfo]["remoteBlock"];

    _currentConnection = aConnection;
    _currentTotalCount = parseInt([_currentConnection valueForResponseHeader:@"X-Nuage-Count"]);
    _currentPage       = parseInt([_currentConnection valueForResponseHeader:@"X-Nuage-Page"]);
    _currentOrderedBy  = [_currentConnection valueForResponseHeader:@"X-Nuage-OrderBy"];

    [target performSelector:selector withObjects:self, _parentObject, _currentTotalCount];

    if (block)
        (function(){block(self, _parentObject, _currentTotalCount); [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];})();

    [self _resetLastConnectionInformation];
}

@end
