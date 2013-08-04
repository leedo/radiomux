package Radiomux::Station;

use v5.16;
use warnings;
use mop;

use AnyEvent::Socket;
use URI;

class WUOM extends Radiomux::Station::WEMU {
  has $http_headers is ro;
  has $stream is ro = "http://ummedia12.miserver.it.umich.edu:8004/stream/1/";
  has $url    is ro = "http://www.michiganradio.org/schedule";
  has $name   is ro = "WUOM";
  has $type   is ro = "ICY";
}

1;
