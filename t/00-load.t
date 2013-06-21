#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( q(App::SharedLibraryDeps) );
}

diag( qq(Testing App::SharedLibraryDeps $App::SharedLibraryDeps::VERSION, )
    . qq(Perl $], $^X) );
