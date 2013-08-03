package Radiomux;

use v5.16;
use warnings;
use mop;

use AnyEvent::AIO;
use IO::AIO qw{aio_write aio_open aio_mkdir};

class Save {
  has $station_name is ro;
  has $on_error;
  has $buffer = "";
  has $offset = 0;
  has $fh;
  has $id;

  submethod BUILD {
    my $now = time;
    aio_mkdir "/Users/lee/src/radiomux/recordings/$station_name/", 0755, sub {
      unless ($_[0]) {
        $on_error->("failed to make dir: $!");
        return;
      }
      aio_open "/Users/lee/src/radiomux/recordings/$station_name/$now.mp3", IO::AIO::O_WRONLY | IO::AIO::O_CREAT, 0644, sub {
        unless ($_[0]) {
          $on_error->("failed to open mp3: $!");
          return;
        }
        $fh = $_[0];
        $self->write($buffer) if $buffer;
      };
    };
  }

  method write ($data) {
    if ($fh) {
      aio_write $fh, $offset, length $data, $data, 0, sub {
        $_[0] > 0 or die "write error: $!";
        $offset += $_[0];
      };
    }
    else {
      $buffer .= $data;
    }
  }
}

1;
