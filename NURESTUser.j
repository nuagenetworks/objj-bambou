/*
****************************************************************************
*
*   Filename:         NURESTUser.j
*
*   Created:          Mon Apr  2 11:23:45 PST 2012
*
*   Description:      Cappuccino UI
*
*   Project:          Cloud Network Automation - Nuage - Data Center Service Delivery - IPD
*
*
***************************************************************************
*
*                 Source Control System Information
*
*   $Id: something $
*
*
*
****************************************************************************
*
* Copyright (c) 2011-2012 Alcatel, Alcatel-Lucent, Inc. All Rights Reserved.
*
* This source code contains confidential information which is proprietary to Alcatel.
* No part of its contents may be used, copied, disclosed or conveyed to any party
* in any manner whatsoever without prior written permission from Alcatel.
*
* Alcatel-Lucent is a trademark of Alcatel-Lucent, Inc.
*
*
*****************************************************************************
*/


@import <Foundation/Foundation.j>


var NURESTUserCurrent = nil;

@implementation NURESTUser : NURESTObject
{
    CPString                _firstName              @accessors(property=firstName);
    CPString                _lastName               @accessors(property=lastName);
    CPString                _userName               @accessors(property=userName);
    CPString                _email                  @accessors(property=email);
    CPString                _enterpriseID           @accessors(property=enterpriseID);
    CPArray                 _groupIDs               @accessors(property=groupIDs);
    CPString                _userType               @accessors(property=userType);

    CPArray                 _enterprises            @accessors(property=enterprises);
    NUEnterprisesFetcher    _enterprisesFetcher     @accessors(property=enterprisesFetcher);
}


#pragma mark -
#pragma mark Class methods

+ (NURESTUser)defaultUser
{
    if (!NURESTUserCurrent)
        NURESTUserCurrent = [[NURESTUser alloc] init];

    return NURESTUserCurrent;
}


#pragma mark -
#pragma mark Initialization

- (NURESTUser)init
{
    if (self = [super init])
    {
        _enterprises = [CPArray array];

        _enterprisesFetcher = [[NUEnterprisesFetcher alloc] init];
        [_enterprisesFetcher setEntity:self];

        // [self exposeLocalKeyPathToRest:@"firstName"];
        // [self exposeLocalKeyPathToRest:@"lastName"];
        // [self exposeLocalKeyPathToRest:@"userName"];
        // [self exposeLocalKeyPathToRest:@"email"];
    }

    return self;
}


#pragma mark -
#pragma mark Rest

- (CPURL)RESTQueryURL
{
    return [CPURL URLWithString:@"enterprises" relativeToURL:_baseURL]; //@TODO
}


- (void)fetchAndCallSelector:(SEL)aSelector ofObject:(id)anObject
{
    var request = [CPURLRequest requestWithURL:[self RESTQueryURL]],
        someUserInfo = (aSelector && anObject) ? [anObject, aSelector] : nil;

    [request setHTTPMethod:@"GET"];

    [self sendRESTCall:request andPerformSelector:@selector(_didFetch:) ofObject:self userInfo:someUserInfo];
}

/*! @ignore
*/
- (void)_didFetch:(NURESTConnection)aConnection
{
    var JSON = [[aConnection responseData] JSONObject];

    //[self objectFromJSON:JSON.entities[0]];

    if ([aConnection userInfo])
        [[aConnection userInfo][0] performSelector:[aConnection userInfo][1] withObject:aConnection];
}

@end
