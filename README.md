# Slacklib

Simple Vibe.d based library to write Slack bots

## Dependency

This library is not registered on `code.dlang.org`.
Instead, clone is as a submodule:
```console
mkdir submodules
git submodule add --name slacklib https://github.com/Geod24/slacklib.git submodules/slacklib
```

Add the following to your `dub.json`'s dependencies:
```json
"slacklib:lib": { "path": "submodules/slacklib" }
```

Or for `dub.sdl`:
```sdlang
dependency "slacklib:lib" path="submodules/slacklib"
```

You might also need to add the `VibeDefaultMain` `version` if you follow the example.

## Usage

See [the usage example](example/simple/app.d).
For the credentials to use, see [this article](https://get.slack.help/hc/en-us/articles/215770388-Create-and-regenerate-API-tokens).
