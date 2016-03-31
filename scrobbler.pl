#!/usr/bin/perl -w
#
# XMMS2 last.fm scrobbler
# http://www.last.fm/api/desktopauth
#

use LWP;
use Digest::MD5 qw(md5_hex);
use Env qw(HOME);
use Audio::XMMSClient;
use Data::Dumper;
use POSIX qw(strftime);
use strict;

use constant URL => 'http://ws.audioscrobbler.com/2.0/';
use constant DIR => "$HOME/.cache/xmms2";
use constant TOKENFILENAME => DIR . "/lastfmplugin.token";
use constant SESSIONFILENAME => DIR . "/lastfmplugin.session";
use constant LOGFILENAME => DIR . "/lastfmplugin.log";
use constant API_KEY => "";
use constant SECRET => "";

my $browser = LWP::UserAgent->new;
my %lastplayed = ( 'artist' => '', 'title' => '', 'album' => '', 'duration' => 0, 'started' => 0);
my $token = "";
my $sessionkey = "";
my $debugfh;

system("mkdir -p " . DIR) == 0 or die "Cannot create dir";

sub debug
{
	if (1) {
		my ($method, $text) = @_;

		my $line = "-> " . strftime("%F %T", localtime) . " $method: $text\n";

		if (!defined $debugfh) {
			open($debugfh, ">>", LOGFILENAME) or die "Cannot open file " . LOGFILENAME . " for writing: $!";
			select( (select($debugfh), $| = 1)[0] );
		}

		print $debugfh $line;
		print $line;
	}
}

sub writeToFile
{
	my ($name, $filename, $sessionkey) = @_;

	debug($name, $sessionkey);

	open (my $fh, ">$filename") or die "Cannot open file $filename for writing: $!";
	print $fh $sessionkey;
	close $fh;
}

sub writeTokenToFile
{
	writeToFile("writeTokenToFile", TOKENFILENAME, $_[0]);
}

sub writeSessionToFile
{
	writeToFile("writeSessionToFile", SESSIONFILENAME, $_[0]);
}

sub getFromFile
{
	my ($name, $filename) = @_;
	my $fh;
	unless(open ($fh, "<$filename")) {
		debug($name, "");
		return "";
	}
	my $token = <$fh>;
	close $fh;
	debug($name, $token);
	return $token;
}

sub getTokenFromFile
{
	return getFromFile("getTokenFromFile", TOKENFILENAME);
}

sub getSessionFromFile
{
	return getFromFile("getSessionFromFile", SESSIONFILENAME);
}

sub getToken
{
	my $method = "auth.getToken";

	debug($method, "enter");

	my $api_sig = "";
	$api_sig .= "api_key" . API_KEY;
	$api_sig .= "method" . $method;
	$api_sig .= SECRET;
	$api_sig = md5_hex($api_sig);

	my $response = $browser->post(URL,
		[
		'api_key' => API_KEY,
		'api_sig' => $api_sig,
		'method' => $method
		],
	);

	debug($method, "Response: " . $response->content);
	die "Error: " . $response->status_line unless $response->is_success;

	$response->content =~ /<token>(.*)<\/token>/;
	debug($method, $1);
	return $1;
}

sub requestAuthorization
{
	print "Open a web browser and visit this URL: http://www.last.fm/api/auth/?api_key=" . API_KEY . "&token=$token\n";
	print "Press Enter to continue\n";
	<STDIN>;
}

# The successful answer is:
#   <session>
#       <name>somename</name>
#       <key>6e6daca04fe050089179a8c543577ab3</key>
#       <subscriber>0</subscriber>
#   </session>
#
# Error:
#   <error code="4">Invalid authentication token supplied</error>
#
sub getSession
{
	my $method = "auth.getSession";

	debug($method, "enter");

	my $api_sig = "";
	$api_sig .= "api_key" . API_KEY;
	$api_sig .= "method" . $method;
	$api_sig .= "token" . $token;
	$api_sig .= SECRET;
	$api_sig = md5_hex($api_sig);

	my $response = $browser->post(URL,
		[
		'token' => $token,
		'api_key' => API_KEY,
		'api_sig' => $api_sig,
		'method' => $method
		],
	);

	debug($method, "Response: " . $response->content);
	if ($response->content =~ /<error code="(\d+)"/) {
		my $error_code = $1;
		return "$error_code";
	}

	die "Error: " . $response->status_line unless $response->is_success;

	$response->content =~ /<key>(.*)<\/key>/;
	debug($method, $1);
	return $1;
}

sub updateNowPlaying
{
	my $method = "track.updateNowPlaying";
	my ($artist, $track, $album, $optional_retry) = @_;

	debug($method, "enter");

	my $api_sig = "";
	$api_sig .= "album" . $album;
	$api_sig .= "api_key" . API_KEY;
	$api_sig .= "artist" . $artist;
	$api_sig .= "method" . $method;
	$api_sig .= "sk" . $sessionkey;
	$api_sig .= "track" . $track;
	$api_sig .= SECRET;
	$api_sig = md5_hex($api_sig);

	my $response = $browser->post(URL,
		[
		'album' => $album,
		'api_key' => API_KEY,
		'artist' => $artist,
		'api_sig' => $api_sig,
		'method' => $method,
		'sk' => $sessionkey,
		'track' => $track
		],
	);

	debug($method, "Response: " . $response->content);
	if ($response->content =~ /<error code="(\d+)"/) {
		my $error_code = $1;

		# error codes:
		# 9: Invalid session key - Please re-authenticate
		#
		if ($error_code eq "9" && !defined $optional_retry) {
			reauthorize();
			updateNowPlaying($artist, $track, $album, 'RETRY');
			return;
		}
	}

	die "Error: " . $response->status_line unless $response->is_success;
}

sub scrobble
{
	my $method = "track.scrobble";
	my ($artist, $track, $album) = @_;

	debug($method, "enter");

	# Compute timestamp
	#
	my $timestamp = time() - 600;

	my $api_sig = "";
	$api_sig .= "album" . $album;
	$api_sig .= "api_key" . API_KEY;
	$api_sig .= "artist" . $artist;
	$api_sig .= "method" . $method;
	$api_sig .= "sk" . $sessionkey;
	$api_sig .= "timestamp" . $timestamp;
	$api_sig .= "track" . $track;
	$api_sig .= SECRET;
	$api_sig = md5_hex($api_sig);

	my $response = $browser->post(URL,
		[
		'album' => $album,
		'api_key' => API_KEY,
		'artist' => $artist,
		'api_sig' => $api_sig,
		'method' => $method,
		'sk' => $sessionkey,
		'timestamp' => $timestamp,
		'track' => $track
		],
	);

	debug($method, "Response: " . $response->content);
	die "Error: " . $response->status_line unless $response->is_success;
}

# Sign in via last.fm API
#
sub signIn
{
	$token = getTokenFromFile();
	if ($token eq "") {
		$token = getToken();
		writeTokenToFile($token);
	}

	$sessionkey = getSessionFromFile();
	if ($sessionkey eq "") {
		$sessionkey = getSession();

		if ($sessionkey eq "4" ||
			$sessionkey eq "14") {

			# 4: Invalid authentication token
			# 14: Unauthorized Token - This token has not been authorized
			#
			reauthorize();
		}
		 else {
			writeSessionToFile($sessionkey);
		}
	}
}

sub reauthorize
{
	debug("reauthorize", "enter");

	$token = getToken();
	writeTokenToFile($token);

	requestAuthorization();

	$sessionkey = getSession();
	writeSessionToFile($sessionkey);
}

# Scrobble if last.fm conditions are met
# http://www.last.fm/api/scrobbling
#
sub scrobbleIfNeeded
{
	my $now = time();

	debug("scrobbleIfNeeded", "lastduration " . $lastplayed{duration} . " now $now laststarted " . $lastplayed{started});

	# Scrobble if:
	# - total length is greater than 30s
	# - track has been playing for half its duration (or 4 minutes)
	#
	if ($lastplayed{artist} ne "" &&
		$lastplayed{title} ne "" &&
		$lastplayed{album} ne "" &&
		$lastplayed{duration} > 30 &&
		($now - $lastplayed{started} > ($lastplayed{duration} / 2) || $now - $lastplayed{started} > 240)
		) {

		# Scrobble $lastplayed
		scrobble($lastplayed{artist}, $lastplayed{title}, $lastplayed{album});
	}
}

# Callback upon track change
#
sub xmms2_current_id
{
	my ($id, $xc) = @_;

	debug("xmms2_current_id", "id $id");

	my $result = $xc->medialib_get_info($id);
	$result->wait;

	if ($result->iserror) {
		# This can return error if the id is not in the medialib
		#
		die "medialib get info returns error, " . $result->get_error;
	}

	my $minfo = $result->value;

	# print Dumper($minfo);

	my $artist = $minfo->{artist}->{'plugin/id3v2'};
	my $title = $minfo->{title}->{'plugin/id3v2'};
	my $duration = $minfo->{duration}->{'plugin/mad'} / 1000;
	my $album = $minfo->{album}->{'plugin/id3v2'};

	debug("xmms2_current_id", "artist: $artist title: $title album: $album duration: $duration s");

	signIn();

	my $now = time();

	updateNowPlaying($artist, $title, $album);

	if ($title ne $lastplayed{title}) {
		scrobbleIfNeeded();
	}

	%lastplayed = (
		'artist' => $artist,
		'title' => $title,
		'album' => $album,
		'duration' => $duration,
		'started' => $now);

	return 1;
}

# Callback upon start/stop/pause
#
sub xmms2_playback_status {
	my ($value, $xc) = @_;

	debug("xmms2_playback_status", "value: $value");

	# Values:
	# 1 - start
	# 0 - stop
	# 2 - pause
	#
	if ($value eq "0") {
		if ($lastplayed{artist} ne "" &&
			$lastplayed{title} ne "" &&
			$lastplayed{album} ne "") {
			scrobbleIfNeeded();
		}

		$lastplayed{artist} = "";
		$lastplayed{title} = "";
		$lastplayed{album} = "";
	}

	return 1;
}

debug("main", "Scrobbler starts");

# Connect to XMMS2 daemon and establish callbacks
#
my $xmms = Audio::XMMSClient->new('lastfm_scrobbler');
if (!$xmms->connect) {
	die "Connection failed: " . $xmms->get_last_error;
}

$xmms->request( broadcast_playback_current_id => sub { xmms2_current_id (@_, $xmms) } );
$xmms->request( broadcast_playback_status => sub { xmms2_playback_status (@_, $xmms) } );

$xmms->loop;
