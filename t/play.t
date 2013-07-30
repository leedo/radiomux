use Test::More;
use Test::Fatal;
use Radiomux::Play;

BEGIN { use_ok 'Radiomux::Play' }

like exception { Radiomux::Play->new },
  qr{is required},
  "required params";

my $p = Radiomux::Play->new(
  artist => "Ween",
  title  => "Roses Are Free",
  album  => "Chocolate and Cheese",
  label  => "Electra",
  timestamp => 1374979431,
);

is $p->hash,
  "84a105cc723ebdc51229ce34a64e4a6c937e7834",
  "correct hash";

done_testing;


