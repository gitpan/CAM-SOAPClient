#!/usr/bin/perl -w

use strict;
use FindBin qw($Bin);
use lib ("$Bin/lib");
use English qw(-no_match_vars);
BEGIN
{
   eval {
      require CAM::SOAPApp;
      CAM::SOAPApp->import();
   };
   if ($EVAL_ERROR)
   {
      die 'Could not find optional module CAM::SOAPApp needed for the advanced tests';
   }
}
use Example;
use SOAP::Transport::HTTP;

SOAP::Transport::HTTP::CGI
       -> dispatch_to('Example')
       -> handle;
