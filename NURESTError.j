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
    CPDate              receivedDate    @accessors;
    CPString            description     @accessors;
    CPString            name            @accessors;
    NURESTConnection    connection      @accessors;
}

+ (void)RESTErrorWithName:(CPString)aName description:(CPString)aDescription
{
    var error = [[NURESTError alloc] init];
    [error setName:aName];
    [error setDescription:aDescription];
    [error setReceivedDate:new Date()];

    return error;
}

+ (void)postRESTErrorWithName:(CPString)aName description:(CPString)aDescription connection:(NURESTConnection)aConnection
{
    var error = [NURESTError RESTErrorWithName:aName description:aDescription];

    [error setConnection:aConnection];

    [[CPNotificationCenter defaultCenter] postNotificationName:NURESTErrorNotification object:error userInfo:nil];
}

@end
