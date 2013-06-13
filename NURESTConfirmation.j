/*
*   Filename:         NURESTConfirmation.j
*   Created:          Fri May  3 18:01:22 PDT 2013
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

NURESTConfirmationNotification = @"NURESTConfirmationNotification";


@implementation NURESTConfirmation : CPObject
{
    CPArray             choices         @accessors;
    CPDate              receivedDate    @accessors;
    CPNumber            currentChoice   @accessors;
    CPString            description     @accessors;
    CPString            name            @accessors;
    NURESTConnection    connection      @accessors;
}

+ (void)RESTConfirmationWithName:(CPString)aName description:(CPString)aDescription choices:(CPArray)someChoices
{
    var confirmation = [[NURESTConfirmation alloc] init];
    [confirmation setName:aName];
    [confirmation setDescription:aDescription];
    [confirmation setChoices:someChoices];
    [confirmation setCurrentChoice:1];
    [confirmation setReceivedDate:new Date()];

    return confirmation;
}

+ (void)postRESTConfirmationWithName:(CPString)aName description:(CPString)aDescription choices:(CPArray)someChoices connection:(NURESTConnection)aConnection
{
    var confirmation = [NURESTConfirmation RESTConfirmationWithName:aName description:aDescription choices:someChoices];

    [confirmation setConnection:aConnection];

    [[CPNotificationCenter defaultCenter] postNotificationName:NURESTConfirmationNotification object:confirmation userInfo:nil];
}

@end
