#!/usr/bin/perl -w

# Copyright (c) 2013 by Brian Manning <brian at xaoc dot org>

# For support with this file, please file an issue on the GitHub issue tracker
# for this project: https://github.com/spicyjack/public/issues

=head1 NAME

B<shared_lib_deps.pl> - Determine the shared library dependencies for a given
set of files.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

 perl shared_lib_deps.pl [OPTIONS]

 Script options:
 -d|--debug         Debug script execution; super noisy output
 -v|--verbose       Verbose script execution
 -h|--help          Shows this help text
 -c|--colorize      Always colorize log output (not filelist output)

 Other script options:
 -f|--file          Discover dependencies for these files
 -o|--output        Output dependencies as a filelist (for 'gen_init_cpio')

 Example usage:

 # list the structure of an XLS file
 shared_lib_deps.pl --file /path/to/file1 --file=/path/to/file2

You can view the full C<POD> documentation of this file by calling C<perldoc
shared_lib_deps.pl>.

=cut

our @options = (
    # script options
    q(debug|d),
    q(verbose|v),
    q(help|h),
    q(colorize|c),
    # other options
    q(file|f=s@),
    q(output|o=s),
    # FIXME
    # - type of output
    #   - plain formatted list
    #   - kernel 'gen_init_cpio' filelist
    #   - combination (report)
);

=head1 DESCRIPTION

B<shared_lib_deps.pl> - Determine the shared library dependencies for a given
set of files.

=head1 OBJECTS

=head2 App::SharedLibraryDeps::Config

An object used for storing configuration data.

=head3 Object Methods

=cut

#############################
# App::SharedLibraryDeps::Config #
#############################
package App::SharedLibraryDeps::Config;
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use POSIX qw(strftime);

=over

=item new( )

Creates the L<App::SharedLibraryDeps::Config> object, and parses out options
using L<Getopt::Long>.

=cut

sub new {
    my $class = shift;

    my $self = bless ({}, $class);

    # script arguments
    my %args;

    # parse the command line arguments (if any)
    my $parser = Getopt::Long::Parser->new();

    # pass in a reference to the args hash as the first argument
    $parser->getoptions( \%args, @options );

    # assign the args hash to this object so it can be reused later on
    $self->{_args} = \%args;

    # dump and bail if we get called with --help
    if ( $self->get(q(help)) ) { pod2usage(-exitstatus => 1); }

    # return this object to the caller
    return $self;
} # sub new

=item get($key)

Returns the scalar value of the key passed in as C<key>, or C<undef> if the
key does not exist in the L<App::SharedLibraryDeps::Config> object.

=cut

sub get {
    my $self = shift;
    my $key = shift;

    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    if ( exists $args{$key} ) {
        return $args{$key};
    } else {
        return undef;
    }
} # sub get

=item set( key => $value )

Sets in the L<App::SharedLibraryDeps::Config> object the key/value pair passed
in as arguments.  Returns the old value if the key already existed in the
L<App::SharedLibraryDeps::Config> object, or C<undef> otherwise.

=cut

sub set {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    if ( exists $args{$key} ) {
        my $oldvalue = $args{$key};
        $args{$key} = $value;
        $self->{_args} = \%args;
        return $oldvalue;
    } else {
        $args{$key} = $value;
        $self->{_args} = \%args;
    } # if ( exists $args{$key} )
    return undef;
} # sub get

=item defined($key)

Returns "true" (C<1>) if the value for the key passed in as C<key> is
C<defined>, and "false" (C<0>) if the value is undefined, or the key doesn't
exist.

=cut

sub defined {
    my $self = shift;
    my $key = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    # Can't use Log4perl here, since it hasn't been set up yet
    if ( exists $args{$key} ) {
        #warn qq(exists: $key\n);
        if ( defined $args{$key} ) {
            #warn qq(defined: $key; ) . $args{$key} . qq(\n);
            return 1;
        }
    }
    return 0;
}


=item get_args( )

Returns a hash containing the parsed script arguments.

=cut

sub get_args {
    my $self = shift;
    # hash-ify the return arguments
    return %{$self->{_args}};
} # get_args

################
# package main #
################
package main;
use 5.010;
use strict;
use warnings;

# Perl core modules
use Carp;
use File::Basename;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Log::Log4perl::Level;
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;


# Project modules
use App::SharedLibraryDeps::Cache;

    my $script_start_time = [gettimeofday];
    our $my_name = basename $0;

    my $config = App::SharedLibraryDeps::Config->new();
    my $cache = App::SharedLibraryDeps::Cache->new();
    # create a logger object
    my $log_conf;
    if ( $config->defined(q(debug)) ) {
        $log_conf = qq(log4perl.rootLogger = DEBUG, Screen\n);
    } elsif ( $config->defined(q(verbose)) ) {
        $log_conf = qq(log4perl.rootLogger = INFO, Screen\n);
    } else {
        $log_conf = qq(log4perl.rootLogger = WARN, Screen\n);
    }
    if ( -t STDOUT || $config->defined(q(colorize)) ) {
        $log_conf .= qq(log4perl.appender.Screen = )
            . qq(Log::Log4perl::Appender::ScreenColoredLevels\n);
    } else {
        $log_conf .= qq(log4perl.appender.Screen = )
            . qq(Log::Log4perl::Appender::Screen\n);
    }

    #. q(log4perl.appender.Screen.layout.ConversionPattern = %d %p %m%n)
    $log_conf .= qq(log4perl.appender.Screen.stderr = 1\n)
        . qq(log4perl.appender.Screen.utf8 = 1\n)
        . qq(log4perl.appender.Screen.layout = PatternLayout\n)
        . q(log4perl.appender.Screen.layout.ConversionPattern )
        . qq|= [%8r] %p{1} %4L (%M{1}) %m%n\n|;
        # old log prefix
        #. qq|= %d{HH.mm.ss} %p %F{1}:%L (%M{1}) %m%n\n|;
    # create a logger object, and prime the logfile for this session
    Log::Log4perl::init( \$log_conf );
    my $log = get_logger("");

    if ( ! $config->defined(q(file)) ) {
        $log->fatal(q|Use '--file' argument(s) to discover file dependencies|);
        $log->logdie(qq|'$my_name --help' to see script usage and options|);
    }

    # print a nice banner
    $log->info(qq($my_name: Starting... version $VERSION));
    $log->info(qq($my_name: My PID is $$));
    # need to call Log::Log4perl::Level::to_level to convert the log level
    # integer constant to "human readable"
    $log->info(qq($my_name: Current log level is )
        . Log::Log4perl::Level::to_level($log->level()) );

    my @dependencies;
    foreach my $filename ( @{$config->get(q(file))} ) {
        $log->debug(qq(Adding file $filename));
        @dependencies = $cache->get_deps(filename => $filename);
        say qq(Dependencies for $filename: );
        # Use map to enumerate over all of the dependency objects, call the
        # filename() method on each one, and dump the output into a new array
        # that can be sorted nicely
        my @dep_filenames = map($_->filename, @dependencies);
        foreach my $dep ( sort(@dep_filenames) ) {
            say qq(- $dep);
        }

        if ( $log->is_info ) {
            use Data::Dumper;
            $Data::Dumper::Indent = 1;
            $Data::Dumper::Sortkeys = 1;
            $Data::Dumper::Terse = 1;
            foreach my $cache_file ( sort($cache->get_all_cached_files()) ) {
                $log->info(q(Dumping ) . $cache_file->get_deps_count()
                    . q( deps for: ) . $cache_file->filename);
                foreach my $dep ($cache_file->get_deps()) {
                    $log->info( q( - ) . $dep );
                }
                $log->info(q(Dumping ) . $cache_file->get_reverse_deps_count()
                    . q( reverse deps for: ) . $cache_file->filename);
                foreach my $rev_dep ( $cache_file->get_reverse_deps() ) {
                    $log->info( q( - ) . $rev_dep );
                }
            }
        }
    }
    $log->info(qq($my_name: Parsed dependencies for )
        . scalar(@{$config->get(q(file))}) . q( files));
    $log->info(qq($my_name: in ) . sprintf(q(%0.1f),
        tv_interval($script_start_time, [gettimeofday])) . q( seconds));

=cut

=back

=head1 AUTHOR

Brian Manning, C<< <brian at xaoc dot org> >>

=head1 BUGS

Please report any bugs or feature requests to the GitHub issue tracker for
this project:

C<< <https://github.com/spicyjack/public/issues> >>.

=head1 SUPPORT

You can find documentation for this script with the perldoc command.

    perldoc shared_lib_deps.pl

=head1 COPYRIGHT & LICENSE

Copyright (c) 2013 Brian Manning, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# fin!
# vim: set shiftwidth=4 tabstop=4
