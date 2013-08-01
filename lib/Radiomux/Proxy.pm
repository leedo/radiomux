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
  has $connecting;

  method connect {
    $connecting = 1;
    http_get $station->stream,
      want_body_handle => 1,
      sub {
        my ($_handle, $headers) = @_;
        $connecting = 0;

        if ($headers->{Status} == 200) {
          $http_headers = [ map {$_ => $headers->{$_}} grep {/^[a-z]/} keys $headers ];
          $connected = 1;
          my ($current_frame, $content_length);
          $_handle->on_read(sub {
            if (@$queue) {
              # not-so-carefully wait for the next frame header
              shift->push_read(chunk => 1, sub {
                if ($_[1] eq "\xff") {
                  shift->push_read(chunk => 3, sub {
                    while (my $listener = shift @$queue) {
                      $self->add_listener(@$listener);
                    }
                    $_->push_write("\xff$_[1]") for map { $_->[0] } values %$listeners;
                  });
                }
              });
            }
            else {
              shift->push_read(chunk => 1024, sub {
                $_->push_write($_[1]) for map { $_->[0] } values %$listeners;
              });
            }
          });

          $_handle->on_error(sub { $self->destroy });
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
    $handle->destroy;
    $_->destroy for map { $_->[0] } values %$listeners;
    $listeners = {};
  }

  method add_listener ($env, $respond) {
    if (!$connected) {
      warn "adding request to connect queue";
      push @$queue, [$env, $respond];
      $self->connect;
      return;
    }

    warn "responding with stream";
    my $id = $max++;
    my $writer = $respond->([200, [@$http_headers]]);
    my $h = AnyEvent::Handle->new(
      fh => $env->{'psgix.io'},
      on_error => sub {
        warn $_[2];
        delete $listeners->{$id};
        $self->destroy unless keys %$listeners;
      }
    );
    $listeners->{$id} = [$h, $env, $writer];
  }
}

1;
