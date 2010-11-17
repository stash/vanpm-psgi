use warnings;
use strict;
use Plack::Builder;
use Plack::Request;
use JSON::XS;
use Template;
use DBI;
use DBD::SQLite;

sub dbh {
    my $dbh = DBI->connect('dbi:SQLite:dbname=debug.sqlite','','');
    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = 1;
    return $dbh;
}

my $tt2_config = { INCLUDE_PATH => 'tt2' };
my $tt2 = Template->new($tt2_config);

sub process_template {
    my ($template, $vars) = @_;
    my @output;
    $tt2->process($template,$vars,sub { push @output,@_ });
    return \@output;
}

my @H = ( 'Content-Type'=>'text/html' );

sub show_book {
    my ($book_id, $dbh, $code) = @_;
    $dbh ||= dbh();
    my $sth = $dbh->prepare(q{SELECT * FROM books WHERE book_id = ?});
    $sth->execute($book_id);
    my $book = $sth->fetchrow_hashref || {};
    return [200, \@H, process_template('book.html',{book => $book})];
}

builder {
    enable 'Debug', panels => [qw(
        Environment Response Memory Timer 
        ModuleVersions Parameters Session PerlConfig
    )];
    enable 'Debug::DBIProfile', profile => 2;
    enable 'Debug::DBITrace';
    # mount '/someotherapp' => $otherapp;
    sub {
        my $req = Plack::Request->new(shift);
        if ($req->method eq 'POST') {
            my $post = $req->body_parameters;
            my $dbh = dbh();
            my $sth = $dbh->prepare(q{INSERT INTO books (title,body) VALUES (?,?)});
            $sth->execute($post->{title}, $post->{body});
            my $book_id = $dbh->last_insert_id('','','','');
            show_book($book_id,$dbh);
        }
        elsif ($req->method eq 'GET') {
            if ($req->path =~ qr{^/books?/(\d+)$}) {
                show_book($1);
            }
            else {
                my $dbh = dbh();
                my $sth = $dbh->prepare(q{SELECT * FROM books});
                $sth->execute();
                my $all = $sth->fetchall_arrayref({}) || [];
                return [200, \@H,
                    process_template('books.html',{books => $all})];
            }
        }
        else {
            return [409, \@H, ['']];
        }
    };
}
