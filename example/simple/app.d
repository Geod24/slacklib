/*******************************************************************************

    Simple example of a Slack bot which just answers when mentioned

    Author:         Mathias 'Geod24' Lang
    License:        MIT (See LICENSE.txt)
    Copyright:      Copyright (c) 2016-2017 Mathias Lang. All rights reserved.

*******************************************************************************/

module simple.app;

import std.exception;

import vibe.core.args;
import vibe.core.core;
import vibe.core.log;
import vibe.data.json;
import vibe.http.client;
import vibe.http.websockets;
import vibe.stream.tls;

import slacklib.Client;
import slacklib.Message;
import slacklib.Utils;

/// Initialization (used by Vibe.d)
shared static this ()
{
    string auth_token;
    readOption("auth-token", &auth_token,
               "Token to use for authentication on the web API");
    runTask(() => startBot(auth_token));
}

/// Start the bot's event loop
private void startBot (string auth_token)
{
    HTTPClient.setTLSSetupCallback(&disablePerrValidation);
    logInfo("Starting up connection...");
    auto client = Client.start(auth_token);
    logInfo("WebSocket connected");
    client.runEventLoop(); // Should never return
    logFatal("Connection to Slack lost!");
}

void disablePerrValidation (TLSContext context) @safe
{
    context.peerValidationMode = TLSPeerValidationMode.none;
}

///
public class Client : SlackClient
{
    /***************************************************************************

        Given an authentication token, starts a new connection to Slack's
        real-time-messaging (RTM) API.

    ***************************************************************************/

    public static SlackClient start (string token)
    {
        enforce(token.length, "Empty token provided");
        Json infos;

        SlackClient.webr("rtm.connect", token).request(
            (scope HTTPClientRequest req) {},
            (scope HTTPClientResponse res) { infos = res.readJson; });

        scope (failure)
            logError("Error while connecting to Slack: %s", infos.to!string);
        enforce(infos["ok"].get!bool, "Slack didn't answer with 'ok=true'");

        logInfo("Response from slack: %s", infos.to!string);

        auto sock = connectWebSocket(URL(infos["url"].get!istring));
        auto hello_msg = sock.receiveText();
        enforce(hello_msg == `{"type":"hello"}`,
            "Expected 'hello' message, but got: " ~ hello_msg);
        return new Client(token, sock, infos);
    }

    /***************************************************************************

        Private ctor, called from `start`

    ***************************************************************************/

    private this (string token, WebSocket socket, Json infos)
    {
        super(token, socket, infos);
    }

    /// Implementation of the handler
    protected override void handleEvent (Json msg) nothrow
    {
        try handle(msg);
        catch (Exception e)
            logError("Error happened while handling '%s': %s", msg, e);
    }

    /// Just log received messages and pretty-print messages
    public void handle (Json json)
    {
        logInfo("Received: %s", json);
        auto type = enforce("type" in json, "No type in json");
        if (type.to!string == "pong")
            return;
        if (type.to!string == "message")
        {
            if (auto st = "subtype" in json) {
                logInfo("Ignoring message with subtype %s", st.to!string);
                return;
            }
            auto msg = enforce("text" in json, "No text for message").to!string;
            /// Usage of the 'mentions' helper
            if (msg.mentions.any!((v) => v == this.id))
            {
                logInfo("I was mentioned! Message: %s", msg);
                if (auto chan = "channel" in json)
                {
                    if (auto user = "user" in json)
                    {
                        this.sendMessage(
                            (*chan).to!string,
                            "Thanks for your kind words <@" ~ (*user).to!string ~ ">");
                    }
                    else
                        logFatal("Couldn't find user: %s", json.to!string);
                }
                else
                    logError("Couldn't find channel: %s", json.to!string);
            }
        }
    }
}
