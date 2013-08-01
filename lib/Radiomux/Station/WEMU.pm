package Radiomux::Station;

use v5.16;
use warnings;
use mop;

class WEMU extends Radiomux::Station {
  has $stream is ro = "http://pubint.ic.llnwd.net/stream/pubint_wemu";
  has $url    is ro = "http://www.wemu.org/";
  has $name   is ro = "WEMU";

  method extract_plays ($body) {
    return ();
  }
}

1;
