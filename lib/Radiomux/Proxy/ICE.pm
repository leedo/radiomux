package Radiomux::Proxy;

use v5.16;
use warnings;
use mop;

use AnyEvent::Socket;
use AnyEvent::Handle;
use URI;

class ICE extends Radiomux::Proxy {
  has $http_headers is ro;

  method connect () {
    my $uri = URI->new($self->station->stream);
    tcp_connect $uri->host, $uri->port, sub {
      my ($fh) = @_ or die "unable to connect to stream";
      my $h = AnyEvent::Handle->new(fh => $fh);
      $h->push_write("GET " . $uri->path . " HTTP/1.0\015\012\015\012");
      my $headers = [];
      $h->push_read(regex => qr{\015\012\015\012}, sub {
        for my $header (split "\015\012", $_[1]) {
          if ($header =~ /^([a-zA-Z_-]+):\s*(.+)/) {
            push @$headers, $1, $2;
          }
        }
        $http_headers = $headers;
        $self->setup_handle($h);
      });
    };
  }
}

1;
