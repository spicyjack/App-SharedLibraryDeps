#!perl -T

use Test::More tests => 8;
#use Test::More;
use Test::File;

BEGIN {
    ## TEST
    use_ok(q(File::Basename)); # used to find log4perl config file
    use_ok(q(Log::Log4perl), qw(:easy :no_extra_logdie_message));
    use_ok(q(App::SharedLibraryDeps::Cache));
}

diag( qq(Testing App::SharedLibraryDeps::Cache )
    .  qq($App::SharedLibraryDeps::Cache::VERSION,\n)
    . qq(Perl $], $^X) );

my $dirname = dirname($0);
## TEST
file_exists_ok(qq($dirname/tests.log4perl.cfg),
    q(log4perl config file exists for testing));
Log::Log4perl->init_once(qq($dirname/tests.log4perl.cfg));
my $log = Log::Log4perl->get_logger();
## TEST
isa_ok($log, q(Log::Log4perl::Logger));

my $cache = App::SharedLibraryDeps::Cache->new();
## TEST
isa_ok($cache, q(App::SharedLibraryDeps::Cache));

# test $cache->dependencies
my @test = $cache->get_deps(filename => undef);
ok(scalar(@test) == 0, q(get_deps with 'undef' for filename returns )
    . q(empty list));

# mount is a good candidate for testing; we just want to see if get_deps
# returns a non-zero value, not an exact number
@test = $cache->get_deps(filename => q(/bin/mount));
ok(scalar(@test) > 0, q(get_deps with '/bin/mount' returned )
    . scalar(@test) . q( dependencies));

done_testing();
