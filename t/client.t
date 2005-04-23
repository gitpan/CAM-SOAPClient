#!/usr/bin/perl -w

use warnings;
use strict;
use Carp;
$SIG{__WARN__} = $SIG{__DIE__} = \&Carp::confess;

BEGIN
{ 
   use Test::More tests => 20;
   use_ok("CAM::SOAPClient");
}

package FakeSOAP;

my $SOM;
sub call
{
   # Return a SOAP::SOM object
   return $SOM ||= SOAP::Deserializer->deserialize(<<'EOF');
<Envelope xmlns:ss="http://xml.apache.org/xml-soap"
          xmlns:xsi="http://www.w3.org/1999/XMLSchema-instance"
          xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
          xmlns:xsd="http://www.w3.org/1999/XMLSchema">
  <Body>
    <methodResponse>
      <userID xsi:type="xsd:string">12</userID>
      <data enc:arrayType="ss:SOAPStruct[]" xsi:type="enc:Array">
        <item xsi:type="ss:SOAPStruct"><id xsi:type="xsd:int">4</id></item>
        <item xsi:type="ss:SOAPStruct"><id xsi:type="xsd:int">6</id></item>
        <item xsi:type="ss:SOAPStruct"><id xsi:type="xsd:int">7</id></item>
        <item xsi:type="ss:SOAPStruct"><id xsi:type="xsd:int">10</id></item>
        <item xsi:type="ss:SOAPStruct"><id xsi:type="xsd:int">20</id></item>
      </data>
    </methodResponse>
  </Body>
</Envelope>
EOF
}
sub uri
{
   return shift;
}
sub proxy
{
   return shift;
}

package main;

my $response;
my $obj = CAM::SOAPClient->new("http://www.foo.com/No/Such/Class/", "foo");
ok($obj, "Constructor");

# HACK! ruin the SOAP object for the sake of the test
$obj->{soap} = bless({}, "FakeSOAP");

my $all = {data => [{id=>4},{id=>6},{id=>7},{id=>10},{id=>20}], userID => 12};
my @tests = (
             "undef" => $all, [$all],
             "'data/item/id'"   => 4, [4],
             "['data/item/id']" => 4, [4],
             "'\@data/item/id'"   => 4, [4,6,7,10,20],
             "['\@data/item/id']"   => 4, [4,6,7,10,20],
             "['data/item/id','userID']" => 4, [4,12],
             "['\@data/item/id','userID']" => [4,6,7,10,20], [[4,6,7,10,20],12],
             "['userID', '\@data/item/id',]" => 12, [12,[4,6,7,10,20]],
             );
while (@tests > 0)
{
   my $spaths = shift @tests;
   my $paths = eval $spaths;
   $response = $obj->call("null", $paths);
   is_deeply($response, shift @tests, "call scalar $spaths");
   $response = [$obj->call("null", $paths)];
   is_deeply($response, shift @tests, "call array  $spaths");

   #use Data::Dumper;
   #print Dumper($obj->getLastSOM());
}

$obj = CAM::SOAPClient->new(wsdl => "file:t/test.wsdl");
is($obj->{proxies}->{test}, "http://www.foo.com/test.cgi", "WSDL test - endpoint");
is($obj->{uris}->{test}, "http://foo.com/test", "WSDL test - uri");
