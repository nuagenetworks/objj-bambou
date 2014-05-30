/*
*   Filename:         NURESTError.j
*   Created:          Fri May  3 17:56:47 PDT 2013
*   Author:           Antoine Mercadal <antoine.mercadal@alcatel-lucent.com>
*   Description:      VSA
*   Project:          VSD - Nuage - Data Center Service Delivery - IPD
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

@class NURESTConnection;

NURESTErrorNotification = @"NURESTErrorNotification";


@implementation NURESTError : CPObject
{
    CPDate              _receivedDate    @accessors(property=receivedDate);
    CPString            _description     @accessors(property=description);
    CPString            _name            @accessors(property=name);
    NURESTConnection    _connection      @accessors(property=connection);
}


#pragma mark -
#pragma mark Class Methods

+ (void)RESTErrorWithName:(CPString)aName description:(CPString)aDescription connection:(NURESTConnection)aConnection
{
    var error = [[NURESTError alloc] init];
    [error setName:aName];
    [error setDescription:aDescription];
    [error setConnection:aConnection];
    [error setReceivedDate:new Date()];

    return error;
}

+ (void)postRESTErrorWithName:(CPString)aName description:(CPString)aDescription connection:(NURESTConnection)aConnection
{
    [[NURESTError RESTErrorWithName:aName description:aDescription connection:aConnection] post];
}


#pragma mark -
#pragma mark Utilities

- (void)post
{
    [[CPNotificationCenter defaultCenter] postNotificationName:NURESTErrorNotification object:self userInfo:nil];
}

@end
