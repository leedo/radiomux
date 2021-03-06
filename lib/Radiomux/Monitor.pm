package Radiomux;

use v5.16;
use warnings;
use mop;

use AE;

class Monitor {
  has $stations  is rw = [];
  has $listeners is rw = [];
  has $interval = 15;
  has $timer;

  method find_station ($name) {
    for (@$stations) {
      return $_ if lc $_->name eq lc $name;
    }
  }

  method start {
    $self->tick;
  }

  method tick {
    undef $timer;
    my $cb; $cb = sub {
      my ($station, @stations) = @_;

      if (!$station) {
        undef $cb;
        $timer = AE::timer $interval, 0, sub { $self->tick };
        return;
      }

      $station->fetch(sub {
         my ($err, $station, $plays) = @_;
         warn $err if $err;
         $self->broadcast($station, $plays) if $plays;
         $cb->(@stations);
       });
    };
    $cb->(@$stations);
  }

  method add_station ($station) {
    push @$stations, $station;
  }

  method subscribe ($callback) {
    push @$listeners, $callback;
  }

  method broadcast ($station, $plays) {
    $_->($station, @$plays) for @$listeners;
  }

  method serialize {
    [
      map {
        +{
          station => $_->name,
          plays   => [map { $_->serialize } @{$_->plays}],
        }
      } @{$self->stations}
    ];
  }
}

1;
