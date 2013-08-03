package Radiomux;

use v5.16;
use warnings;
use mop;

class Listener {
  has $handle;
  has $env;
  has $writer;
  has $respond;
  has $id;
  has $on_error is ro;

  method write {
    $handle->push_write($_[0]);
  }

  method destroy {
    $handle->destroy if $handle;
  }

  method respond ($headers) {
    $writer = $respond->([200, [@$headers]]);
    $handle = AnyEvent::Handle->new(
      fh => $env->{'psgix.io'},
      on_error => $on_error,
    );
    return $self;
  }
}

1;
