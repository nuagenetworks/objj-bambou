/*
*   Filename:         NURESTModelController.j
*   Created:          Tue Oct 21 15:26:05 PDT 2014
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

var NURESTModelControllerDefault;


@implementation NURESTModelController : CPObject
{
    CPDictionary    _modelRegistry;
}

#pragma mark -
#pragma mark Class Methods

+ (id)defaultController
{
    if (!NURESTModelControllerDefault)
        NURESTModelControllerDefault = [[NURESTModelController alloc] init];

    return NURESTModelControllerDefault;
}

#pragma mark -
#pragma mark Initialization

- (id)init
{
    if (self = [super init])
    {
        _modelRegistry = @{};
    }

    return self
}


#pragma mark -
#pragma mark Models Registration

- (void)registerModelClass:(Class)aClass
{
    if (![_modelRegistry containsKey:[aClass RESTName]])
        [_modelRegistry setObject:[] forKey:[aClass RESTName]];

    if (![[_modelRegistry objectForKey:[aClass RESTName]] containsObject:aClass])
        [[_modelRegistry objectForKey:[aClass RESTName]] addObject:aClass];
}


#pragma mark -
#pragma mark Accessing Registred Classes

- (Class)modelClassForRESTName:(CPString)aRESTName
{
    return [[_modelRegistry objectForKey:aRESTName] firstObject]
}

- (CPArray)modelClassesForRESTName:(CPString)aRESTName
{
    return [_modelRegistry objectForKey:aRESTName];
}

- (NURESTObject)newObjectWithRESTName:(CPString)aRESTName
{
    return [[self modelClassForRESTName:aRESTName] new];
}

@end
