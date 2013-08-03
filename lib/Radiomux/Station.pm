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
  has $id is ro;
  has $type is ro = "HTTP";
  has $limit = 20;

  method name     { die "need to override" }
  method station  { die "need to override" }
  method url      { die "need to override" }

  method fetch ($cb) {
    my $url = $self->url;
    http_get $url, sub {
      my ($body, $headers) = @_;
      if ($headers->{Status} != 200) {
        $cb->("failed to fetch $url - $headers->{Status} ($headers->{Reason})", $self);
        return;
      }

      my @new = $self->extract_plays(decode(utf8 => $body), $limit);

      if (@new and (!@$plays or $new[0]->hash ne $plays->[0]->hash)) {
        $plays = \@new;
        $cb->(undef, $self, $plays);
        return;
      }
      $cb->(undef, $self);
    }
  }
}

1;
