# Conexus 🔗
~ A simple Discord bot to link private test channels to voice channels.

## Uses
- Provides a place for messages only pertaining to the people in a voice-channel (so you don't clutter #general or some place and confuse people)
- Allows people in voice-channels who cannot use voice to talk to the other people in a voice-channel without cluttering another text-channel
- Tracks people entering/leaving voice-channels

This bot creates a hidden text-channel named `voice-channel` for every non-AFK voice channel on a server. Only users in a voice-channel can view and message in a hidden text-channel. 

## Add to Server
[https://discordapp.com/oauth2/authorize?&client_id=304009832489287691&scope=bot+&permissions=8](https://discordapp.com/oauth2/authorize?&client_id=304009832489287691&scope=bot+&permissions=8)

or

## Run Yourself (Recommended)
To run the program yourself, just clone it and run the following:
```sh
$ git clone git@github.com:Apexal/conexus.git && cd conexus
$ bundle
$ ruby run.rb <token> <client-id>
```
