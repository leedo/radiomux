package Radiomux::Station;

use v5.16;
use warnings;
use mop;

class WFMU extends Radiomux::Station {
  has $stream is ro = "http://stream0.wfmu.org/freeform-128k";
  has $url    is ro = "http://wfmu.org/table";
  has $name   is ro = "WFMU";
  has $type   is ro = "HTTP";

  method extract_plays ($body) {
    return ();
  }
}

1;
