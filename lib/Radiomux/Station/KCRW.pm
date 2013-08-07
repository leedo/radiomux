package Radiomux::Station;

class KCRW extends Radiomux::Station {
  has $url    is ro = "http://www.kcrw.com/schedule";
  has $name   is ro = "KCRW";
  has $stream is ro = "http://kcrw.ic.llnwd.net/stream/kcrw_music";

  method extract_plays ($body, $limit) {
    return ();
  }
}

1;
