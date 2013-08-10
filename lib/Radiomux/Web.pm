package Radiomux;

use v5.16;
use warnings;
use mop;

use JSON::XS;
use Text::Xslate qw{mark_raw};
use Encode;
use Data::UUID;
use Plack::Request;

use AnyEvent::Handle;
use AnyEvent::Redis;

class Webclass extends mop::class {
  has $routes is ro = {
    GET  => [],
    POST => [],
  };

  method add_route ($method, $http_method, $pattern) {
    if (defined $routes->{$http_method}) {
      push @{$routes->{$http_method}}, [$pattern, $method];
    }
  }
}

sub route {
  if (ref $_[0] eq "mop::method") {
    my $method = shift;
    $method->associated_meta->add_route($method->name, @_);
  }
}

class Web metaclass Radiomux::Webclass {
  has $events;
  has $max = 1;
  has $monitor;
  has $template;
  has $redis;
  has $uuid;

  method redis    { $redis //= AnyEvent::Redis->new }
  method uuid     { $uuid //= Data::UUID->new }
  method template { $template //= Text::Xslate->new(path => "share/templates") }
  method monitor  { $monitor //= Radiomux::Monitor->new }

  method to_app {
    my $routes = mop::get_meta($self)->routes;

    return sub {
      my $env = shift;
      my $req = Plack::Request->new($env);
      my $handlers = $routes->{$req->method};

      for my $handler (@{$handlers || []}) {
        my ($pattern, $method) = @$handler;
        if ($req->path =~ $pattern) {
          return $self->$method($req);
        }
      }
      return $self->error("not found", 404);
    };
  }

  method error ($message, $status) {
    $message //= "invalid request";
    $status //= 500;
    return [$status, ["Content-Type", "text/plain"], [$message]];
  }

  submethod BUILD {
    $self->monitor->subscribe(sub {
      my ($station, @plays) = @_;
      for my $h ($self->events) {
        my $data = encode_json {
          station => $station->name,
          plays   => [map { $_->marshall } @plays],
        };
        $h->push_write("data: $data\n\n");
      }
    });

    $self->monitor->add_station(Radiomux::Station::WCBN->new);
    $self->monitor->add_station(Radiomux::Station::WEMU->new);
    $self->monitor->add_station(Radiomux::Station::WDET->new);
    $self->monitor->add_station(Radiomux::Station::WUOM->new);
    $self->monitor->add_station(Radiomux::Station::WFMU->new);
    $self->monitor->add_station(Radiomux::Station::KCRW->new);

    $self->monitor->start;
  }

  method events { values %$events }

  method root ($req) is route(GET => qr{^/$}) {
    my $html = $self->template->render("index.tx", {
      monitor => $self->monitor,
      data    => mark_raw encode_json $self->monitor->marshall,
    });
    return [200, ["Content-Type" => "text/html"], [encode "utf8", $html]];
  }

  method play ($req) is route(GET => qr{^/play/?$}) {
    my $token = $req->parameters->{token};
    my $station = $self->monitor->find_station($req->parameters->{station});

    return $self->error unless $station and $token;

    return sub {
      my $respond = shift;
      $self->redis->get($token, sub {
        return $respond->($self->error("invalid token"))
          unless shift eq $station->name;
        Radiomux::Proxy->with($station)->add_listener($req->env, $respond, $token);
      });
    };
  }

  method token ($req) is route(GET => qr{^/token/?}) {
    my $station = $self->monitor->find_station($req->parameters->{station});

    return $self->error("invalid station") unless $station;

    my $token = $self->uuid->create_str;
    return sub {
      my $respond = shift;
      $self->redis->setex($token, 10, $station->name, sub {
        $respond->([200, ["Content-Type" => "text/plain"], [$token]]);
      });
    };
  }

  method record_stop ($req) is route(GET => qr{^/record/stop/?}) {
    my $token = $req->parameters->{token};
    my $station = $self->monitor->find_station($req->parameters->{station});

    return $self->error unless $station and $token;

    my $filename = Radiomux::Proxy->with($station)->stop_record($token);
    return [200, ["Content-Type" => "text/plain"], [$filename]];
  }

  method record_start ($req) is route(GET => qr{^/record/start/?}) {
    my $token = $req->parameters->{token};
    my $station = $self->monitor->find_station($req->parameters->{station});

    return $self->error unless $station and $token;

    Radiomux::Proxy->with($station)->start_record($token);
    return [200, ["Content-Type" => "text/plain"], ["ok"]];
  }

  method plays ($req) is route(GET => qr{^/plays/?}) {
    die "server does not support psgix.io" unless defined $req->env->{'psgix.io'};
    return sub {
      my $respond = shift;
      my $writer = $respond->([200, ["Content-Type" => "text/event-stream"]]);
      my $id = $max++;

      my $h = AnyEvent::Handle->new(
        fh => $req->env->{'psgix.io'},
        on_error => sub {
          delete $events->{$id};
          undef $req;
          undef $writer;
        },
      );

      $events->{$id} = $h;
    };
  }
}

1;
