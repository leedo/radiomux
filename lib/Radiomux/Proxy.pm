package Radiomux;

use v5.16;
use warnings;
use mop;

use AnyEvent::Handle;

class Proxy is abstract {
  has $max = 1;
  has $station is ro;
  has $listeners is rw = {};
  has $queue is rw = [];
  has $http_headers is ro;
  has $handle;
  has $connected;

  method setup_handle ($_handle) {
    $_handle->on_read(sub {
      if (@$queue) {
        # not-so-carefully wait for the next frame header
        shift->push_read(regex => qr{\xff}, sub {
          while (my $listener = shift @$queue) {
            AE::log debug => "adding new listener";
            $self->_add_listener(@$listener);
          }
          my $data = "\xff$_[1]";
          $_->push_write($data) for map { $_->[0] } values %$listeners;
        });
      }
      else {
        shift->push_read(chunk => 1024, sub {
          $_->push_write($_[1]) for map { $_->[0] } values %$listeners;
        });
      }
    });

    $_handle->on_error(sub { AE::log warn => $_[2]; $self->destroy });
    $handle = $_handle;
  }

  method has_listeners {
    return keys %$listeners > 0;
  }

  method destroy {
    AE::log debug => "destroying stream";
    $handle->destroy;
    $_->destroy for map { $_->[0] } values %$listeners;
    $connected = 0;
    $listeners = {};
  }

  method add_listener ($env, $respond) {
    push @$queue, [$env, $respond];
    $self->connect unless $connected;
  }

  method _add_listener ($env, $respond) {
    my $id = $max++;
    my $writer = $respond->([200, [@{$self->http_headers}]]);
    my $h = AnyEvent::Handle->new(
      fh => $env->{'psgix.io'},
      on_error => sub {
        AE::log warn => $_[2];
        delete $listeners->{$id};
        $self->destroy unless keys %$listeners;
      }
    );
    $listeners->{$id} = [$h, $env, $writer];
  }
}

1;
