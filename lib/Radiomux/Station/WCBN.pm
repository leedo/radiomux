use v5.16;
use warnings;
use mop;

use Web::Scraper;

class Radiomux::Station::WCBN extends Radiomux::Station {
  has $scraper;
  has $url is ro = "http://www.wcbn.org/playlist";

  method extract_plays ($body) {
    my $data = $self->scraper->scrape($body);
    my $count = -1;
    my @columns = qw{times artists plays albums labels};
    for my $column (@columns) {
      if ($count > -1 and $count != @{$data->{$column}}) {
        die "uneven number of table cells $url";
      }
      $count = @{$data->{$column}};
    }

    my @plays;

    for my $row (0 .. $count) {
      push @plays, Radiomux::Play->new(
        map { $_ => $data->{$_}[$row] } @columns
      );
    }

    return @plays;
  }

  method scraper {
    $scraper //= do {
      my $nth = sub { "table#playlist > tbody > tr > td:nth-child($_[0])" };
      scraper {
        process $nth->(1), 'times[]'   => 'text';
        process $nth->(2), 'artists[]' => 'text';
        process $nth->(3), 'plays[]'  => 'text';
        process $nth->(4), 'albums[]'  => 'text';
        process $nth->(5), 'labels[]'  => 'text';
      };
    };
  }
}

1;
