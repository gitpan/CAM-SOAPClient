#!/usr/bin/perl -w

use strict;
use lib ($0 =~ m,(.*)/, ? $1 : ".");
use CAM::SOAPApp;
use Example;
use SOAP::Transport::HTTP;

my $PORT = shift || 9674;
my $TIMEOUT = 600; # seconds

# This server will auto-terminate after TIMEOUT seconds
$SIG{ALRM} = sub{exit(0)};
alarm($TIMEOUT);

SOAP::Transport::HTTP::Daemon
       -> new(LocalAddr => 'localhost', LocalPort => $PORT)
       -> dispatch_to('Example')
       -> handle;
