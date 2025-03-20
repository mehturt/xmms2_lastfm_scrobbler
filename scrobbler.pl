#!/usr/bin/perl -w -I.
#
# XMMS2 Last.fm scrobbler
# https://github.com/mehturt/xmms2_lastfm_scrobbler
#

use LastfmXmms2Scrobbler qw(debug info warn error);
use Digest::MD5 qw(md5_hex);
use Env qw(HOME);
use Audio::XMMSClient;
#use Data::Dumper;

my $browser = LWP::UserAgent->new;
my %lastplayed = ( 'artist' => '', 'title' => '', 'album' => '', 'duration' => 0, 'started' => 0);

# Optional notify script for track change
use constant NOTIFYSCRIPT => "$HOME/bin/xmms2_track_change2.sh";

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

	if ($response->is_success) {
		info($method, "Now playing $artist - $track");
	}
	else {
		error($method, "Error: " . $response->status_line);
	}
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

	if ($response->is_success) {
		info($method, "Scrobbled $artist - $track");
	}
	else {
		error($method, "Error: " . $response->status_line);
	}
}

# Scrobble if Last.fm conditions are met
#
sub scrobbleIfNeeded
{
	my $now = time();
	my $method = "scrobbleIfNeeded";

	debug($method, "lastduration " . $lastplayed{duration} . " now $now laststarted " . $lastplayed{started});

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
	my $method = "xmms2_current_id";

	debug($method, "id $id");

	$xc->request( "medialib_get_info", $id, sub { xmms2_mlib_info(@_, $xc) } );
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
	info("main", "Xmms2 exited, exiting as well.");
	$xc->quit_loop;
}

# Callback for medialib_get_info
#
sub xmms2_mlib_info
{
	my ($minfo, $xc) = @_;
	my $method = "xmms2_mlib_info";

	# debug($method, "minfo " . Dumper($minfo));
	# print Dumper($minfo);

	unless (exists $minfo->{artist} && exists $minfo->{title} && exists $minfo->{duration} && exists $minfo->{album}) {
		warn($method, "Required mlib data not present, skipping this file.");
		return 1;
	}

	my (undef, $artist) = each(%{$minfo->{artist}});

	# Find ID3v2 title, or longest title available.
	#
	#my (undef, $title) = each(%{$minfo->{title}});
	my $title = "";
	my $titleref = $minfo->{title};
	foreach my $key (keys %{$titleref}) {
		my $value = ${$titleref}{$key};
		debug($method, "key: $key value: $value");
		if ($key eq "plugin/id3v2") {
			$title = $value;
			last;
		}
		if (length($value) > length($title)) {
			$title = $value;
		}
	}

	my (undef, $duration) = each(%{$minfo->{duration}});
	$duration /= 1000;
	my (undef, $album) = each(%{$minfo->{album}});

	info($method, "artist: $artist title: $title album: $album duration: $duration s");

	# Optional notify script for track change
	#
	if (-x NOTIFYSCRIPT) {
		my $notify = NOTIFYSCRIPT . " \"$artist\" \"$title\"";
		debug($method, "Calling notify script: $notify");
		system($notify);
	}

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

$LastfmXmms2Scrobbler::debug=1;
info("main", "Scrobbler starts");

LastfmXmms2Scrobbler::signIn();

# Connect to XMMS2 daemon and establish callbacks
#
my $xmms = Audio::XMMSClient->new('lastfm_scrobbler');
if (!$xmms->connect) {
	error("main", "Connection failed: " . $xmms->get_last_error);
	die;
}

$xmms->disconnect_callback_set( sub { xmms2_disconnect_cb ($xmms) } );
$xmms->request( broadcast_playback_current_id => sub { xmms2_current_id (@_, $xmms) } );
$xmms->request( broadcast_playback_status => sub { xmms2_playback_status (@_, $xmms) } );

$xmms->loop;
