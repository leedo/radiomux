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
  has $limit = 20;

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

      my @new = $self->extract_plays(decode(utf8 => $body), $limit);

      if (@new and (!@$plays or $new[0]->hash ne $plays->[0]->hash)) {
        $self->broadcast(@new);
      }

      $plays = \@new;
    }
  }

  method subscribe ($callback) {
    push @$listeners, $callback;
  }

  method broadcast (@plays) {
    $_->($self, @plays) for @$listeners;
  }
}

1;
