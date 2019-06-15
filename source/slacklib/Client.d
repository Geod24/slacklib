/*******************************************************************************

    Base client used by other slack implementation

    This client contains all the basic functions, like connecting,
    sending messages, getting informations about users / channels...

    In order to use it, users have to implement the abstract `handler` method
    which receives all events received from Slack.

    Author:         Mathias 'Geod24' Lang
    License:        MIT (See LICENSE.txt)
    Copyright:      Copyright (c) 2016-2017 Mathias Lang. All rights reserved.

*******************************************************************************/

module slacklib.Client;

import vibe.core.log;
import vibe.data.json;
import vibe.http.client;
import vibe.http.websockets;
import vibe.textfilter.urlencode;

import slacklib.Utils;

/// Ditto
public abstract class SlackClient
{
    /***************************************************************************

        Base constructor to call from derived class

        Params:
            token = Authentication token to use
            socket = Websocket connected to the rtm API
            infos = Json object returned by `rtm.connect`

    ***************************************************************************/

    protected this (istring token, WebSocket socket, Json infos)
    in
    {
        assert(token.length, "No token provided");
        assert(socket !is null, "No websocket instance provided");
        assert(infos["ok"].to!bool == true, "Slack answer was not positive");
    }
    do
    {
        this.token = token;
        this.socket = socket;
        this.infos = infos;
    }

    /***************************************************************************

        Event loop function

        Wait for data, receive text, and process it.
        The wait is non-blocking (it will yield if there's no data).

    ***************************************************************************/

    public void runEventLoop ()
    {
        while (this.socket.waitForData())
        {
            auto message = this.socket.receiveText.parseJsonString;
            this.handleEvent(message);
        }
    }

    /// Implement this method to define your business logic
    protected abstract void handleEvent (Json message) nothrow;

    /***************************************************************************

        Send a text message to a Slack channel

        Params:
            channel = Channel ID to send the message to
            message = Text message to send

    ***************************************************************************/

    public void sendMessage (cstring channel, cstring message)
    {
        this.web(
            `chat.postMessage`,
            `&as_user=true&channel=`, channel,
            `&text=`, urlEncode(message))
            .request();
    }

    /***************************************************************************

        Send a ping to Slack

        This shouldn't be needed, as there's a builtin ping in WebSocket which
        is used by default. If for some reason it doesn't work, you can
        schedule a periodic ping with:
        ---
        import core.time;
        vibe.core.core.setTimer(5.seconds, &this.sendPing, true);
        ---

    ***************************************************************************/

    public void sendPing ()
    {
        auto ping_json = Json(["type": Json("ping"), "id": Json(request_id++)]);
        this.socket.send(ping_json.toString);
    }


    /// Returns: This bot's name in slack format
    public istring id () @property
    {
        return this.infos["self"]["id"].to!string;
    }

    /***************************************************************************

        Perform a request to the web API

        This methods uses a buffer to reduce the amount of GC-allocation,
        as a result it is *not* re-entrant (shouldn't be transitively
        called through requested and responder).

        Note that in order to have a palatable API, it was split in two method,
        `web` and `request`, which is to be called like this:
        ---
        this.web("method", "arg1", "arg2).request(requester, responder);
        Client.webr("method", token, "args").request(requester, responder);
        ---

        Params:
            method = Method to request
            token = For the static version only, authentication token to use.
                    The non-static version uses the stored stoken.
            args = Variadic list of argument to append to the URL
                   Arguments are appended verbatim and any pre-processing
                   (e.g. URL encoding for messages text) should be done
                   beforehand.
            request = Optional request delegate. When not provided (or `null`
                      is provided), will send a `POST` request.
            responder = Optional response delegate. WHen not provided (or `null`
                        is provided), will do nothing.

    ***************************************************************************/

    protected auto web (cstring method, cstring[] args...)
    {
        return SlackClient.webr(method, this.token, args);
    }

    /// Ditto
    public static auto webr (cstring method, cstring token, cstring[] args...)
    {
        static mstring url_buffer;
        url_buffer.length = 0;
        url_buffer.assumeSafeAppend;

        url_buffer ~= `https://slack.com/api/`;
        url_buffer ~= method;
        url_buffer ~= `?token=`;
        url_buffer ~= token;
        foreach (value; args)
            url_buffer ~= value;

        static struct WebReq
        {
            cstring buffer_slice;
            public void request (
                scope void delegate(scope HTTPClientRequest) requester = null,
                scope void delegate(scope HTTPClientResponse) responder = null)
            {
                // cast required because requestHTTP expose a bad interface
                istring url = cast(istring) url_buffer;
                scope typeof(requester) def_requester
                    = (scope req) { req.method = HTTPMethod.POST; };
                scope typeof(responder) def_responder
                    = (scope res) {
                        if (res.statusCode != 200)
                            logError("Error for request: [%s]: %s",
                                     this.buffer_slice, res.statusPhrase);
                        else
                            logDebugV("Request succeeded: [%s]", this.buffer_slice);
                    };
                requestHTTP(
                    url,
                    requester !is null ? requester : def_requester,
                    responder !is null ? responder : def_responder);
            }
        }
        return WebReq(url_buffer);
    }

    /// Websocket used for two-ways communication
    protected WebSocket socket;
    /// Token used for authentication, represent the bot user
    protected istring token;
    /// Request id to send to the Slack API
    protected ulong request_id;
    /// Json object, result of `rtm.connect` or `rtm.start`
    protected Json infos;
}
