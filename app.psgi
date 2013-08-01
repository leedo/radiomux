use Plack::Builder;
use AnyEvent::Handle;
use Radiomux::Monitor;
use Radiomux::Station::WCBN;
use JSON::XS;
use Data::Dump qw{pp};

our $max = 1; # stream counter for unique id
our %streams;
our $monitor = Radiomux::Monitor->new;

$monitor->subscribe(sub {
  my ($station, @plays) = @_;
  for my $h (map { $_->[0] } values %streams) {
    my $data = encode_json {
      name  => $station->name,
      plays => [map { $_->marshall } @plays],
    };
    $h->push_write("data: $data\n\n");
  }
});

$monitor->add_station(Radiomux::Station::WCBN->new);
$monitor->start(15);

builder {
  mount "/", sub {
    my $env = shift;
    return [200, ["Content-Type" => "text/plain"], ["hi"]];
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
