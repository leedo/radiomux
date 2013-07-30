use Test::More;
use Radiomux::Monitor;

BEGIN { use_ok 'Radiomux::Monitor' }

my $w = Radiomux::Monitor->new;

isa_ok $w, 'Radiomux::Monitor';

done_testing;
