/*
*   Filename:         NURESTLoginController.j
*   Created:          Tue Oct  9 11:49:41 PDT 2012
*   Author:           Antoine Mercadal <antoine.mercadal@alcatel-lucent.com>
*   Description:      VSA
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
@import "Resources/SHA1.js"

@global btoa
@class NURESTPushCenter

var DefaultNURESTLoginController;

@implementation NURESTLoginController : CPObject
{
    BOOL        _isImpersonating   @accessors(getter=isImpersonating);
    CPString    _APIKey            @accessors(property=APIKey);
    CPString    _company           @accessors(property=company);
    CPString    _impersonation     @accessors(getter=impersonation);
    CPString    _password          @accessors(property=password);
    CPString    _user              @accessors(property=user);
    CPURL       _URL               @accessors(property=URL);
}


#pragma mark -
#pragma mark Class Methods

+ (NULoginController)defaultController
{
    if (!DefaultNURESTLoginController)
        DefaultNURESTLoginController = [[NURESTLoginController alloc] init];
    return DefaultNURESTLoginController;
}


#pragma mark -
#pragma mark Custom Getter and Accessors

- (CPString)RESTAuthString
{
    // Generate the auth string. If APIToken is set, it'll be used. Otherwise, the clear
    // text password will be sent. Users of NURESTLoginController are responsible to
    // clean the password property.
    var authString = [CPString stringWithFormat:@"%s:%s", _user, _APIKey || _password];
    return @"XREST " + btoa(authString);
}


#pragma mark -
#pragma mark Utilities

- (void)reset
{
    _APIKey          = nil;
    _company         = nil;
    _password        = nil;
    _user            = nil;
    _URL             = nil;
    _impersonation   = nil;
    _isImpersonating = NO;
}


#pragma mark -
#pragma mark Impersonation

- (void)impersonateUser:(CPString)aUser enterprise:(CPString)anEnterprise
{
    if (!aUser || !anEnterprise)
        [CPException raise:CPInvalidArgumentException reason:@"you must set a user name and an enterprise name to begin impersonification"];

    _isImpersonating = YES;
    _impersonation = aUser + @":" + anEnterprise;

    [[NURESTPushCenter defaultCenter] stop];
    [[NURESTPushCenter defaultCenter] start];
}

- (void)stopImpersonation
{
    if (!_isImpersonating)
        return;

    _isImpersonating = NO;
    _impersonation = nil;

    [[NURESTPushCenter defaultCenter] stop];
    [[NURESTPushCenter defaultCenter] start];
}

@end
