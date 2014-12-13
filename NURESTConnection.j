/*
*   Filename:         NURESTConnection.j
*   Created:          Tue Oct  9 11:49:32 PDT 2012
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

var NURESTConnectionLastActionTimer,
    NURESTConnectionTimeout = 1200000,
    NURESTConnectionAutoConfirm = NO;


/*! Enhanced version of CPURLConnection
*/
@implementation NURESTConnection : CPObject
{
    BOOL            _usesAuthentication     @accessors(property=usesAuthentication);
    BOOL            _hasTimeouted           @accessors(getter=hasTimeouted);
    BOOL            _ignoreRequestIdle      @accessors(property=ignoreRequestIdle);
    CPData          _responseData           @accessors(getter=responseData);
    CPString        _errorMessage           @accessors(property=errorMessage);
    CPURLRequest    _request                @accessors(property=request);
    HTTPRequest     _HTTPRequest            @accessors(getter=nativeRequest);
    id              _internalUserInfo       @accessors(property=internalUserInfo);
    id              _target                 @accessors(property=target);
    id              _userInfo               @accessors(property=userInfo);
    int             _responseCode           @accessors(getter=responseCode);
    SEL             _selector               @accessors(property=selector);
    int             _XHRTimeout             @accessors(property=timeout);

    BOOL            _isCanceled;
}


#pragma mark -
#pragma mark Class Methods

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
    NURESTConnectionAutoConfirm = isEnabled;
}

+ (void)setTimeoutValue:(int)aValue
{
    NURESTConnectionTimeout = aValue;
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
        errorDescription = @"An error occured in VSD Server, but it was unable to correctly report what exactly happened.";
    }

    switch (responseCode)
    {
        case NURESTConnectionResponseCodeEmpty:
        case NURESTConnectionResponseCodeSuccess:
        case NURESTConnectionResponseCodeCreated:
            return YES;

        case NURESTConnectionResponseCodeMultipleChoices:
            if (NURESTConnectionAutoConfirm)
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

            CPLog.error("RESTCAPPUCCINO: Connection error with code 0. Sending NURESTConnectionFailureNotification notification and exiting.");
            [[CPNotificationCenter defaultCenter] postNotificationName:NURESTConnectionFailureNotification object:self userInfo:nil];

            return NO;


        default:

            CPLog.error(@"RESTCAPPUCCINO: Report this error, because this should not happen:\n\n%@", [[aConnection responseData] rawString]);

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
        _request = aRequest;
        _isCanceled = NO;
        _hasTimeouted = NO;
        _usesAuthentication = YES;
        _XHRTimeout = 300000;
        _ignoreRequestIdle = NO;
        _HTTPRequest = new CFHTTPRequest();
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

- (void)reset
{
    _HTTPRequest  = new CFHTTPRequest();
    _responseData = nil;
    _responseCode = nil;
    _errorMessage = nil;
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

- (void)_XHRDidTimeout
{
    _hasTimeouted = YES;

    if (_target && _selector)
        [_target performSelector:_selector withObject:self];

    [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
}

@end
