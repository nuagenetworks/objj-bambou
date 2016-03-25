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
@import "NURESTObject.j"
@import "NURESTLoginController.j"

@global Sha1

var NURESTAbstractRootCurrent = nil;


@implementation NURESTAbstractRoot : NURESTObject
{
    CPString    _APIKey                 @accessors(property=APIKey);
    CPString    _password               @accessors(property=password);
    CPString    _passwordConfirm        @accessors(property=passwordConfirm);
    CPString    _role                   @accessors(property=role);
    CPString    _userName               @accessors(property=userName);

    CPString    _newPassword            @accessors(property=newPassword);
}


#pragma mark -
#pragma mark Initialization

+ (id)current
{
    if (!NURESTAbstractRootCurrent)
        NURESTAbstractRootCurrent = [[[self class] alloc] init];

    return NURESTAbstractRootCurrent;
}

+ (CPString)RESTName
{
    [CPException raise:CPUnsupportedMethodException reason:"The NURESTAbstractRoot subclass must implement : '+ (CPString)RESTName'"];
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

- (id)init
{
    if (self = [super init])
    {
        [self exposeLocalKeyPathToREST:@"APIKey"];
        [self exposeLocalKeyPathToREST:@"password"];
        [self exposeLocalKeyPathToREST:@"role"];
        [self exposeLocalKeyPathToREST:@"userName"];
        [self exposeLocalKeyPathToREST:@"newPassword"];
        [self exposeLocalKeyPathToREST:@"passwordConfirm"];
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

    [RESTUserCopy setPassword:_newPassword ? Sha1.hash(_newPassword) : nil];

    // reset the login controller for this call as it needs to use password, and not API Key
    [[NURESTLoginController defaultController] setPassword:[self password]];
    [[NURESTLoginController defaultController] setAPIKey:nil];

    [self _manageChildObject:RESTUserCopy method:NURESTConnectionMethodPut andCallSelector:aSelector ofObject:anObject customConnectionHandler:@selector(_didUpdateRESTUser:) block:nil];

    [RESTUserCopy setNewPassword:nil];
    [RESTUserCopy setPasswordConfirm:nil];
    [RESTUserCopy setPasswordConfirm:nil];
}

- (void)_didUpdateRESTUser:(NURESTConnection)aConnection
{
    // then we restore the login controller API Key.
    [[NURESTLoginController defaultController] setPassword:nil];
    [[NURESTLoginController defaultController] setAPIKey:[self APIKey]];

    [self setNewPassword:nil];
    [self setPasswordConfirm:nil];
    [self setPasswordConfirm:nil];

    [self _didPerformStandardOperation:aConnection];
}

@end
