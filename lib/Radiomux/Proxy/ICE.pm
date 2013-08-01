package Radiomux::Proxy;

use v5.16;
use warnings;
use mop;

use AnyEvent::Socket;
use AnyEvent::Handle;
use URI;

class ICE extends Radiomux::Proxy {
  has $http_headers is ro;
  has $connected;

  method connect () {
    my $uri = URI->new($self->station->stream);
    tcp_connect $uri->host, $uri->port, sub {
      my ($fh) = @_ or die "unable to connect to stream";
      my $h = AnyEvent::Handle->new(fh => $fh);
      $h->push_write("GET " . $uri->path . " HTTP/1.0\015\012\015\012");
      $h->push_read(regex => qr{\015\012\015\012}, sub {
        my @headers = split "\015\012", $_[1];

        if (shift(@headers) !~ /200/) {
          $self->destroy;
          return;
        }

        while (my $header = shift @headers) {
          if ($header =~ /^([a-zA-Z_-]+):\s*(.+)/) {
            push @$http_headers, $1, $2;
          }
        }

        $connected = 1;
        $self->setup_handle($h);
      });
    };
  }
}

1;
