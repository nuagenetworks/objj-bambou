/*
*   Filename:         NURESTNestedObject.j
*   Created:          Tue Nov 19 15:49:33 PST 2013
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


@implementation NURESTNestedObject : CPObject
{
    class           _nestedObjectClass      @accessors(property=nestedObjectClass);
    CPString        _nestedObjectIDKeyPath  @accessors(property=nestedObjectIDKeyPath);
    NURESTObject    _nestedObject           @accessors(property=nestedObject);
    NURESTObject    _parentObject           @accessors(property=parentObject);

    id              _lastKnownValue;
}

#pragma mark -
#pragma mark Initialization

/*! Initialize the NURESTNestedObject
    @param anObject the parentObject
    @param aKeyPath the parentObject's key path that stores the nestedObject ID
    @param aClass the class of the nestedObject
*/
- (void)initWithParentObject:(NURESTObject)anObject nestedObjectIDKeyPath:(CPString)aKeyPath nestedObjectClass:(class)aClass
{
    if (self = [super init])
    {
        _nestedObjectIDKeyPath = aKeyPath;
        _nestedObjectClass = aClass;
        [self setParentObject:anObject];
    }

    return self;
}


#pragma mark -
#pragma mark Custom Getters and Setters

/*! Sets the parent object
    It will start to listen to the current value of key path nestedObjectIDKeyPath
    nestedObjectIDKeyPath MUST be set prior to setting the parentObject
    @param anObject the parentObject
*/
- (void)setParentObject:(NURESTObject)anObject
{
    if (_parentObject)
        [_parentObject removeObserver:self forKeyPath:_nestedObjectIDKeyPath];

    [self willChangeValueForKey:@"parentObject"];
    _parentObject = anObject;
    [self didChangeValueForKey:@"parentObject"];

    if (_parentObject)
        [_parentObject addObserver:self forKeyPath:_nestedObjectIDKeyPath options:nil context:nil];
}


#pragma mark -
#pragma mark Listener

/*! @ignore
    Message sent if _nestedObjectIDKeyPath is updated.
    If it's different, re fetch the nested object
    If empty, cleanup the nested object
*/
- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    var oldID = [change objectForKey:CPKeyValueChangeOldKey],
        newID = [change objectForKey:CPKeyValueChangeNewKey];

    if (oldID == newID)
        return;

    CPLog.debug("NURESTNestedObject: keypath %@ of parent object %@ changed from %@ to %@", _nestedObjectIDKeyPath, _parentObject, oldID, newID);

    if (newID && [newID length])
    {
        CPLog.debug("NURESTNestedObject: new ID is %@. Fetching the nested object");
        [self _fetchNestedObject];
    }
    else
    {
        CPLog.debug("NURESTNestedObject: new ID is empty. Cleaning the nested object");
        [self setNestedObject:nil];
    }
}


#pragma mark -
#pragma mark NestedObject fetching

/*! @ignore
    Creates a new instance of _nestedObjectClass, sets the ID to parentObject valueForKeyPath:_nestedObjectIDKeyPath
    and fetch it
*/
- (void)_fetchNestedObject
{
    var newNestedObject = [[_nestedObjectClass alloc] init];

    [newNestedObject setID:[_parentObject valueForKeyPath:_nestedObjectIDKeyPath]];
    [newNestedObject fetchAndCallSelector:@selector(_didFetchNestedObject:connection:) ofObject:self];
}

/*! @ignore
    Update the newly fetched nested object
*/
- (void)_didFetchNestedObject:(NURESTObject)anObject connection:(NURESTConnection)aConnection
{
    console.error(aConnection);
    [self setNestedObject:anObject];
}

@end
