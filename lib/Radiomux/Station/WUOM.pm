package Radiomux::Station;

use v5.16;
use warnings;
use mop;

use AnyEvent::Socket;
use URI;

class WUOM extends Radiomux::Station {
  has $http_headers is ro;
  has $stream is ro = "http://ummedia12.miserver.it.umich.edu:8004/stream/1/";
  has $url    is ro = "http://www.michiganradio.org/";
  has $name   is ro = "WUOM";
  has $type   is ro = "ICE";

  method extract_plays ($body) {
    return ();
  }
}

1;
