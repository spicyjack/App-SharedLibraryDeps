#!perl -T

use Test::More tests => 1;
use Test::ConsistentVersion;

BEGIN {
    use_ok( q(App::SharedLibraryDeps::File) );
}

diag( qq(Testing App::SharedLibraryDeps::File )
    qq($App::SharedLibraryDeps::File::VERSION,\n)
    . qq(Perl $], $^X) );
