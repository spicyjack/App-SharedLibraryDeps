#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'App::SharedLibraryDeps' );
}

diag( "Testing App::SharedLibraryDeps $App::SharedLibraryDeps::VERSION, Perl $], $^X" );
