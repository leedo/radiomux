use Test::More;
use Radiomux::Monitor;
use Radiomux::Station::WCBN;

BEGIN { use_ok 'Radiomux::Monitor' }

my $w = Radiomux::Monitor->new;

isa_ok $w, 'Radiomux::Monitor';

my $cv = AE::cv;

$w->subscribe(sub {
  my ($station, @plays) = @_;
  ok @plays > 0,
     "monitor subscribe gets plays";
  ok scalar @plays == scalar @{$station->plays},
     "all initial plays passed to subscribe";
  $cv->send;
});

my $station = Radiomux::Station::WCBN->new;
$w->add_station($station);

$w->tick;
$cv->recv;

done_testing;
