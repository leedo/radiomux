use Plack::Builder;
use Plack::App::File;
use Plack::Request;
use Plack::App::Proxy;

use AnyEvent::Handle;

use Radiomux::Monitor;
use Radiomux::Station::WCBN;

use JSON::XS;
use Data::Dump qw{pp};
use Text::Xslate qw{mark_raw};
use Encode;

our $max = 1; # stream counter for unique id
our %streams;
our $monitor = Radiomux::Monitor->new;
our $template = Text::Xslate->new(path => "share/templates");
our $proxy = Plack::App::Proxy->new->to_app;

$monitor->subscribe(sub {
  my ($station, @plays) = @_;
  for my $h (map { $_->[0] } values %streams) {
    my $data = encode_json {
      station => $station->name,
      plays   => [map { $_->marshall } @plays],
    };
    $h->push_write("data: $data\n\n");
  }
});

$monitor->add_station(Radiomux::Station::WCBN->new);
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
        $env->{'plack.proxy.url'} = $station->stream;
        return $proxy->($env);
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
        on_error => sub { warn "error on $id"; delete $streams{$id} },
      );

      $streams{$id} = [$h, $writer, $env];
    };
  };
}
