use v5.16;
use warnings;
use mop;

use Web::Scraper;
use DateTime;

class Radiomux::Station::WCBN extends Radiomux::Station {
  has $scraper;
  has $show;
  has $url is ro = "http://www.wcbn.org/playlist";

  method extract_plays ($body) {
    my $data = $self->scraper->scrape($body);
    my $count = -1;
    my @columns = qw{time artist title album label};
    for my $column (@columns) {
      if ($count > -1 and $count != @{$data->{$column}}) {
        die "uneven number of table cells $url";
      }
      $count = @{$data->{$column}};
    }

    my ($month, $day, $year) = split "/", $data->{date} =~ s/\s+//gr;
    my @plays;

    for my $row (0 .. $count - 1) {
      my ($hour, $min, $ap) = split /[^\d]/, $data->{time}[$row];
      my $date = DateTime->new(
        month   => $month,
        day     => $day,
        year    => $year,
        hour    => ($ap eq "AM" ? $hour : $hour + 12) - 1,
        minute  => $min,
      );
      push @plays, Radiomux::Play->new(
        timestamp => $date->epoch,
        map { $_ => $data->{$_}[$row] } @columns
      );
    }

    return @plays;
  }

  method scraper {
    $scraper //= do {
      my $nth = sub { "table#playlist > tbody > tr > td:nth-last-child($_[0])" };
      scraper {
        process "table#playlist > tbody > tr:first-child > td.show", "show", "text";
        process "table#playlist > tbody > tr:first-child > td.date", "date", "text";
        process $nth->(5), 'time[]'   => 'text';
        process $nth->(4), 'artist[]' => 'text';
        process $nth->(3), 'title[]'  => 'text';
        process $nth->(2), 'album[]'  => 'text';
        process $nth->(1), 'label[]'  => 'text';
      };
    };
  }
}

1;
