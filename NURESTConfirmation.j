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
    CPArray             _choices         @accessors(property=choices);
    CPDate              _receivedDate    @accessors(property=receivedDate);
    CPNumber            _currentChoice   @accessors(property=currentChoice);
    CPString            _description     @accessors(property=description);
    CPString            _name            @accessors(property=name);
    NURESTConnection    _connection      @accessors(property=connection);
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

- (void)confirm
{
    if (_currentChoice === nil)
        [CPException raise:CPInvalidArgumentException reason:@"confirmChoice is not set"];

    if (_currentChoice == 0)
        return;

    var request = [[CPURLRequest alloc] init],
        cleanedUpURL = [[[_connection request] URL] absoluteString].split("?")[0];

    [request setURL:[CPURL URLWithString:cleanedUpURL + "?responseChoice=" + _currentChoice]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPMethod:[[_connection request] HTTPMethod]];
    [request setHTTPBody:[[_connection request] HTTPBody]];

    [_connection setRequest:request];
    [_connection reset];
    [_connection start];
}

@end
