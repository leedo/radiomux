package Radiomux;

use v5.16;
use warnings;
use mop;

use AnyEvent::Handle;
use Radiomux::Frame;
use Radiomux::Proxy::HTTP;
use Radiomux::Proxy::ICE;

class Proxy is abstract {
  has $max = 1;
  has $station is ro;
  has $listeners is rw = {};
  has $queue is rw = [];
  has $http_headers is rw;
  has $handle;
  has $connected is ro;

  submethod with ($_station) {
    state %proxies;
    $proxies{$_station->name} //= do {
      my $klass = "Radiomux::Proxy::" . $_station->type;
      $klass->new(station => $_station);
    };
  }

  method setup_handle ($_handle) {
    warn "setting up main stream for " . $station->name;
    $connected = 1;
    $_handle->on_read(sub {
      if (@$queue) {
        # not-so-carefully wait for the next frame header
        shift->push_read(regex => qr{\xff}, sub {

          # write everything up to start of header
          $_->push_write($_[1]) for map { $_->[0] } values %$listeners;

          # read rest of header
          shift->push_read(chunk => 3, sub {
            my $header = "\xff$_[1]";
            if (Radiomux::Frame::valid_frame($header)) {
              while (my $listener = shift @$queue) {
                AE::log debug => "adding new listener";
                $self->_add_listener(@$listener);
              }
              $_->push_write($header) for map { $_->[0] } values %$listeners;
            }
          });
        });
      }
      else {
        shift->push_read(chunk => 1024 * 32, sub {
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
    $handle->destroy if $handle;
    $_->destroy for map { $_->[0] } values %$listeners;
    $connected = 0;
    $listeners = {};
    $queue = [];
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
