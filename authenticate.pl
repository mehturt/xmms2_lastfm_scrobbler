#!/usr/bin/perl -w
#
# XMMS2 Last.fm scrobbler authentication
# http://www.last.fm/api/desktopauth
#

use LastfmXmms2Scrobbler;

LastfmXmms2Scrobbler::signIn();
print "You are now authenticated.\n";
