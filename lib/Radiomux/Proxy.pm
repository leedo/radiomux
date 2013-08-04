package Radiomux;

use v5.16;
use warnings;
use mop;

use AnyEvent::Handle;

use Radiomux::Listener;
use Radiomux::Save;
use Radiomux::Frame;
use Radiomux::Proxy::HTTP;
use Radiomux::Proxy::ICY;

class Proxy is abstract {
  has $station is ro;
  has $listeners is rw = {};
  has $recordings is rw = {};
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
          $_->write($_[1]) for values %$listeners;

          # read rest of header
          shift->push_read(chunk => 3, sub {
            my $header = "\xff$_[1]";
            if (Radiomux::Frame::valid_frame($header)) {
              while (my $listener = shift @$queue) {
                AE::log debug => "adding new listener";
                $listeners->{$listener->token} = $listener;

                # don't need any http headers for saves... hmm
                if (ref $listener eq "Radiomux::Listener") {
                  $listener->respond($self->http_headers);
                }
              }
            }
            $_->write($header) for values %$listeners;
          });
        });
      }
      else {
        shift->push_read(chunk => 1024 * 32, sub {
          $_->write($_[1]) for values %$listeners;
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
    warn "destroying stream";
    $handle->destroy if $handle;
    $_->destroy for values %$listeners;
    $connected = 0;
    $listeners = {};
    $queue = [];
  }

  method handle_disconnect ($id) {
    if (my $listener = $listeners->{$id}) {
      $listener->destroy;
      delete $listeners->{$id};
    }
    $self->destroy unless %$listeners or @$queue;
  }

  method add_listener ($env, $respond, $token) {
    my $listener = Radiomux::Listener->new(
      env      => $env,
      respond  => $respond,
      token    => $token,
      on_error => sub { $self->handle_disconnect($_[0]) },
    );

    push @$queue, $listener;
    $self->connect unless $connected;

    return $listener;
  }

  method start_record ($token) {
    die "invalid listener token" unless defined $listeners->{$token};

    my $save = Radiomux::Save->new(
      station_name => $station->name,
      on_error     => sub { warn $_[1]; $self->handle_disconnect($_[0]) },
    );

    $listeners->{$token}->set_save($save);
    push @$queue, $save;
    $self->connect unless $connected;
  }

  method stop_record ($token) {
    die "invalid listener token" unless defined $listeners->{$token};
    $listeners->{$token}->stop_save;
  }
}

1;
