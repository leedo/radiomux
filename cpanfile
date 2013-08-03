requires 'git://github.com/stevan/p5-mop-redux.git';
requires 'Plack';
requires 'AnyEvent';
requires 'AnyEvent::HTTP';
requires 'AnyEvent::Redis';
requires 'DateTime';
requires 'IO::AIO';
requires 'AnyEvent::AIO';
requires 'List::MoreUtils';
requires 'Web::Scraper';
requires 'HTML::TreeBuilder::LibXML'; # for fast scraper
requires 'Data::UUID';
requires 'Text::Xslate';
requires 'JSON::XS';
requires 'Encode';
requires 'Digest::SHA1';
requires 'Twiggy';
requires 'EV';

on 'test' => sub {
	requires 'Test::More';
	requires 'Test::Fatal';
}
