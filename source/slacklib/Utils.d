/*******************************************************************************

    Collection of useful definitions which are used everywhere

    Author:         Mathias 'Geod24' Lang
    License:        MIT (See LICENSE.txt)
    Copyright:      Copyright (c) 2016-2017 Mathias Lang. All rights reserved.

*******************************************************************************/

module slacklib.Utils;

/// A mutable string, most likely used as a buffer
public alias mstring = char[];
/// A constant view into a string, can be mutable or not. Most common type.
public alias cstring = const(char)[];
/// The old immutable string alias, should be very uncommon
public alias istring = string;
