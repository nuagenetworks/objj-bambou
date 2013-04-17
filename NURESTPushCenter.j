/*
*   Filename:         NURESTPushCenter.j
*   Created:          Tue Oct  9 11:52:21 PDT 2012
*   Author:           Antoine Mercadal <antoine.mercadal@alcatel-lucent.com>
*   Description:      VSD Architect
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

@global CPApp
@global _format_log_json;


NURESTPushCenterPushReceived            = @"NURESTPushCenterPushReceived";
NURESTPushCenterServerUnreachable       = @"NURESTPushCenterServerUnreachable";

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
    CPURL               _URL                    @accessors(property=URL);

    BOOL                _isRunning;
    NURESTConnection    _currentConnexion;
}


#pragma mark -
#pragma mark Class methods

/*! Returns the defaultCenter. Initialize it if needed
    @returns default NURESTPushCenter
*/
+ (void)defaultCenter
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

     if (_currentConnexion)
         [_currentConnexion cancel];
}


#pragma mark -
#pragma mark Privates

/*! @ignore
    manage the connection
*/
- (void)_listenToNextEvent:(CPString)anUUID
{
    if (!_URL)
        [CPException raise:CPInternalInconsistencyException reason:@"NURESTPushCenter needs to have a valid URL. please use setURL: before starting it."];

    var eventURL =  anUUID ? @"events?uuid=" + anUUID : @"events",
        request = [CPURLRequest requestWithURL:[CPURL URLWithString:eventURL relativeToURL:_URL]];

    _currentConnexion = [NURESTConnection connectionWithRequest:request target:self selector:@selector(_didReceiveEvent:)];
    [_currentConnexion setTimeout:0];
    [_currentConnexion setIgnoreRequestIdle:YES];
    [_currentConnexion start];
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
        CPLog.error("RESTCAPPUCCINO PUSHCENTER: Connexion failure URL %s. Error Code: %s, (%s) ", _URL, [aConnection responseCode], [aConnection errorMessage]);

        [[CPNotificationCenter defaultCenter] postNotificationName:NURESTPushCenterServerUnreachable
                                                            object:self
                                                          userInfo:nil];

        return;
    }

    if (JSONObject)
    {
        var numberOfIndividualEvents = JSONObject.events.length;

        try
        {

            _DEBUG_NUMBER_OF_RECEIVED_EVENTS_ += numberOfIndividualEvents;
            _DEBUG_NUMBER_OF_RECEIVED_PUSH_SESSION_++;

            CPLog.debug("RESTCAPPUCCINO PUSHCENTER:\n\nReceived Push #%d (total: %d, latest: %d):\n\n%@\n\n",
                            _DEBUG_NUMBER_OF_RECEIVED_PUSH_SESSION_, _DEBUG_NUMBER_OF_RECEIVED_EVENTS_,
                            numberOfIndividualEvents, _format_log_json([[aConnection responseData] rawString]));

            [[CPNotificationCenter defaultCenter] postNotificationName:NURESTPushCenterPushReceived object:self userInfo:JSONObject];
        }
        catch (e)
        {
            CPLog.error("RESTCAPPUCCINO PUSHCENTER: An error occured while processing a push event: " + e);
        }
    }

    if (_isRunning)
        [self _listenToNextEvent:JSONObject ? JSONObject.uuid : nil];
}

@end
