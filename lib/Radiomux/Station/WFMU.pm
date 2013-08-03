package Radiomux::Station;

use v5.16;
use warnings;
use mop;

use Web::Scraper::LibXML;
use Radiomux::Play;

class WFMU extends Radiomux::Station {
  has $stream is ro = "http://stream0.wfmu.org/freeform-128k";
  has $url    is ro = "http://wfmu.org/";
  has $name   is ro = "WFMU";
  has $type   is ro = "HTTP";
  has $scraper;

  method extract_plays ($body, $limit) {
    my $data = $self->scraper->scrape($body);
    return () unless $data->{title};
    $data->{title} =~ s/[\s\n]+/ /sg;
    my ($title, $artist) = $data->{title} =~ /"([^"]+)" by (.+)/;
    $title = $data->{title} unless $title;
    return Radiomux::Play->new(
      title => $title,
      ($artist ? (artist => $artist) : ()),
    );
  }

  method scraper {
    $scraper //= do {
      scraper {
        process "#nowplaying div:first-child div.bigline", "title", "text";
      };
    };
  }
}

1;
