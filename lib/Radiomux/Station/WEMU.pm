package Radiomux::Station;

use v5.16;
use warnings;
use mop;

use DateTime;
use Radiomux::Play;
use Web::Scraper;

my @months = qw{
  january february march april may june july
  august september october november december
};

class WEMU extends Radiomux::Station {
  has $stream is ro = "http://pubint.ic.llnwd.net/stream/pubint_wemu";
  has $url    is ro = "http://www.wemu.org/schedule";
  has $name   is ro = "WEMU";
  has $scraper;

  sub find_month {
    my $name = lc shift;
    for (my $i=0; $i < @months; $i++) {
      return $i if $name eq $months[$i];
    }
  }

  method extract_plays ($body, $limit) {
    my $data = $self->scraper->scrape($body);

    my ($hour, $minute, $ampm) = $data->{time} =~ /(\d+):(\d+) (AM|PM)/;
    my ($month, $day) = $data->{date} =~ /\w+, (\w+) (\d+)/;

    my $now = DateTime->now;
    my $date = DateTime->new(
      hour => ($ampm eq "PM" ? $hour + 12 : $hour),
      minute => $minute,
      day => $day,
      month => find_month($month),
      year => $now->year,
      time_zone => "America/Detroit",
    );

    my $play = Radiomux::Play->new(
      artist => $data->{artist},
      title  => $data->{title},
      timestamp => $date->epoch,
    );
    return ($play);
  }

  method scraper {
    $scraper //= do {
      my $schedule = "#schedule-layout-day .schedule-layout-row.onair";
      scraper {
        process ".schedule-display-date", "date", "text";
        process "$schedule .schedule-layout-time", "time", "text";
        process "$schedule .schedule-title", "title", "text";
        process "$schedule .schedule-host", "artist", "text";
      };
    };
  }
}

1;
