package Radiomux;

use v5.16;
use warnings;
use mop;

class Listener {
  has $handle;
  has $env;
  has $writer;
  has $respond;
  has $token is ro;
  has $on_error is ro;
  has $save;

  method write {
    $handle->push_write($_[0]);
  }

  method set_save($_save) {
    $save->destroy if $save;
    $save = $_save;
  }

  method stop_save {
    if ($save) {
      $save->destroy;
      return $save->filename;
    }
  }

  method destroy {
    $save->destroy   if $save;
    $handle->destroy if $handle;
  }

  method respond ($headers) {
    $writer = $respond->([200, [@$headers]]);
    $handle = AnyEvent::Handle->new(
      fh => $env->{'psgix.io'},
      on_error => sub { warn $_[2]; $on_error->($self->token) },
    );
    return $self;
  }
}

1;
