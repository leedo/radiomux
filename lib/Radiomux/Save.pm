package Radiomux;

use v5.16;
use warnings;
use mop;

use AnyEvent::AIO;
use IO::AIO qw{aio_write aio_open aio_mkdir};

class Save {
  has $station_name is ro;
  has $filename is ro = "";
  has $on_error;
  has $buffer = "";
  has $offset = 0;
  has $fh;

  method token { $self->id }

  submethod BUILD {
    my $now = time;
    $filename = "recordings/$station_name/$now.mp3";

    aio_mkdir "recordings/$station_name", 0755, sub {
      unless ($_[0]) {
        $on_error->($self->id, "failed to make dir: $!");
        return;
      }
      aio_open "recordings/$station_name/$now.mp3", IO::AIO::O_WRONLY | IO::AIO::O_CREAT, 0644, sub {
        unless ($_[0]) {
          $on_error->($self->id, "failed to open mp3: $!");
          return;
        }
        $fh = $_[0];
        if ($buffer) {
          $self->write($buffer);
          undef $buffer;
        }
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

  method destroy {
    $offset = 0;
    undef $buffer;

    if ($fh) {
      close $fh;
      undef $fh;
    }
  }
}

1;
