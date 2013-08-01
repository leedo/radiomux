use v5.16;
use warnings;

use Plack::Builder;
use Plack::App::File;
use Plack::Request;

use Radiomux::Proxy::HTTP;
use Radiomux::Proxy::ICE;
use Radiomux::Monitor;
use Radiomux::Station::WCBN;
use Radiomux::Station::WEMU;
use Radiomux::Station::WDET;
use Radiomux::Station::WUOM;

use JSON::XS;
use Text::Xslate qw{mark_raw};
use Encode;
use AnyEvent::Handle;

our $max = 1; # stream counter for unique id
our (%events, %streams);
our $monitor = Radiomux::Monitor->new;
our $template = Text::Xslate->new(path => "share/templates");

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
$monitor->start(5);

builder {
  enable "Plack::Middleware::Static", path => qr{^/assets/}, root => "./share/";

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
    if (defined $req->parameters->{station}) {
      my $station = $monitor->find_station($req->parameters->{station});
      if ($station) {
        return sub {
          my $respond = shift;
          my $class = "Radiomux::Proxy::" . $station->type;
          my $stream = $streams{$station->name} //= $class->new(station => $station);
          $stream->add_listener($env, $respond);
        };
      }
    }
    return [500, ["Content-Type" => "text/plain"], ["invalid station"]];
  };

  mount "/refresh", sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    if (defined $req->parameters->{station}) {
      my $station = $monitor->find_station($req->parameters->{station});
      $station->fetch;
    }
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
        on_error => sub { warn "error on $id"; delete $events{$id} },
      );

      $events{$id} = [$h, $writer, $env];
    };
  };
}
