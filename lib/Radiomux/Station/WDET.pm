package Radiomux::Station;

use v5.16;
use warnings;
use mop;

use Encode;
use Web::Scraper::LibXML;
use Radiomux::Play;

class WDET extends Radiomux::Station {
  has $stream is ro = "http://141.217.119.35:8000/";
  has $url    is ro = "http://www.wdet.org/";
  has $name   is ro = "WDET";
  has $type   is ro = "ICE";
  has $scraper;

  method extract_plays ($body, $limit) {
    my $data = $self->scraper->scrape($body);
    return Radiomux::Play->new(title => $data->{title});
  }

  method scraper {
    $scraper //= do {
      scraper {
        process "#onNowBox h3", "title", "text";
        process "#onNowBox h4 > ul > li", "time", "text";
      };
    };
  }
}

1;
