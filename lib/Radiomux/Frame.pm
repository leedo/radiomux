package Radiomux::Frame;

use strict;
#use warnings;
use integer;

use vars qw/$lax $mpeg25/;

# stolen from Audio::MPEG::Frame

$mpeg25 = 1; # normally support it

my @consts;
sub B ($) { $_[0] == 12 ? 3 : (1 + ($_[0] / 4)) }
sub M ($) {
  my $s = 0;
  $s += $consts[$_][1] for (0 .. $_[0]-1);
  $s%=8;
  my $v = '';
  vec($v,8-$_,1) = 1 for $s+1 .. $s+$consts[$_[0]][1];
  "0x" . unpack("H*", $v);
}
sub R ($) { 
  my $i = 0;
  my $m = eval "M_$consts[$_[0]][0]()";
  $i++ until (($m >> $i) & 1);
  $i;
}

BEGIN {
  @consts = (
    # [ $name, $width ]
    [ SYNC => 3 ],
    [ VERSION => 2 ],
    [ LAYER => 2 ],
    [ CRC => 1 ], 
    [ BITRATE => 4 ],
    [ SAMPLE => 2 ],
    [ PAD => 1 ],
    [ PRIVATE => 1 ],
    [ CHANMODE => 2 ],
    [ MODEXT => 2 ],
    [ COPY => 1 ],
    [ HOME => 1 ],
    [ EMPH => 2 ],
  );
  my $i = 0;
  foreach my $c (@consts){
    my $CONST = $c->[0];
    eval "sub $CONST () { $i }"; # offset in $self->{header}
    eval "sub M_$CONST () { " . M($i) ." }"; # bit mask
    eval "sub B_$CONST () { " . B($i) . " }"; # offset in read()'s @hb
    eval "sub R_$CONST () { " . R($i) . " }"; # amount to right shift
    $i++;
  }
}

sub valid_frame {
  my $bytes = shift;
  my @hb = unpack("CCCC",$bytes);

  ($hb[B_SYNC]    & M_SYNC)    >> R_SYNC    != 0x07 and next; # see if the sync remains
  my $v = ($hb[B_VERSION] & M_VERSION) >> R_VERSION;
  $v == 0x00 and ($mpeg25 or next);
  $v == 0x01 and next;
  ($hb[B_LAYER]   & M_LAYER)   >> R_LAYER   == 0x00 and next;
  ($hb[B_BITRATE] & M_BITRATE) >> R_BITRATE == 0x0f and next;
  ($hb[B_SAMPLE]  & M_SAMPLE)  >> R_SAMPLE  == 0x03 and next;
  ($hb[B_EMPH]    & M_EMPH)    >> R_EMPH    == 0x02 and ($lax or next);

  return 1;
}
