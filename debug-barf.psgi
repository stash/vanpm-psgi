use warnings;
use strict;
use Plack::Builder;
use Plack::Request;
use JSON::XS;
use Template;

sub dbh {
    my $dbh = DBI->connect('dbi:SQLite:dbname=debug.sqlite','','');
    $dbh->{AutoCommit} = 1;
    return $dbh;
}

my $tt2_config = {
    INCLUDE_PATH => 'tt2',
};
my $tt2 = Template->new($tt2_config);

sub process_template {
    my ($template, $vars) = @_;
    my $output = '';
    $tt2->process($template,$vars,\$output);
    return [$output];
}

my @H = ( 'Content-Type'=>'text/html' );

sub show_book {
    my ($book_id, $dbh, $code) = @_;
    $dbh ||= dbh();
    my $sth = $dbh->do(q{SELECT * FROM books WHERE book_id = ?},$1);
    my $book = $sth->fetchrow_hashref || {};
    return [200, \@H, process_template('book.html',$book)];
}

builder {
    enable 'Debug', panels => [ qw(DBITrace Memory Timer) ];
    mount '/' => sub {
        my $req = Plack::Request->new(shift);
        if ($req->method eq 'POST') {
            my $post = $req->body_parameters;
            my $dbh = dbh();
            $dbh->do(q{INSERT INTO books (title,body) VALUES (?,?)}, $post->{title}, $post->{body});
            my $book_id = $dbh->sqlite_last_insert_rowid();
            show_book($1,$dbh);
        }
        elsif ($req->method eq 'GET') {
            if ($req->path =~ qr{^/book/(\d+)$}) {
                show_book($1);
            }
            else {
                my $dbh = dbh();
                my $sth = $dbh->do(q{SELECT * FROM books});
                my $all = $sth->fetchall_arrayref({});
                # TODO: some template
            }
        }
        else {
            return [409, ['Content-Type'=>'text/html'], ['<html><body><h1>Method not supported.</h1></body></html>']];
        }
    };
}
