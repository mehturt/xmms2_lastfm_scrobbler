package LastfmXmms2Scrobbler;

use strict;
use warnings;
use Env qw(HOME);
use LWP;
use POSIX qw(strftime);
use Digest::MD5 qw(md5_hex);

use Exporter 'import';
our @EXPORT_OK = qw(debug info warn error);

use constant URL => 'http://ws.audioscrobbler.com/2.0/';
use constant DIR => "$HOME/.cache/xmms2";
use constant TOKENFILENAME => DIR . "/lastfmplugin.token";
use constant SESSIONFILENAME => DIR . "/lastfmplugin.session";
use constant LOGFILENAME => DIR . "/lastfmplugin.log";
# This API key belongs to mehturt <mehturt@gmail.com>
# generated 2016 for use in the XMMS2 Last.fm plugin
use constant API_KEY => "64525a1371eaedf15e24bb150fcabc29";
use constant SECRET => "41abfb889e363ea12ed70a36617cb83d";

our $sessionkey = "";
our $debug = 0;

my $token = "";
my $logfh;
my $browser = LWP::UserAgent->new;

INIT
{
	system("mkdir -p " . DIR) == 0 or die "Cannot create dir";
}

sub writelog
{
	my ($severity, $method, $text) = @_;

	my $line = "$severity " . strftime("%F %T", localtime) . " $method: $text\n";

	if (!defined $logfh) {
		open($logfh, ">>", LOGFILENAME) or die "Cannot open file " . LOGFILENAME . " for writing: $!";
		select( (select($logfh), $| = 1)[0] );
	}

	print $logfh $line;
}

sub warn
{
	my ($method, $text) = @_;
	writelog("WARN ", $method, $text);
}

sub error
{
	my ($method, $text) = @_;
	writelog("ERROR", $method, $text);
}

sub info
{
	my ($method, $text) = @_;
	writelog("INFO ", $method, $text);
}

sub debug
{
	if ($debug != 0) {
		my ($method, $text) = @_;
		writelog("DEBUG", $method, $text);
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
	my $message = <<"EOF";

Open a web browser and visit this URL: http://www.last.fm/api/auth/?api_key=${\API_KEY}&token=$token
You will have to log in to your Last.fm account, if not logged in already.

The web page will ask you to grant permission to 'xmms2 scrobbling plugin' to use your Last.fm account.
Click 'Yes, allow access'.

Press Enter here to continue once you've done that.
EOF

	print $message;
	<STDIN>;
}

# The successful answer is:
#   <session>
#       <name>somename</name>
#       <key>6e6daca04fe050089179a8c543577ab3</key>
#       <subscriber>0</subscriber>
#   </session>
#
# Error: answer will containt
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

sub reauthorize
{
	debug("reauthorize", "enter");

	$token = getToken();
	writeTokenToFile($token);

	requestAuthorization();

	$sessionkey = getSession();

	if ($sessionkey =~ /^\d+$/) {
		die "Cannot authorize, error code $sessionkey\nFor the summary of error codes, visit http://www.last.fm/api/show/auth.getSession";
	}

	writeSessionToFile($sessionkey);

	print "Congratulations, you have authorized the scrobbling plugin to use your Last.fm account.\n";
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

		if ($sessionkey =~ /^\d+$/) {

			# Example error codes:
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
