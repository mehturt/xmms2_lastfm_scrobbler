# XMMS2 scrobbler for last.fm

Since the existing scrobbler for last.fm does not work with the new
API, I decided to write my own.

## Environment

The scrobbler is developed and tested on Debian GNU/Linux testing with
xmms2 from Debian repository.

## How to run it

1. Allow the scrobbler to use your Last.fm account
2. Start scrobbler
3. Start xmms2 and play something

### Step 1 - Authenticate

Run `./authenticate.pl` to authenticate to Last.fm.

If you run the script for the first time, it will ask you to go to a
Last.fm URL that will allow the scrobbler to use your Last.fm account.

It saves some information in `$HOME/.cache/xmms2/lastfmplugin.token`
and `$HOME/.cache/xmms2/lastfmplugin.session`.

If for any reason you need to reauthenticate, just remove those 2
files from the filesystem.

### Step 2 - Scrobbling

Once you are authenticated, you can start the scrobbler:
`./scrobbler.pl`

It will wait for xmms2 to play something and then update your "now
playing" and once conditions are met, scrobble the track played.

### Step 3 - Play music

Start playing music via `xmms2`.

## Issues

- Scripts do not work without `API_KEY` and `SECRET`. Not sure if I can share those.  Most likely I can because it's also present in the [rhythmbox scrobbler](https://git.gnome.org/browse/rhythmbox/tree/plugins/audioscrobbler/rb-audioscrobbler-service.c)
- Files with missing / invalid ID3 tags were not tested yet, I expect
  some issues there.

## Last.fm API

- authentication: http://www.last.fm/api/desktopauth
- scrobbling: http://www.last.fm/api/scrobbling

The scrobbler calls [track.updateNowPlaying](http://www.last.fm/api/show/track.updateNowPlaying) and [track.scrobble](http://www.last.fm/api/show/track.scrobble).
