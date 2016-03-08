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

@class NURESTLoginController

NURESTConnectionResponseCodeBadRequest          = 400;
NURESTConnectionResponseCodeConflict            = 409;
NURESTConnectionResponseCodeCreated             = 201;
NURESTConnectionResponseCodeEmpty               = 204;
NURESTConnectionResponseCodeInternalServerError = 500;
NURESTConnectionResponseCodeMethodNotAllowed    = 405;
NURESTConnectionResponseCodeMultipleChoices     = 300;
NURESTConnectionResponseCodeNotFound            = 404;
NURESTConnectionResponseCodePermissionDenied    = 403;
NURESTConnectionResponseCodePreconditionFailed  = 412;
NURESTConnectionResponseCodeServiceUnavailable  = 503;
NURESTConnectionResponseCodeSuccess             = 200;
NURESTConnectionResponseCodeUnauthorized        = 401;
NURESTConnectionResponseCodeZero                = 0;
NURESTConnectionTimeout                         = 42;

NURESTConnectionMethodDelete                    = @"DELETE";
NURESTConnectionMethodGet                       = @"GET";
NURESTConnectionMethodPost                      = @"POST";
NURESTConnectionMethodPut                       = @"PUT";

NURESTConnectionFailureNotification             = @"NURESTConnectionFailureNotification";
NURESTConnectionIdleTimeoutNotification         = @"NURESTConnectionIdleTimeoutNotification";
NURESTConnectionAutoConfirmAPIIdentifiers       = @"NURESTConnectionAutoConfirmAPIIdentifiers";

var NURESTConnectionLastActionTimer,
    NURESTConnectionTimeout = 1200000,
    NURESTConnectionGeneralAutoConfirm = NO;


/*! Enhanced version of CPURLConnection
*/
@implementation NURESTConnection : CPObject
{
    BOOL            _hasTimeouted           @accessors(getter=hasTimeouted);
    BOOL            _ignoreRequestIdle      @accessors(property=ignoreRequestIdle);
    BOOL            _usesAuthentication     @accessors(property=usesAuthentication);
    CPData          _responseData           @accessors(getter=responseData);
    CPString        _errorMessage           @accessors(property=errorMessage);
    CPString        _transactionID          @accessors(getter=transactionID);
    CPURLRequest    _request                @accessors(property=request);
    id              _internalUserInfo       @accessors(property=internalUserInfo);
    id              _target                 @accessors(property=target);
    id              _userInfo               @accessors(property=userInfo);
    int             _responseCode           @accessors(getter=responseCode);
    int             _XHRTimeout             @accessors(property=timeout);
    SEL             _selector               @accessors(property=selector);

    HTTPRequest     _HTTPRequest;
    BOOL            _isCanceled;
}


#pragma mark -
#pragma mark Class Methods

+ (void)initialize
{
    [[CPUserDefaults standardUserDefaults] registerDefaults:@{NURESTConnectionAutoConfirmAPIIdentifiers: []}];
}

/*! Initialize a new NURESTConnection
    @param aRequest the CPURLRequest to send
    @param anObject a random object that is the target of the result events
    @param aSuccessSelector the selector to send to anObject in case of success
    @param anErrorSelector the selector to send to anObject in case of error
    @return NURESTConnection fully ready NURESTConnection
*/
+ (NURESTConnection)connectionWithRequest:(CPURLRequest)aRequest target:(CPObject)anObject selector:(SEL)aSelector
{
    var connection = [[NURESTConnection alloc] initWithRequest:aRequest];
    [connection setTarget:anObject];
    [connection setSelector:aSelector];

    return connection;
}

+ (void)setAutoConfirm:(BOOL)isEnabled
{
    NURESTConnectionGeneralAutoConfirm = isEnabled;
}

+ (void)setTimeoutValue:(int)aValue
{
    NURESTConnectionTimeout = aValue;
}

+ (BOOL)isConnectionSuccess:(NURESTConnection)aConnection
{
    switch ([aConnection responseCode])
    {
        case NURESTConnectionResponseCodeEmpty:
        case NURESTConnectionResponseCodeSuccess:
        case NURESTConnectionResponseCodeCreated:
        case NURESTConnectionResponseCodeMultipleChoices:
            return YES;

        case NURESTConnectionResponseCodeConflict:
        case NURESTConnectionResponseCodePermissionDenied:
        case NURESTConnectionResponseCodeUnauthorized:
        case NURESTConnectionResponseCodeNotFound:
        case NURESTConnectionResponseCodeMethodNotAllowed:
        case NURESTConnectionResponseCodePreconditionFailed:
        case NURESTConnectionResponseCodeServiceUnavailable:
        case NURESTConnectionResponseCodeInternalServerError:
        case NURESTConnectionResponseCodeBadRequest:
        case NURESTConnectionResponseCodeInternalServerError:
        case NURESTConnectionResponseCodeZero:
            return NO;

        default:
            [CPException raise:CPInvalidArgumentException reason:@"Error code " + [aConnection responseCode] + " is unknown."];
    }
}

+ (BOOL)handleResponseForConnection:(NURESTConnection)aConnection postErrorMessage:(BOOL)shouldPost
{
    var responseObject   = [[aConnection responseData] JSONObject],
        responseCode     = [aConnection responseCode],
        containsInfo     = (responseObject && responseObject.errors),
        errorName,
        errorDescription;

    try
    {
        errorName        = containsInfo ? responseObject.errors[0].descriptions[0].title : nil;
        errorDescription = containsInfo ? responseObject.errors[0].descriptions[0].description : nil;
    }
    catch(e)
    {
        errorName = @"Malformed Server Error for code " + responseCode;
        errorDescription = @"An error occured in the server, but it was unable to correctly report what exactly happened.";
    }

    switch (responseCode)
    {
        case NURESTConnectionResponseCodeEmpty:
        case NURESTConnectionResponseCodeSuccess:
        case NURESTConnectionResponseCodeCreated:
            return YES;

        case NURESTConnectionResponseCodeMultipleChoices:
            if ([aConnection _isAutoConfirm])
                [[NURESTConfirmation RESTConfirmationWithName:errorName description:errorDescription choices:responseObject.choices connection:aConnection] confirm];
            else
                [NURESTConfirmation postRESTConfirmationWithName:errorName description:errorDescription choices:responseObject.choices connection:aConnection];

            return NO;

        case NURESTConnectionResponseCodeConflict:

            if (!shouldPost)
                return YES;

            [NURESTError postRESTErrorWithName:errorName description:errorDescription connection:aConnection];

            return NO;


        case NURESTConnectionResponseCodePermissionDenied:
        case NURESTConnectionResponseCodeUnauthorized:

            if (!shouldPost)
                return YES;

            var errorName        = @"Permission denied",
                errorDescription = @"You are not allowed to access this resource.";

            [NURESTError postRESTErrorWithName:errorName description:errorDescription connection:aConnection];

            return NO;


        case NURESTConnectionResponseCodeNotFound:
        case NURESTConnectionResponseCodeMethodNotAllowed:
        case NURESTConnectionResponseCodePreconditionFailed:
        case NURESTConnectionResponseCodeServiceUnavailable:

            if (!shouldPost)
                return YES;

            [NURESTError postRESTErrorWithName:errorName description:errorDescription connection:aConnection];

            return NO;

        case NURESTConnectionResponseCodeBadRequest:

            if (!shouldPost)
                return YES;

            var errorName        = @"Bad Request",
                errorDescription = @"This API call cannot be processed by the server. Please report this to the UI team";

            [NURESTError postRESTErrorWithName:errorName description:errorDescription connection:aConnection];

            return NO;


        case NURESTConnectionResponseCodeInternalServerError:

            var errorName        = errorName || @"[CRITICAL] Internal Server Error",
                errorDescription = errorDescription || @"Please check the log and report this error to the server team";

            [NURESTError postRESTErrorWithName:errorName description:errorDescription connection:aConnection];

            return NO;

        case NURESTConnectionResponseCodeZero:

            CPLog.error("BAMBOU: Connection error with code 0. Sending NURESTConnectionFailureNotification notification and exiting.");
            [[CPNotificationCenter defaultCenter] postNotificationName:NURESTConnectionFailureNotification object:self userInfo:nil];

            return NO;


        default:

            CPLog.error(@"BAMBOU: Report this error, because this should not happen:\n\n%@", [[aConnection responseData] rawString]);

            return NO;
    }
}

+ (void)resetIdleTimeout
{
    if (!NURESTConnectionTimeout)
        return;

    if (NURESTConnectionLastActionTimer)
        clearTimeout(NURESTConnectionLastActionTimer);

    var lastUserEventTimeStamp = [[CPApp currentEvent] timestamp];

    NURESTConnectionLastActionTimer = setTimeout(function()
    {
        if (!NURESTConnectionTimeout)
            return;

        [[CPNotificationCenter defaultCenter] postNotificationName:NURESTConnectionIdleTimeoutNotification object:self userInfo:lastUserEventTimeStamp];
    }, NURESTConnectionTimeout);
}


#pragma mark -
#pragma mark Initialization

/*! Initialize a NURESTConnection with a CPURLRequest
    @param aRequest the request to user
*/
- (id)initWithRequest:aRequest
{
    if (self = [super init])
    {
        _hasTimeouted       = NO;
        _HTTPRequest        = new CFHTTPRequest();
        _ignoreRequestIdle  = NO;
        _isCanceled         = NO;
        _request            = aRequest;
        _transactionID      = [CPString UUID];
        _usesAuthentication = YES;
        _XHRTimeout         = 300000;
    }

    return self;
}


/*! Start the connection
*/
- (void)start
{
    _isCanceled = NO;
    _hasTimeouted = NO;

    if (!_ignoreRequestIdle)
        [[self class] resetIdleTimeout];

    try
    {
        _HTTPRequest.open([_request HTTPMethod], [[_request URL] absoluteString], YES);

        _HTTPRequest._nativeRequest.timeout   = _XHRTimeout;
        _HTTPRequest.onreadystatechange       = function() { [self _readyStateDidChange]; }
        _HTTPRequest._nativeRequest.ontimeout = function() { [self _XHRDidTimeout]; }

        var fields = [_request allHTTPHeaderFields],
            key    = nil,
            keys   = [fields keyEnumerator];

        while (key = [keys nextObject])
            _HTTPRequest.setRequestHeader(key, [fields objectForKey:key]);

        if (_usesAuthentication)
        {
            _HTTPRequest.setRequestHeader("X-Nuage-Organization", [[NURESTLoginController defaultController] company]);
            _HTTPRequest.setRequestHeader("Authorization", [[NURESTLoginController defaultController] RESTAuthString]);
        }

        if ([[NURESTLoginController defaultController] isImpersonating])
            _HTTPRequest.setRequestHeader("X-Nuage-Proxy", [[NURESTLoginController defaultController] impersonation]);

        _HTTPRequest.send([_request HTTPBody]);
    }
    catch (anException)
    {
        _errorMessage = anException;
        if (_target && _selector)
            [_target performSelector:_selector withObject:self];
    }
}

/*! Abort the connection
*/
- (void)cancel
{
    _isCanceled = YES;

    try { _HTTPRequest.abort(); } catch (e) {}
}

/*! Reset the connection
*/
- (void)reset
{
    _errorMessage  = nil;
    _HTTPRequest   = new CFHTTPRequest();
    _responseCode  = nil;
    _responseData  = nil;
    _transactionID = [CPString UUID];
}

/*! @ignore
*/
- (void)_readyStateDidChange
{
    if (_HTTPRequest.readyState() === CFHTTPRequest.CompleteState)
    {
        _responseCode = _HTTPRequest.status();
        _responseData = [CPData dataWithRawString:_HTTPRequest.responseText()];

        if (_target && _selector)
            [_target performSelector:_selector withObject:self];

        [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
    }
}

/*! @ignore
*/
- (void)_XHRDidTimeout
{
    _hasTimeouted = YES;

    if (_target && _selector)
        [_target performSelector:_selector withObject:self];

    [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
}

- (CPString)valueForResponseHeader:(CPString)aHeader
{
    return _HTTPRequest.getResponseHeader(aHeader);
}


#pragma mark -
#pragma mark Auto Confirmation

/*! Register or unregister the API Identifier to be auto confirm
    for the current API Identifier
*/
- (void)enableAutoConfirm:(BOOL)shouldEnable
{
    var ignoredAPIs = [[CPUserDefaults standardUserDefaults] objectForKey:NURESTConnectionAutoConfirmAPIIdentifiers],
        identifier  = [self _APIIdentifier],
        registered  = [ignoredAPIs containsObject:identifier];

    if ((shouldEnable && registered) || (!shouldEnable && !registered))
        return;

    if (shouldEnable)
        [ignoredAPIs addObject:identifier];
    else
        [ignoredAPIs removeObject:identifier];

    [[CPUserDefaults standardUserDefaults] setObject:ignoredAPIs forKey:NURESTConnectionAutoConfirmAPIIdentifiers];
}

/*! @ignore
    Returns if the current connection is marked
    as auto confirm
*/
- (BOOL)_isAutoConfirm
{
    return NURESTConnectionGeneralAutoConfirm || [[[CPUserDefaults standardUserDefaults] objectForKey:NURESTConnectionAutoConfirmAPIIdentifiers] containsObject:[self _APIIdentifier]];
}

/*! @ignore
    Returns an unique identifier for an API.
    This will basically removes UUID from the URL
*/
- (CPString)_APIIdentifier
{
    return [[_request URL] absoluteString].split("?")[0].replace(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g, "UUID");
}

@end
