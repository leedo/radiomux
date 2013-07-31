use Test::More;
use Radiomux::Monitor;
use Radiomux::Station::WCBN;

BEGIN { use_ok 'Radiomux::Monitor' }

my $w = Radiomux::Monitor->new;

isa_ok $w, 'Radiomux::Monitor';

my $cv = AE::cv;
$w->subscribe(sub {
  my $station = shift;
  ok scalar @{$station->plays} > 0, "monitor subscribe gets plays"; 
  $cv->send;
});

my $station = Radiomux::Station::WCBN->new;
$w->add_station($station);

$w->start(1);
$cv->recv;

done_testing;
