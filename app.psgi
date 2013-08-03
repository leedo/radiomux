use v5.16;
use warnings;

use Plack::Builder;
use Plack::App::File;
use Radiomux;

builder {
  enable "Plack::Middleware::Static", path => qr{^/assets/}, root => "./share/";

  my $recordings = Plack::App::File->new(root => "./recordings")->to_app;

  mount "/recordings" => sub {
    my $res = $recordings->(shift);
    Plack::Util::header_push($res->[1], "Content-Disposition", "attachment");
    $res;
  };

  mount "/", Radiomux::Web->new->to_app;
}
