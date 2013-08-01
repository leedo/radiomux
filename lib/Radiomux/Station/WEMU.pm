package Radiomux::Station;

use v5.16;
use warnings;
use mop;

class WEMU extends Radiomux::Station {
  has $stream is ro = "http://pubint.ic.llnwd.net/stream/pubint_wemu";
  has $url    is ro = "http://www.wemu.org/schedule";
  has $name   is ro = "WEMU";

  method extract_plays ($body, $limit) {
    my $data = $self->scraper->scrape($body);

    my $count = -1;
    my @columns = qw{time artist title};
    for my $column (@columns) {
      if ($count > -1 and $count != @{$data->{$column}}) {
        die "uneven number of table cells $url";
      }
      $count = @{$data->{$column}};
    }

    return ();
  }

  method scraper {
    $scraper //= do {
      my $schedule = "#schedule-layout-day .schedule-layout-row";
      scraper {
        process ".schedule-display-date", "date", "text";
        process "$schedule .schedule-layout-time", "time[]", "text";
        process "$schedule .schedule-title", "title", "text[]";
        process "$schedule .schedule-host", "artist", "text[]";
    };
  }
}

1;
