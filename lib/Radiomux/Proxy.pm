package Radiomux;

use v5.16;
use warnings;
use mop;

use AnyEvent::Handle;
use AnyEvent::HTTP;

class Proxy {
  has $max = 1;
  has $station is ro;
  has $listeners is rw = {};
  has $queue is rw = [];
  has $http_headers is ro;
  has $audio_headers is ro;
  has $handle;
  has $connected;

  method connect {
    http_get $station->stream,
      want_body_handle => 1,
      sub {
        my ($_handle, $headers) = @_;

        if ($headers->{Status} == 200) {
          $http_headers = [ map {$_ => $headers->{$_}} grep {/^[a-z]/} keys $headers ];
          $connected = 1;
          my ($current_frame, $content_length);
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
        else {
          $connected = 0;
        }
      };
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
    my $writer = $respond->([200, [@$http_headers]]);
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
