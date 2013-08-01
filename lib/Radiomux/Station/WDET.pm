package Radiomux::Station;

use v5.16;
use warnings;
use mop;

class WDET extends Radiomux::Station {
  has $stream is ro = "http://141.217.119.35:8000/";
  has $url    is ro = "http://www.wdet.org/";
  has $name   is ro = "WDET";
  has $type   is ro = "ICE";

  method extract_plays ($body) {
    return ();
  }
}

1;
