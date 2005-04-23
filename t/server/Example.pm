package Example;

use warnings;
use strict;
use CAM::SOAPApp;

our @ISA = qw(SOAP::Server::Parameters);

sub getEmployeeData {
   my $pkg = shift;
   my $app = CAM::SOAPApp->new(soapdata => \@_);
   my %data = $app->getSOAPData();
   unless ($data{ssn} && $data{ssn} eq "111-11-1111") {
      $app->error("BadSSN", "Don't know that employee");
   }
   return $app->response(name => "John Smith",
                         birthdate => "1969-01-01",
                         phone => "212-555-1212");
}

1;
