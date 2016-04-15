# XMMS2 scrobbler for last.fm

Since the existing scrobbler for last.fm does not work with the new
API, I decided to write my own.

## Environment

The scrobbler is developed and tested on Debian GNU/Linux testing with
xmms2 from Debian repository.

These are the dependencies needed for the scrobbler:

- libperl5.22
- libwww-perl
- libaudio-xmmsclient-perl

## How to run it

1. Allow the scrobbler to use your Last.fm account
2. Install scrobbler
3. Start xmms2 and play something

### Step 1 - Authenticate

Run `./authenticate.pl` to authenticate to Last.fm.

If you run the script for the first time, it will ask you to go to a
Last.fm URL that will allow the scrobbler to use your Last.fm account.

It saves some information in `~/.cache/xmms2/lastfmplugin.token`
and `~/.cache/xmms2/lastfmplugin.session`.

If for any reason you need to reauthenticate, just remove those 2
files from the filesystem.

### Step 2 - Install scrobbler

This step assumes you have already run xmms2 before, so the directory
`~/.config/xmms2/startup.d` exists.

Go to the `startup.d` directory and create a symlink to the actual
script, wherever you decide to install it on your machine.

The following snippet assumes the script is installed in `~/bin`.

```
$ cd ~/.config/xmms2/startup.d
$ ln -s ~/bin/scrobbler.pl
```

Also, modify the `scrobbler.pl` so that the `-I` parameter contains the
path where the `LastfmXmms2Scrobbler.pm` is located on your
filesystem, e.g.:

```
#!/usr/bin/perl -w -I/home/user/bin
```

### Step 3 - Play music

Start playing music via `xmms2`.

When `xmms2d` is started, the scrobbler script should be running as
well.  You can check it using `ps`:

```
$ ps -ef | grep scrobbler.pl
```

Also you should see the following line in the log file:

```
$ tail ~/.cache/xmms2/lastfmplugin.log
INFO  2016-04-05 17:07:32 main: Scrobbler starts
```

If it's not running, you can check `xmms2d` log for possible causes,
such as:

```
$ tail ~/.cache/xmms2/xmms2d.log
--- Starting new xmms2d ---
 INFO: ../src/xmms/log.c:49: Initialized logging system :)
17:03:32  INFO: ../src/xmms/ipc.c:817: IPC listening on 'unix:///tmp/xmms-ipc-someusername'.
17:03:32 ERROR: ../src/xmms/plugin.c:375: Failed to open plugin /usr/lib/xmms2/libxmms_equalizer.so: /usr/lib/xmms2/libxmms_equalizer.so: undefined symbol: iir
17:03:32  INFO: ../src/xmms/main.c:561: Using output plugin: pulse
Can't locate LastfmXmms2Scrobbler.pm in @INC (you may need to install the LastfmXmms2Scrobbler module) (@INC contains: /home/someusername/opt/src/xmms2-pluginx /home/someusername/opt/src/xmms2-pluginx /etc/perl /usr/local/lib/x86_64-linux-gnu/perl/5.22.1 /usr/local/share/perl/5.22.1 /usr/lib/x86_64-linux-gnu/perl5/5.22 /usr/share/perl5 /usr/lib/x86_64-linux-gnu/perl/5.22 /usr/share/perl/5.22 /usr/local/lib/site_perl /usr/lib/x86_64-linux-gnu/perl-base .) at /home/someusername/.config/xmms2/startup.d/scrobbler.pl line 7.
BEGIN failed--compilation aborted at /home/someusername/.config/xmms2/startup.d/scrobbler.pl line 7.
```

## Issues

- None known at the moment.

## Last.fm API

- authentication: http://www.last.fm/api/desktopauth
- scrobbling: http://www.last.fm/api/scrobbling

The scrobbler calls [track.updateNowPlaying](http://www.last.fm/api/show/track.updateNowPlaying) and [track.scrobble](http://www.last.fm/api/show/track.scrobble).
