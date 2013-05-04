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

@global NURESTConnection;

NURESTErrorNotification = @"NURESTErrorNotification";

@implementation NURESTError : CPObject
{
    NURESTConnection    connection  @accessors;
    CPString            name        @accessors;
    CPString            description @accessors;
}

+ (void)postRESTErrorWithName:(CPString)aName description:(CPString)aDescription connection:(NURESTConnection)aConnection
{
    var error = [[NURESTError alloc] init];
    [error setName:aName];
    [error setDescription:aDescription];
    [error setConnection:aConnection];

    [[CPNotificationCenter defaultCenter] postNotificationName:NURESTErrorNotification
                                                object:error
                                             userInfo:nil];
}

@end
