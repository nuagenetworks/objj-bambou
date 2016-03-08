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
