package Radiomux::Proxy;

use v5.16;
use warnings;
use mop;

use AnyEvent::HTTP;

class HTTP extends Radiomux::Proxy {
  has $connected;
  has $http_headers is ro;

  method connect {
    http_get $self->station->stream,
      want_body_handle => 1,
      sub {
        my ($_handle, $headers) = @_;

        if ($headers->{Status} == 200) {
          $http_headers = [ map {$_ => $headers->{$_}} grep {/^[a-z]/ and !/^icy-/i} keys $headers ];
          $self->setup_handle($_handle);
        }
        else {
          $self->destroy;
        }
      };
  }
}
1;
