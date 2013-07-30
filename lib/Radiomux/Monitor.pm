use v5.16;
use warnings;
use mop;

use AE;

class Radiomux::Monitor {
  has $stations  is rw = [];
  has $listeners is rw = [];
  has $timer;

  method start ($interval) {
    $timer = AE::timer 0, $interval, sub { $self->tick };
  }

  method tick { $_->fetch for @$stations }

  method add_station ($station) {
    push @$stations, $station;
    $station->subscribe(sub { $self->broadcast(@_) });
  }

  method subscripe ($callback) {
    push @$listeners, $callback;
  }

  method broadcast ($station, @tracks) {
    $_->($station, @tracks) for @$listeners;
  }
}

1;
