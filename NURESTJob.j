/*
*   Filename:         NURESTJob.j
*   Created:          Mon Apr 20 11:53:48 PDT 2015
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

NURESTJobStatusFAILED  = "FAILED";
NURESTJobStatusRUNNING = "RUNNING";
NURESTJobStatusSUCCESS = "SUCCESS";


@implementation NURESTJob : NURESTObject
{
    CPDictionary        _parameters         @accessors(property=parameters);
    CPDictionary        _result             @accessors(property=result);
    CPString            _command            @accessors(property=command);
    CPString            _status             @accessors(property=status);
    float               _progress           @accessors(property=progress);
}


#pragma mark -
#pragma mark Class Method

+ (CPString)RESTName
{
    return @"job";
}


#pragma mark -
#pragma mark Initialization

- (id)init
{
    if (self = [super init])
    {
        [self exposeLocalKeyPathToREST:@"command"];
        [self exposeLocalKeyPathToREST:@"parameters"];
        [self exposeLocalKeyPathToREST:@"progress"];
        [self exposeLocalKeyPathToREST:@"result"];
        [self exposeLocalKeyPathToREST:@"status"];
    }

    return self;
}

@end
