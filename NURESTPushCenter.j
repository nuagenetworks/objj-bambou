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
@import "NURESTLoginController.j"

@global CPApp
@global _format_log_json;

NURESTPushCenterPushReceived      = @"NURESTPushCenterPushReceived";
NURESTPushCenterServerUnreachable = @"NURESTPushCenterServerUnreachable";

NUPushEventTypeCreate = @"CREATE";
NUPushEventTypeUpdate = @"UPDATE";
NUPushEventTypeDelete = @"DELETE";
NUPushEventTypeRevoke = @"REVOKE";
NUPushEventTypeGrant  = @"GRANT";

var NURESTPushCenterDefault;

_DEBUG_NUMBER_OF_RECEIVED_EVENTS_ = 0;
_DEBUG_NUMBER_OF_RECEIVED_PUSH_SESSION_ = 0;


/*! This is the default push center
    Use it by calling [NURESTPushCenter defaultCenter];
*/
@implementation NURESTPushCenter : CPObject
{
    BOOL                _isRunning;
    NURESTConnection    _currentConnection;
}


#pragma mark -
#pragma mark Class methods

/*! Returns the defaultCenter. Initialize it if needed
    @returns default NURESTPushCenter
*/
+ (NURESTPushCenter)defaultCenter
{
    if (!NURESTPushCenterDefault)
        NURESTPushCenterDefault = [[NURESTPushCenter alloc] init];

    return NURESTPushCenterDefault;
}


#pragma mark -
#pragma mark Push Center Controls

/*! Start to listen for push notification
*/
- (void)start
{
    if (_isRunning)
        return;

     _isRunning = YES;

     [self _listenToNextEvent:nil];
}

/*! Stops listening for push notification
*/
- (void)stop
{
    if (!_isRunning)
        return;

     _isRunning = NO;

     if (_currentConnection)
         [_currentConnection cancel];
}


#pragma mark -
#pragma mark Privates

/*! @ignore
    manage the connection
*/
- (void)_listenToNextEvent:(CPString)anUUID
{
    var URL = [[NURESTLoginController defaultController] URL];

    if (!URL)
        [CPException raise:CPInternalInconsistencyException reason:@"NURESTPushCenter needs to have a valid URL set in the default NURESTLoginController"];

    var eventURL =  anUUID ? @"events?uuid=" + anUUID : @"events",
        request = [CPURLRequest requestWithURL:[CPURL URLWithString:eventURL relativeToURL:URL]];

    _currentConnection = [NURESTConnection connectionWithRequest:request target:self selector:@selector(_didReceiveEvent:)];
    [_currentConnection setTimeout:0];
    [_currentConnection setIgnoreRequestIdle:YES];
    [_currentConnection start];
}

/*! @ignore
    manage the connection response
*/
- (void)_didReceiveEvent:(NURESTConnection)aConnection
{
    if (!_isRunning)
        return;

    var JSONObject = [[aConnection responseData] JSONObject];

    if ([aConnection responseCode] !== 200)
    {
        CPLog.error("BAMBOU PUSHCENTER: Connection failure URL %s. Error Code: %s, (%s) ", [[NURESTLoginController defaultController] URL], [aConnection responseCode], [aConnection errorMessage]);

        [[CPNotificationCenter defaultCenter] postNotificationName:NURESTPushCenterServerUnreachable
                                                            object:self
                                                          userInfo:nil];

        return;
    }

    if (JSONObject)
    {
        var numberOfIndividualEvents = JSONObject.events.length;

        _DEBUG_NUMBER_OF_RECEIVED_EVENTS_ += numberOfIndividualEvents;
        _DEBUG_NUMBER_OF_RECEIVED_PUSH_SESSION_++;

        CPLog.debug("BAMBOU PUSHCENTER:\n\nReceived Push #%d (total: %d, latest: %d):\n\n%@\n\n",
                        _DEBUG_NUMBER_OF_RECEIVED_PUSH_SESSION_, _DEBUG_NUMBER_OF_RECEIVED_EVENTS_,
                        numberOfIndividualEvents, _format_log_json([[aConnection responseData] rawString]));

        [[CPNotificationCenter defaultCenter] postNotificationName:NURESTPushCenterPushReceived object:self userInfo:JSONObject];
    }

    _currentConnection = nil;

    if (_isRunning)
        [self _listenToNextEvent:JSONObject ? JSONObject.uuid : nil];
}

@end
