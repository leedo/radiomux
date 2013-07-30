use v5.16;
use Test::More;
use Test::Fatal;
use Radiomux::Play;
use Radiomux::Station;
use Radiomux::Station::WCBN;

like exception { Radiomux::Station->new },
  qr{Cannot instantiate abstract class},
  "is abstract";

my $station = sub {
  Radiomux::Station::WCBN->new;
};

my $play = sub {
  state $t = "a";
  Radiomux::Play->new(
    timestamp => time,
    map { $_, $t++ } qw{artist title album label},
  );
};

subtest "can't add same play twice", sub {
  my $r = $station->();
  my $p = $play->();

  $r->maybe_add_play($p);
  is_deeply $r->plays, [$p];

  $r->maybe_add_play($p);
  is_deeply $r->plays, [$p];
};

subtest "tracks sorted by timestamp", sub {
  my $r = $station->();
  my $a = $play->();
  sleep 1;
  my $b = $play->();
  sleep 1;
  my $c = $play->();

  $r->maybe_add_play($b);
  $r->maybe_add_play($a);
  $r->maybe_add_play($c);

  is_deeply $r->plays, [$a, $b, $c];
};

subtest "fetch gets some tracks", sub {
  my $r = $station->();
  my $cv = AE::cv;
  $r->subscribe(sub { $cv->send });
  $r->fetch;
  $cv->recv;
  is 1, 1;
};

done_testing;
