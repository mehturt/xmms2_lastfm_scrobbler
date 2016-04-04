#!/usr/bin/perl -w
#
# XMMS2 Last.fm scrobbler
# http://www.last.fm/api/scrobbling
#

use LastfmXmms2Scrobbler qw(debug);
use Digest::MD5 qw(md5_hex);
use Env qw(HOME);
use Audio::XMMSClient;
#use Data::Dumper;

my $browser = LWP::UserAgent->new;
my %lastplayed = ( 'artist' => '', 'title' => '', 'album' => '', 'duration' => 0, 'started' => 0);

sub updateNowPlaying
{
	my $method = "track.updateNowPlaying";
	my ($artist, $track, $album, $optional_retry) = @_;

	debug($method, "enter");

	my $api_sig = "";
	$api_sig .= "album" . $album;
	$api_sig .= "api_key" . LastfmXmms2Scrobbler::API_KEY;
	$api_sig .= "artist" . $artist;
	$api_sig .= "method" . $method;
	$api_sig .= "sk" . $LastfmXmms2Scrobbler::sessionkey;
	$api_sig .= "track" . $track;
	$api_sig .= LastfmXmms2Scrobbler::SECRET;
	$api_sig = md5_hex($api_sig);

	my $response = $browser->post(LastfmXmms2Scrobbler::URL,
		[
		'album' => $album,
		'api_key' => LastfmXmms2Scrobbler::API_KEY,
		'artist' => $artist,
		'api_sig' => $api_sig,
		'method' => $method,
		'sk' => $LastfmXmms2Scrobbler::sessionkey,
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
	$api_sig .= "api_key" . LastfmXmms2Scrobbler::API_KEY;
	$api_sig .= "artist" . $artist;
	$api_sig .= "method" . $method;
	$api_sig .= "sk" . $LastfmXmms2Scrobbler::sessionkey;
	$api_sig .= "timestamp" . $timestamp;
	$api_sig .= "track" . $track;
	$api_sig .= LastfmXmms2Scrobbler::SECRET;
	$api_sig = md5_hex($api_sig);

	my $response = $browser->post(LastfmXmms2Scrobbler::URL,
		[
		'album' => $album,
		'api_key' => LastfmXmms2Scrobbler::API_KEY,
		'artist' => $artist,
		'api_sig' => $api_sig,
		'method' => $method,
		'sk' => $LastfmXmms2Scrobbler::sessionkey,
		'timestamp' => $timestamp,
		'track' => $track
		],
	);

	debug($method, "Response: " . $response->content);
	die "Error: " . $response->status_line unless $response->is_success;
}

# Scrobble if Last.fm conditions are met
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

sub xmms2_disconnect_cb {
	my ($xc) = @_;
	print "Xmms2 exited, exiting as well.\n";
	$xc->quit_loop;
}

$LastfmXmms2Scrobbler::debug=1;
debug("main", "Scrobbler starts");

LastfmXmms2Scrobbler::signIn();

# Connect to XMMS2 daemon and establish callbacks
#
my $xmms = Audio::XMMSClient->new('lastfm_scrobbler');
if (!$xmms->connect) {
	die "Connection failed: " . $xmms->get_last_error;
}

$xmms->disconnect_callback_set( sub { xmms2_disconnect_cb ($xmms) } );
$xmms->request( broadcast_playback_current_id => sub { xmms2_current_id (@_, $xmms) } );
$xmms->request( broadcast_playback_status => sub { xmms2_playback_status (@_, $xmms) } );

$xmms->loop;
