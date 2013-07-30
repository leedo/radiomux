use v5.16;
use warnings;
use mop;

use List::MoreUtils qw{any};
use Encode;
use AE;

class Radiomux::Station is abstract {
  has $plays     is rw = [];
  has $listeners is rw = [];

  method fetch {
    my $url = $self->url;
    http_get $url, sub {
      my ($body, $headers) = @_;
      if ($headers->{Status} != 200) {
        AE::log warn => "failed to fetch $url - $headers->{Status} ($headers->{Reason})";
        return;
      }
      my @plays = $self->extract_plays(decode utf8 => $body);
      $self->maybe_add_play($_) for @plays;
    }
  }

  method maybe_add_play ($play) {
    return if any { $_->hash eq $play->hash } @$plays;
    $plays = [ sort { $a->timestamp <=> $b->timestamp } @$plays, $play ];
  }

  method subscribe ($callback) {
    push @$listeners, $callback;
  }

  method broadcast (@plays) {
    $_->($self, @plays) for @$listeners;
  }
}

1;
