/*
*   Filename:         RNURESTBasicUser.j
*   Created:          Thu May  9 14:41:33 PDT 2013
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
@import "NURESTObject.j"
@import "NURESTLoginController.j"

@global Sha1

var NURESTBasicUserCurrent = nil;

@implementation NURESTBasicUser : NURESTObject
{
    CPString    _APIKey     @accessors(property=APIKey);
    CPString    _password   @accessors(property=password);
    CPString    _userName   @accessors(property=userName);

    CPString    _desiredNewPassword;
}


#pragma mark -
#pragma mark Class Method

+ (CPString)RESTName
{
    [CPException raise:CPUnsupportedMethodException reason:"The NURESTBasicUser subclass must implement : '+ (CPString)RESTName'"];
}

+ (id)defaultUser
{
    if (!NURESTBasicUserCurrent)
        NURESTBasicUserCurrent = [[[self class] alloc] init];

    return NURESTBasicUserCurrent;
}


#pragma mark -
#pragma mark Initialization

- (id)init
{
    if (self = [super init])
    {
        [self exposeLocalKeyPathToREST:@"password"];
        [self exposeLocalKeyPathToREST:@"userName"];
        [self exposeLocalKeyPathToREST:@"APIKey"];
    }

    return self;
}


#pragma mark -
#pragma mark Rest

- (void)prepareUpdatePassword:(CPString)aNewPassword
{
    _desiredNewPassword = aNewPassword;
}

- (void)saveAndCallSelector:(SEL)aSelector ofObject:(id)anObject password:(CPString)aPassword
{
    var request = [CPURLRequest requestWithURL:[self RESTResourceURL]],
        someUserInfo = (aSelector && anObject) ? [anObject, aSelector] : nil;

    if (_desiredNewPassword)
        [self setPassword:Sha1.hash(_desiredNewPassword)];

    var updatedUserString = JSON.stringify([self objectToJSON]);
    [[NURESTLoginController defaultController] setPassword:aPassword];
    [[NURESTLoginController defaultController] setAPIKey:nil];

    [request setHTTPMethod:NURESTConnectionMethodPut];
    [request setHTTPBody:updatedUserString];
    [self sendRESTCall:request performSelector:@selector(_didReceiveRESTUserSaveReply:) ofObject:self andPerformRemoteSelector:aSelector ofObject:anObject userInfo:someUserInfo];
}

- (void)_didReceiveRESTUserSaveReply:(NURESTConnection)aConnection
{
    [[NURESTLoginController defaultController] setPassword:nil];
    [[NURESTLoginController defaultController] setAPIKey:_APIKey];

    [self _didPerformStandardOperation:aConnection];
}


#pragma mark -
#pragma mark CPCoding Compliance

- (id)initWithCoder:(CPCoder)aCoder
{
    if (self = [super initWithCoder:aCoder])
    {
        _APIKey         = [aCoder decodeObjectForKey:@"_APIKey"];
        _password       = [aCoder decodeObjectForKey:@"_password"];
        _userName       = [aCoder decodeObjectForKey:@"_userName"];
    }

    return self;
}

/*! CPCoder compliance
*/
- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];

    [aCoder encodeObject:_APIKey forKey:@"_APIKey"];
    [aCoder encodeObject:_password forKey:@"_password"];
    [aCoder encodeObject:_userName forKey:@"_userName"];
}

@end
