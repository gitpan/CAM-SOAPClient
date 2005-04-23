#!/usr/bin/perl -w

use strict;
use lib qw(.);
use CAM::SOAPApp;
use Example;
use SOAP::Transport::HTTP;

SOAP::Transport::HTTP::CGI
       -> dispatch_to('Example')
       -> handle;
