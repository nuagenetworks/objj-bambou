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
@import "NURESTJob.j"
@import "NURESTPushCenter.j"

NURESTJobsControllerJobCompletedNotification = @"NURESTJobsControllerJobCompletedNotification";

var _NUJRESTobsControllerDefaultController;

@implementation NURESTJobsController : CPObject
{
    CPArray         _jobsRegistry;
    BOOL            _isListeningForPush;
}


#pragma mark -
#pragma mark Class Methods

+ (void)defaultController
{
    if (!_NUJRESTobsControllerDefaultController)
        _NUJRESTobsControllerDefaultController = [NURESTJobsController new];

    return _NUJRESTobsControllerDefaultController;
}


#pragma mark -
#pragma mark Initialization

- (id)init
{
    if (self = [super init])
    {
        _jobsRegistry = [];
        _isListeningForPush = NO;
    }

    return self;
}


#pragma mark -
#pragma mark Job Registry

- (void)_addJobInfo:(CPDictionary)someInfo
{
    [_jobsRegistry addObject:someInfo];
}

- (CPArray)jobInfoForEntityID:(CPString)anID
{
    var predicate = [CPPredicate predicateWithFormat:@"entityID == %@", anID];

    return [[_jobsRegistry filteredArrayUsingPredicate:predicate] firstObject];
}

- (CPArray)_jobInfoForJobID:(CPString)anID
{
    var predicate = [CPPredicate predicateWithFormat:@"job.ID == %@", anID];

    return [[_jobsRegistry filteredArrayUsingPredicate:predicate] firstObject];
}


#pragma mark -
#pragma mark JobPosting

- (void)postJob:(NURESTJob)aJob toEntity:(NURESTObject)anObject
{
    [self postJob:aJob toEntity:anObject andCallSelector:[CPNull null] ofObject:[CPNull null]];
}

- (void)postJob:(NURESTJob)aJob toEntity:(NURESTObject)anEntity andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    if (!_isListeningForPush)
        [self startListeningForPush];

    if (!anObject)
        anObject = [CPNull null];

    if (!aSelector)
        aSelector = [CPNull null];

    [self _addJobInfo:@{"selector": aSelector, @"target": anObject, @"entityID": [anEntity ID], @"job": [CPNull null], @"jobClass": [aJob class]}];

    [anEntity createChildObject:aJob andCallSelector:@selector(_didEntity:createJob:connection:) ofObject:self];
}

- (void)_didEntity:(NURESTObject)anObject createJob:(NURESTJob)aJob connection:(NURESTConnection)aConnection
{
    var jobInfo = [self jobInfoForEntityID:[anObject ID]];

    if (aConnection && ![NURESTConnection handleResponseForConnection:aConnection postErrorMessage:YES])
    {
        [_jobsRegistry removeObject:jobInfo];
        return;
    }

    [jobInfo setObject:aJob forKey:@"job"];
}

- (void)_sendJobResultFromJobInfo:(CPDictionary)someInfo
{
    var target = [someInfo objectForKey:@"target"],
        selector = [someInfo objectForKey:@"selector"],
        job = [someInfo objectForKey:@"job"];

    [_jobsRegistry removeObject:someInfo];

    if (![_jobsRegistry count])
        [self stopListeningForPush];

    if ([target isKindOfClass:[CPNull class]])
        [[CPNotificationCenter defaultCenter] postNotificationName:NURESTJobsControllerJobCompletedNotification object:nil userInfo:@{@"job" : job}];
    else
        [target performSelector:selector withObject:job];
}

- (void)removeJobListenerForEntity:(NURESTObject)anObject
{
    var info = [self jobInfoForEntityID:[anObject ID]];
    [_jobsRegistry removeObject:info];

    if (![_jobsRegistry count])
        [self stopListeningForPush];
}


#pragma mark -
#pragma mark Job Retrieval

- (void)getJobWithID:(CPString)anID andCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    var job = [[[self _jobInfoForJobID:anID] objectForKey:@"jobClass"] new];
    [job setID:anID];

    [job fetchAndCallSelector:aSelector ofObject:anObject];
}

- (void)_didFetchJob:(NURESTJob)aJob connection:(NURESTConnection)aConnection
{
    if (![NURESTConnection handleResponseForConnection:aConnection postErrorMessage:YES])
        return;

    var info = [self _jobInfoForJobID:[aJob ID]];
    [info setObject:aJob forKey:@"job"];

    [self _sendJobResultFromJobInfo:info];
}


#pragma mark -
#pragma mark Push Management

- (void)startListeningForPush
{
    if (_isListeningForPush)
        return;

    _isListeningForPush = YES;

    CPLog.debug("PUSH: JobController is now registered for push");
    [[CPNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_didReceivePush:)
                                                 name:NURESTPushCenterPushReceived
                                               object:[NURESTPushCenter defaultCenter]];
}

- (void)stopListeningForPush
{
    if (!_isListeningForPush)
        return;

    _isListeningForPush = NO;

    CPLog.debug("PUSH: JobController is now unregistered from push");
    [[CPNotificationCenter defaultCenter] removeObserver:self
                                                 name:NURESTPushCenterPushReceived
                                               object:[NURESTPushCenter defaultCenter]];
}

- (void)_didReceivePush:(CPNotification)aNotification
{
    var JSONObject = [aNotification userInfo],
        events = JSONObject.events;

    if (events.length <= 0)
        return;

    for (var i = 0, c = events.length; i < c; i++)
    {
        var eventType = events[i].type,
            entityType = events[i].entityType,
            entityJSON = events[i].entities[0];

        if (entityType != [NURESTJob RESTName])
            continue;

        switch (eventType)
        {
            case NUPushEventTypeCreate:
            case NUPushEventTypeUpdate:

                var localJobInfo = [self _jobInfoForJobID:entityJSON.ID];

                if (!localJobInfo || (entityJSON.status != NURESTJobStatusFAILED && entityJSON.status != NURESTJobStatusSUCCESS))
                    break;

                var job = [localJobInfo objectForKey:@"job"];

                [self getJobWithID:[job ID] andCallSelector:@selector(_didFetchJob:connection:) ofObject:self];

                break;

            case NUPushEventTypeDelete:

                var localJobInfo = [self _jobInfoForJobID:entityJSON.ID];

                if (!localJobInfo)
                    break;

                [_jobsRegistry removeObject:localJobInfo];

                break;
        }
    }

    if (![_jobsRegistry count])
        [self stopListeningForPush];
}

@end
