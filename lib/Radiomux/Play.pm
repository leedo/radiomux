package Radiomux;

use v5.16;
use warnings;
use mop;

use Digest::SHA1 qw(sha1_hex);

class Play {
  has $artist     is ro;
  has $title      is ro;
  has $album      is ro;
  has $label      is ro;
  has $timestamp  is ro;
  has $hash;

  submethod BUILD {
    for (qw{title}) {
      die "$_ is required" unless defined $self->$_
    }
  }

  method serialize {
    +{ map { $_ => $self->$_ } qw{artist title album label timestamp hash} };
  }

  method hash {
    sha1_hex join "", map {$_ || ""} $artist, $title, $album, $label, $timestamp;
  }
}

1;
