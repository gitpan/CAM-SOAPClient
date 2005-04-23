#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN
{ 
   use Test::More tests => 3;
   use_ok("CAM::SOAPClient");
}

my $PORT = 9674;

SKIP:
{
   require IO::Socket;
   my $s = IO::Socket::INET->new(PeerAddr => "localhost:$PORT",
                                 Timeout  => 10);
   if (!$s)
   {
      skip("The test server is not running.  Run via:  './t/server/soap.pl $PORT &'\n" .
           "(the server runs for about ten minutes before turning itself off)\n" .
           "(Also note that the server require CAM::SOAPApp to be installed...)\n",
           # Hack: get the number of tests we expect, skip all but one
           # This hack relies on the soliton nature of Test::Builder
           Test::Builder->new()->expected_tests() -
           Test::Builder->new()->current_test());
   }

   close($s);

   my $uri   = "http://localhost/Example";
   my $proxy = "http://localhost:$PORT/soaptest/soap.cgi";
   my $ssn = "111-11-1111";
   
   is_deeply([getPhoneNumber_SOAPLite($ssn, $uri, $proxy)], ["212-555-1212"], "SOAP::Lite");
   is_deeply([getPhoneNumber_CAM_SOAP($ssn, $uri, $proxy)], ["212-555-1212"], "CAM::SOAPClient");
}


sub getPhoneNumber_CAM_SOAP {
   my ($ssn, $uri, $proxy) = @_;
   return CAM::SOAPClient
       -> new($uri, $proxy)
       -> call("getEmployeeData", "phone", ssn => $ssn);
}

sub getPhoneNumber_SOAPLite {
   my ($ssn, $uri, $proxy) = @_;
   my $som = SOAP::Lite
       -> uri($uri)
       -> proxy($proxy)
       -> call("getEmployeeData", SOAP::Data->name(ssn => $ssn));
   if (ref $som) {
      return $som->valueof("/Envelope/Body/[1]/phone");
   } else {
      return undef;
   }
}
