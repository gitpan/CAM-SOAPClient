package CAM::SOAPClient;

=head1 NAME

CAM::SOAPClient - SOAP interaction tools

=head1 LICENSE

Copyright 2005 Clotho Advanced Media, Inc., <cpan@clotho.com>

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SYNOPSIS

  use CAM::SOAPClient;
  my $client = CAM::SOAPClient->new(wsdl => "http://www.clotho.com/staff.wsdl");
  my ($fname, $lname) = $client->call("fetchEmployee", '[firstName,lastName]',
                                      ssn => '000-00-0000');
  my $record = $client->call("fetchEmployee", undef, ssn => '000-00-0000');
  my @addresses = $client->call("allEmployees", "@email");
  
  my $firstbudget = $client->call("listClientProjects", 
                                  '/client/projects/project/budget');
  
  if ($client->hadFault()) {
     die("SOAP Fault: " . $client->getLastFaultString() . "\n");
  }

=head1 DESCRIPTION

This library offers some basic tools to simplify the creation of SOAP
client implementations.  It is intended to be subclassed.

The purpose for this module is the complexity of SOAP::Lite.  That
module makes easy things really easy and hard things possible, but
really obscure.  The problem is that the easy things are often too
basic.  This module makes normal SOAP/WSDL activities easier by hiding
some of the weirdness of SOAP::Lite.

=cut

#--------------------------------#

require 5.005_62;
use strict;
use warnings;
use SOAP::Lite;

our $VERSION = '1.13';

#--------------------------------#

=head1 METHODS

=over 4

=cut

#--------------------------------#

=item new [opts] URI

=item new [opts] URI, PROXY

=item new [opts] URI, PROXY, USERNAME, PASSWORD

=item new [opts] wsdl => URL

=item new [opts] wsdl => URL, USERNAME, PASSWORD

Create a connection instance.  The proxy is not required here, but if
not specified it must be set later via setProxy().  Optionally, you
can use a WSDL URL instead of a URI and proxy.  The username and
password may not be needed at all for some applications.  There are
included here for convenience, since many applications do need them.

The options are as follows:

=over

=item timeout => seconds

This defaults to 6 hours.

=back

=cut

sub new
{
   my $pkg = shift;
   my %cfg = (
              timeout => 6*60*60, # 6 hours
              );
   while (@_ > 0)
   {
      if ($_[0] eq "timeout")
      {
         my $key = shift;
         my $val = shift;
         $cfg{$key} = $val;
      }
      else
      {
         last;
      }
   }

   my $uri = shift;
   my $proxy = shift;
   my $user = shift;
   my $pass = shift;

   my $soap = SOAP::Lite  -> on_fault( sub {} );
   my $self = bless({
      %cfg,
      services => {},
      soap => $soap,
      auth => {},
      global_proxy => undef,
      global_uri => undef,
      proxies => {},
      uris => {},
   }, $pkg);

   if ($uri && $uri eq "wsdl")
   {
      $self->setWSDL($proxy);
   }
   else
   {
      return undef if (!$uri);
      $self->setURI($uri);
      if ($proxy)
      {
         $self->setProxy($proxy);
      }
   }

   if ($user)
   {
      $self->setUserPass($user, $pass);
   }
   return $self;
}
#--------------------------------#

=item setWSDL URL

Loads a Web Service Description Language file describing the SOAP service.

=cut

sub setWSDL
{
   my $self = shift;
   my $url = shift;
   
   my $services = SOAP::Schema->schema($url)->parse()->services();
   #use Data::Dumper; print STDERR Dumper($services);

   foreach my $class (values %$services)
   {
      foreach my $method (keys %$class)
      {
         $self->{proxies}->{$method} = $class->{$method}->{endpoint}->value();
         $self->{uris}->{$method} = $class->{$method}->{uri}->value();
      }
   }

   return $self;
}
#--------------------------------#

=item setURI URI

Specifies the URI for the SOAP server.

=cut

sub setURI
{
   my $self = shift;
   my $uri = shift;

   $self->{global_uri} = $uri;
   return $self;
}
#--------------------------------#

=item setProxy PROXY

Specifies the URL for the SOAP server.

=cut

sub setProxy
{
   my $self = shift;
   my $proxy = shift;

   $self->{global_proxy} = $proxy;
   return $self;
}
#--------------------------------#

=item setUserPass USERNAME, PASSWORD

Specifies the username and password to use on the SOAP server.

=cut

sub setUserPass
{
   my $self = shift;
   my $username = shift;
   my $password = shift;

   $self->{auth}->{username} = $username;
   $self->{auth}->{password} = $password;
   return $self;
}
#--------------------------------#

=item getLastSOM

Returns the SOAP::SOM object for the last query.

=cut

sub getLastSOM
{
   my $self = shift;

   return $self->{last_som};
}
#--------------------------------#

=item hadFault

Returns a boolean indicating whether the last call() resulted in a fault.

=cut

sub hadFault
{
   my $self = shift;

   my $som = $self->getLastSOM();
   return $som && ref($som) && $som->fault();
}
#--------------------------------#

=item getLastFaultString

Returns the fault string from the last query, or C<(none)> if the last
query did not result in a fault.

=cut

sub getLastFaultString
{
   my $self = shift;

   my $som = $self->getLastSOM();
   if ($som && ref($som) && $som->can("faultstring") && $som->fault())
   {
      return $som->faultstring();
   }
   else
   {
      return "(none)";
   }
}
#--------------------------------#

=item call METHOD, undef, KEY => VALUE, KEY => VALUE, ...

=item call METHOD, XPATH, KEY => VALUE, KEY => VALUE, ...

=item call METHOD, XPATH_ARRAYREF, KEY => VALUE, KEY => VALUE, ...

Invoke the named SOAP method.  The return values are indicated in the
second argument, which can be undef, a single scalar or a list of
return fields.  If this path is undef, then all data are returned as
if the SOAP C<paramsout()> method was called.  Otherwise, the SOAP
response is searched for these values.  If any of them are missing,
call() returns undef.  If multiple values are specified, they are all
returned in array context, while just the first one is returned in
scalar context. This is best explained by examples:

    'documentID' 
           returns 
        /Envelope/Body/<method>/documentID

    ['documentID', 'data/[2]/type', '//result']
           returns
       (/Envelope/Body/<method>/documentID,
        /Envelope/Body/<method>/data/[2]/type,
        /Envelope/Body/<method>/*/result)
           or
        /Envelope/Body/<method>/documentID
           in scalar context

If the path matches multiple fields, just the first is returned.
Alternatively, if the path is prefixed by a C<@> character, it is
expected that the path will match multiple fields.  If there is just
one path, the matches are returned as an array (just the first one in
scalar context).  If there are multiple paths specified, then the
matches are returned as an array reference.  For example, imagine a
query that returns a list of documents with IDs 4,6,7,10,20 for user
#12.  Here we detail the return values for the following paths:

  path: 'documents/item/id' or ['documents/item/id']
      returns
   array context: (4)
  scalar context: 4
  
  path: '@documents/item/id' or ['@documents/item/id']
      returns
   array context: (4,6,7,10,20)
  scalar context: 4
  
  path: ['documents/item/id', 'userID']
      returns
   array context: (4, 12)
  scalar context: 4
  
  path: ['@documents/item/id', 'userID']
      returns
   array context: ([4,6,7,10,20], 12)
  scalar context: [4,6,7,10,20]
  
  path: ['userID', '@documents/item/id']
      returns
   array context: (12, [4,6,7,10,20])
  scalar context: 12

=cut

sub call
{
   my $self = shift;
   my $method = shift;
   my $paths = shift;
   my @args = @_;

   my @rets;

   if ($paths && !ref($paths))
   {
      $paths = [$paths];
   }

   my $uri = $self->{uris}->{$method} || $self->{global_uri};
   my $proxy = $self->{proxies}->{$method} || $self->{global_proxy};
   unless ($uri && $proxy)
   {
      return wantarray ? () : undef;
   }
   
   my $som = $self->{soap}
                  ->uri($uri)
                  ->proxy($proxy,
                          ($self->{timeout} ? 
                           (timeout => $self->{timeout}) : ())
                          )
                  ->call($method, $self->request($self->loginParams(), @args));
   $self->{last_som} = $som;

   if (!$som || !ref($som) || $som->fault)
   {
      return wantarray ? () : undef;
   }

   if (!defined $paths)
   {
      @rets = ($som->match('/Envelope/Body/[1]')->valueof());
   }
   else
   {
      foreach my $origpath (@$paths)
      {
         my $path = $origpath;
         my $isArray = ($path =~ s/^\@//);
         
         return undef if (!$som->match("/Envelope/Body/[1]/$path"));
         my @values = $som->valueof();
         if ($isArray)
         {
            if (@$paths == 1)
            {
               push @rets, @values;
            }
            else
            {
               push @rets, [@values];
            }
         }
         else
         {
            push @rets, $values[0];
         }
      }
   }
   return wantarray ? @rets : $rets[0];
}
#--------------------------------#

=item loginParams

This is intened to return a hash of all the required parameters shared
by all SOAP requests.  This version returns the contents of
C<%{$soap->{auth}}>.  Some subclasses may wish to override this, while
others may wish to simply add more to that hash.

=cut

sub loginParams
{
   my $self = shift;
   return (%{$self->{auth}});
}
#--------------------------------#

=item request KEY => VALUE, KEY => VALUE, ...

=item request SOAPDATA, SOAPDATA, ...

Helper routine which wraps its key-value pair arguments in SOAP::Data
objects, if they are not already in that form.

=cut

sub request
{
   my $pkg_or_self = shift;
   # other args below

   my @return;
   while (@_ > 0)
   {
      my $var = shift;
      if ($var && ref($var) && ref($var) eq "SOAP::Data")
      {
         push @return, $var;
      }
      else
      {
         push @return, SOAP::Data->name($var, shift);
      }
   }
   return @return;
}
#--------------------------------#

1;
__END__

=back

=head1 AUTHOR

Clotho Advanced Media, I<cpan@clotho.com>
