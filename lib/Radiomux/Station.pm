package Radiomux;

use v5.16;
use warnings;
use mop;

use List::MoreUtils qw{any};
use Encode;
use AE;
use AnyEvent::HTTP;

class Station is abstract {
  has $plays     is rw = [];
  has $listeners is rw = [];
  has $id is ro;
  has $type is ro = "HTTP";

  method name     { die "need to override" }
  method station  { die "need to override" }
  method url      { die "need to override" }

  method fetch {
    my $url = $self->url;
    http_get $url, sub {
      my ($body, $headers) = @_;
      if ($headers->{Status} != 200) {
        AE::log warn => "failed to fetch $url - $headers->{Status} ($headers->{Reason})";
        return;
      }
      my @plays = $self->extract_plays(decode utf8 => $body);
      my @new = sort { $a->timestamp <=> $b->timestamp} grep { $self->maybe_add_play($_) } @plays;
      $self->broadcast(@new) if @new;
    }
  }

  method maybe_add_play ($play) {
    return if any { $_->hash eq $play->hash } @$plays;
    $plays = [ sort { $a->timestamp <=> $b->timestamp } @$plays, $play ];
    return 1;
  }

  method subscribe ($callback) {
    push @$listeners, $callback;
  }

  method broadcast (@plays) {
    $_->($self, @plays) for @$listeners;
  }
}

1;
