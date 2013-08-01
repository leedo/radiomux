package Radiomux;

use v5.16;
use warnings;
use mop;

use AnyEvent::Handle;
use AnyEvent::HTTP;

# stolen from MPEG::Audio::Frame
my @layers = (
  undef,  # 0b00 is reserved
  2,    # 0b01 Layer III
  1,    # 0b10 Layer II
  0,    # 0b11 Layer I
);

my @versions = (
  1,    # 0b00 MPEG 2.5
  undef,  # 0b01 is reserved
  1,    # 0b10 MPEG 2
  0,    # 0b11 MPEG 1
);

my @bitrates = (
    # 0/free 1   10  11  100  101  110  111  1000 1001 1010 1011 1100 1101 1110 # bits
  [ # mpeg 1
    [ undef, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448 ], # l1
    [ undef, 32, 48, 56, 64,  80,  96,  112, 128, 160, 192, 224, 256, 320, 384 ], # l2
    [ undef, 32, 40, 48, 56,  64,  80,  96,  112, 128, 160, 192, 224, 256, 320 ], # l3
  ],
  [ # mpeg 2
    [ undef, 32, 48, 56, 64,  80,  96,  112, 128, 144, 160, 176, 192, 224, 256 ], # l1
    [ undef, 8,  16, 24, 32,  40,  48,  56,  64,  80,  96,  112, 128, 144, 160 ], # l3
    [ undef, 8,  16, 24, 32,  40,  48,  56,  64,  80,  96,  112, 128, 144, 160 ], # l3
  ],
);

my @samples = (
  [ # MPEG 2.5
    11025, # 0b00
    12000, # 0b01
    8000,  # 0b10
    undef, # 0b11 is reserved
  ],
  undef, # version 0b01 is reserved
  [ # MPEG 2
    22050, # 0b00
    24000, # 0b01
    16000, # 0b10
    undef, # 0b11 is reserved
  ],
  [ # MPEG 1
    44100, # 0b00
    48000, # 0b01
    32000, # 0b10
    undef, # 0b11 is reserved
  ],
);

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
