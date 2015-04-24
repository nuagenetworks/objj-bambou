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
    CPString    _APIKey                 @accessors(property=APIKey);
    CPString    _password               @accessors(property=password);
    CPString    _role                   @accessors(property=role);
    CPString    _userName               @accessors(property=userName);

    CPString    _desiredNewPassword;
}


#pragma mark -
#pragma mark Initialization

+ (id)defaultUser
{
    if (!NURESTBasicUserCurrent)
        NURESTBasicUserCurrent = [[[self class] alloc] init];

    return NURESTBasicUserCurrent;
}

+ (CPString)RESTName
{
    [CPException raise:CPUnsupportedMethodException reason:"The NURESTBasicUser subclass must implement : '+ (CPString)RESTName'"];
}

+ (BOOL)RESTResourceNameFixed
{
    return YES;
}

- (CPURL)RESTResourceURL
{
    return [CPURL URLWithString:[self RESTName] + @"/" relativeToURL:[[self class] RESTBaseURL]];
}

- (CPURL)RESTResourceURLForChildrenClass:(Class)aChildrenClass
{
    return [CPURL URLWithString:[aChildrenClass RESTResourceName] + @"/" relativeToURL:[[self class] RESTBaseURL]];
}


#pragma mark -
#pragma mark Initialization

- (id)init
{
    if (self = [super init])
    {
        [self exposeLocalKeyPathToREST:@"APIKey"];
        [self exposeLocalKeyPathToREST:@"password"];
        [self exposeLocalKeyPathToREST:@"role"];
        [self exposeLocalKeyPathToREST:@"userName"];
    }

    return self;
}


#pragma mark -
#pragma mark Utilties

- (void)hasRoles:(CPArray)someRoles
{
    return [someRoles containsObject:_role];
}


#pragma mark -
#pragma mark Overrides

- (void)saveAndCallSelector:(SEL)aSelector ofObject:(id)anObject password:(CPString)aPassword
{
    var RESTUserCopy = [self duplicate];

    [RESTUserCopy setPassword:_desiredNewPassword ? Sha1.hash(_desiredNewPassword) : nil];

    // reset the login controller for this call as it needs to use password, and not API Key
    [[NURESTLoginController defaultController] setPassword:aPassword];
    [[NURESTLoginController defaultController] setAPIKey:nil];

    [self _manageChildObject:RESTUserCopy method:NURESTConnectionMethodPut andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didUpdateRESTUser:)];
}

- (void)_didUpdateRESTUser:(NURESTConnection)aConnection
{
    // then we restore the login controller API Key.
    [[NURESTLoginController defaultController] setPassword:nil];
    [[NURESTLoginController defaultController] setAPIKey:_APIKey];

    [self _didPerformStandardOperation:aConnection];
}

@end
