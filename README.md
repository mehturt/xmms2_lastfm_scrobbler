# XMMS2 scrobbler for last.fm

Since the existing scrobbler for last.fm does not work with the new
API, I decided to write my own.

## last.fm API

- last.fm authentication: http://www.last.fm/api/desktopauth
- last.fm scrobbling: http://www.last.fm/api/scrobbling

The scrobbler calls [track.updateNowPlaying](http://www.last.fm/api/show/track.updateNowPlaying) and [track.scrobble](http://www.last.fm/api/show/track.scrobble).

## Environment

The scrobbler is developed and tested on Debian GNU/Linux testing with
xmms2 from Debian repository.
I run it as a standalone script once I start xmms2.

## Issues

- It could be integrated with xmms2 to startup automatically after xmms2
is started.  The only issue is the last.fm authentication the first
time user runs the scrobbler, which must be done via a web browser.  I
tried to launch "links" from the script, but it did not work for me.  *Possibly separate authentication from the scrobbler.*
- Script goes to an infinite loop once `xmms2 quit` is executed.
- Script does not work without `API_KEY` and `SECRET`. Not sure if I can share those.  Most likely I can because it's also present in the [rhythmbox scrobbler](https://git.gnome.org/browse/rhythmbox/tree/plugins/audioscrobbler/rb-audioscrobbler-service.c)


