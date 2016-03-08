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

@class NURESTConnection;

NURESTConfirmationNotification = @"NURESTConfirmationNotification";
NURESTConfirmationCancelNotification = @"NURESTConfirmationCancelNotification";


@implementation NURESTConfirmation : CPObject
{
    CPArray             _choices         @accessors(property=choices);
    CPDate              _receivedDate    @accessors(property=receivedDate);
    CPNumber            _currentChoice   @accessors(property=currentChoice);
    CPString            _description     @accessors(property=description);
    CPString            _name            @accessors(property=name);
    NURESTConnection    _connection      @accessors(property=connection);
}


#pragma mark -
#pragma mark Class Methods

+ (void)RESTConfirmationWithName:(CPString)aName description:(CPString)aDescription choices:(CPArray)someChoices connection:(NURESTConnection)aConnection
{
    var confirmation = [[NURESTConfirmation alloc] init];
    [confirmation setName:aName];
    [confirmation setDescription:aDescription];
    [confirmation setChoices:someChoices];
    [confirmation setCurrentChoice:1];
    [confirmation setConnection:aConnection];
    [confirmation setReceivedDate:new Date()];

    return confirmation;
}

+ (void)postRESTConfirmationWithName:(CPString)aName description:(CPString)aDescription choices:(CPArray)someChoices connection:(NURESTConnection)aConnection
{
    [[NURESTConfirmation RESTConfirmationWithName:aName description:aDescription choices:someChoices connection:aConnection] post];
}


#pragma mark -
#pragma mark Utilities

- (void)confirm
{
    if (_currentChoice === nil)
        [CPException raise:CPInvalidArgumentException reason:@"confirmChoice is not set"];

    if (_currentChoice == 0)
    {
        [[CPNotificationCenter defaultCenter] postNotificationName:NURESTConfirmationCancelNotification object:self userInfo:nil];
        return;
    }

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

- (void)post
{
    [[CPNotificationCenter defaultCenter] postNotificationName:NURESTConfirmationNotification object:self userInfo:nil];
}

@end
