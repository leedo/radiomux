use v5.16;
use warnings;

use Plack::Builder;
use Plack::App::File;
use Plack::Request;

use Radiomux::Proxy;
use Radiomux::Monitor;
use Radiomux::Monitor;

use Radiomux::Station::WCBN;
use Radiomux::Station::WEMU;
use Radiomux::Station::WDET;
use Radiomux::Station::WUOM;
use Radiomux::Station::WFMU;

use JSON::XS;
use Text::Xslate qw{mark_raw};
use Encode;
use Data::UUID;

use AnyEvent::Handle;
use AnyEvent::Redis;

our $max = 1; # stream counter for unique id
our %events;
our $monitor = Radiomux::Monitor->new;
our $template = Text::Xslate->new(path => "share/templates");
our $redis = AnyEvent::Redis->new;
our $uuid = Data::UUID->new;

$monitor->subscribe(sub {
  my ($station, @plays) = @_;
  for my $h (map { $_->[0] } values %events) {
    my $data = encode_json {
      station => $station->name,
      plays   => [map { $_->marshall } @plays],
    };
    $h->push_write("data: $data\n\n");
  }
});

$monitor->add_station(Radiomux::Station::WCBN->new);
$monitor->add_station(Radiomux::Station::WEMU->new);
$monitor->add_station(Radiomux::Station::WDET->new);
$monitor->add_station(Radiomux::Station::WUOM->new);
$monitor->add_station(Radiomux::Station::WFMU->new);
$monitor->start(5);

builder {
  enable "Plack::Middleware::Static", path => qr{^/assets/}, root => "./share/";

  my $recordings = Plack::App::File->new(root => "./recordings")->to_app;

  mount "/recordings" => sub {
    my $res = $recordings->(shift);
    Plack::Util::header_push($res->[1], "Content-Disposition", "attachment");
    $res;
  };

  mount "/", sub {
    my $env = shift;
    my $html = $template->render("index.tx", {
      monitor => $monitor,
      data    => mark_raw encode_json $monitor->marshall,
    });
    return [200, ["Content-Type" => "text/html"], [encode "utf8", $html]];
  };

  mount "/play", sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $token = $req->parameters->{token};
    my $station = $monitor->find_station($req->parameters->{station});

    unless ($station and $token) {
      return [500, ["Content-Type" => "text/plain"], ["invalid request"]];
    }

    return sub {
      my $respond = shift;
      $redis->srem($station->name, $token, sub {
        return $respond->([500, ["Content-Type" => "text/plain"], ["invalid token"]])
          unless shift == 1;
        Radiomux::Proxy->with($station)->add_listener($env, $respond, $token);
      });
    };
  };

  mount "/token", sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $station = $monitor->find_station($req->parameters->{station});

    unless ($station) {
      return [500, ["Content-Type" => "text/plain"], ["invalid station"]];
    }

    my $token = $uuid->create_str;
    return sub {
      my $respond = shift;
      $redis->sadd($station->name, $token, sub {
        $respond->([200, ["Content-Type" => "text/plain"], [$token]]);
      });
    };
  };

  mount "/record/stop", sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $token = $req->parameters->{token};
    my $station = $monitor->find_station($req->parameters->{station});

    unless ($station and $token) {
      return [500, ["Content-Type" => "text/plain"], ["invalid request"]];
    }

    my $filename = Radiomux::Proxy->with($station)->stop_record($token);
    return [200, ["Content-Type" => "text/plain"], [$filename]];
  };

  mount "/record/start", sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $token = $req->parameters->{token};
    my $station = $monitor->find_station($req->parameters->{station});

    unless ($station and $token) {
      return [500, ["Content-Type" => "text/plain"], ["invalid request"]];
    }

    Radiomux::Proxy->with($station)->start_record($token);
    return [200, ["Content-Type" => "text/plain"], ["ok"]];
  };

  mount "/plays", sub {
    my $env = shift;
    die "server does not support psgix.io" unless defined $env->{'psgix.io'};
    return sub {
      my $respond = shift;
      my $writer = $respond->([200, ["Content-Type" => "text/event-stream"]]);
      my $id = $max++;

      my $h = AnyEvent::Handle->new(
        fh => $env->{'psgix.io'},
        on_error => sub { delete $events{$id} },
      );

      $events{$id} = [$h, $writer, $env];
    };
  };
}
