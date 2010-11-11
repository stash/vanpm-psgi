use warnings;
use strict;
use Plack::Builder;
use Plack::App::File;
my $proc_req = 0;
my $my_app = sub {
    return [
        200,['Content-Type'=>'text/html'],
        ['<html><head><title>ohai</title></head><body>o hai ',$proc_req++,'</body></html>']
    ];
};
builder {
    enable "Debug", panels => [qw(Memory)];
    mount "/static" => Plack::App::File->new(root=>'htdocs/');
    mount "/favicon.ico" => sub { [200,[],['']] };
    mount "/" => $my_app;
};
