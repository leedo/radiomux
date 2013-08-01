package Radiomux;

use v5.16;
use warnings;
use mop;

use AE;

class Monitor {
  has $stations  is rw = [];
  has $listeners is rw = [];
  has $timer;

  method find_station ($name) {
    for (@$stations) {
      return $_ if lc $_->name eq lc $name;
    }
  }

  method start ($interval) {
    $timer = AE::timer 0, $interval, sub { $self->tick };
  }

  method tick { $_->fetch for @$stations }

  method add_station ($station) {
    push @$stations, $station;
    $station->subscribe(sub { $self->broadcast(@_) });
  }

  method subscribe ($callback) {
    push @$listeners, $callback;
  }

  method broadcast ($station, @tracks) {
    $_->($station, @tracks) for @$listeners;
  }

  method marshall {
    [
      map {
        +{
          station => $_->name,
          plays   => [map { $_->marshall } @{$_->plays}],
        }
      } @{$self->stations}
    ];
  }
}

1;
