#!perl -T

use Test::More tests => 1;
use Test::ConsistentVersion;

BEGIN {
    use_ok( q(App::SharedLibraryDeps::Cache) );
}

diag( qq(Testing App::SharedLibraryDeps::Cache )
    qq($App::SharedLibraryDeps::Cache::VERSION,\n)
    . qq(Perl $], $^X) );
