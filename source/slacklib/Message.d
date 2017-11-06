/*******************************************************************************

    Functions and types to deal with messages

    Author:         Mathias 'Geod24' Lang
    License:        MIT (See LICENSE.txt)
    Copyright:      Copyright (c) 2016-2017 Mathias Lang. All rights reserved.

*******************************************************************************/

module slacklib.Message;

import slacklib.Utils;

import std.algorithm.searching;
import std.range.primitives;

/*******************************************************************************

    Returns:
        A `ForwardRange` of all users mentioned in `text`

*******************************************************************************/

public auto mentions (cstring text) @safe pure
{
    static struct MentionRange
    {
        private enum UIDLength = 9;

        private cstring message, current;

        pure @safe:

        private this (cstring text)
        {
            this.message = text;
            this.popFront;
        }

        // countUntil is not `nogc` or `nothrow`
        public auto popFront ()
        {
            size_t nextidx = this.message.countUntil("<@U");
            if (nextidx == -1)
                this.message = this.current = null;
            else
            {
                assert(this.message.length >= nextidx + 3 + UIDLength);
                assert(this.message[nextidx + 2 + UIDLength] == '>', this.message);

                this.current = this.message[nextidx + 2 .. nextidx + 2 + UIDLength];
                this.message = this.message[nextidx + 3 + UIDLength .. $];

                assert(this.current[0] == 'U', this.current);
            }
        }

        public auto front ()
        {
            return this.current;
        }

        public auto empty ()
        {
            return !this.current.length && this.message.countUntil("<@U") == -1;
        }

        public auto save ()
        {
            return this;
        }
    }
    static assert (isForwardRange!MentionRange);
    return MentionRange(text);
}

///
unittest
{
    import std.algorithm.searching : any;
    import std.range : enumerate;

    size_t idx;
    static immutable istring[] results = [
        `U00000000`,
        `U00000001`, `U00000002`,
        `U00000003`, `U00000004`,
        `U00000005`,
    ];

    // Simple test
    assert(`Hello <@U00000000>! How's your day ?`.mentions
           .all!((v) => v == results[idx++]), results[idx - 1]);
    // Mention at the beginning (and 2 mentions)
    assert(`<@U00000001> et <@U00000002> sont sur un bateau...`.mentions
           .all!((v) => v == results[idx++]), results[idx - 1]);
    // Both at the beggining and at the end
    assert(`<@U00000003> please meet <@U00000004>`.mentions
           .all!((v) => v == results[idx++]), results[idx - 1]);
    // Single mention as a text
    assert(`<@U00000005>`.mentions.all!((v) => v == results[idx++]),
           results[idx - 1]);

    // Make sure we actually tested something
    assert(idx == results.length);

    // Real-world use case
    assert(`<@U0Z3M3388> is a stupid bot`.mentions.any!((v) => v == `U0Z3M3388`));
}
