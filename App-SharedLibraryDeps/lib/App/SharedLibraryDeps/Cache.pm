package App::SharedLibraryDeps::Cache;

# system modules
use strict;
use 5.010;
use warnings;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Moo;

# local modules
use App::SharedLibraryDeps::File;

# for storing file objects once they've been queried via ld.so
my %_cache;

=head1 NAME

App::SharedLibraryDeps::Cache - A cache of L<App::SharedLibraryDeps::File>
objects.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    my $filename = q(/path/to/a/binary/or/library);
    use App::SharedLibraryDeps::Cache;
    my $file = App::SharedLibraryDeps::File->new(filename => $filename);
    my @deps = $file->get_shared_library_dependencies();
    my $cache = App::SharedLibraryDeps::Cache->new();
    $cache->add(file => $file);
    ...

=head1 OBJECT ATTRIBUTES

=over

=item attribute1

This is some text about attribute #1.

=back

=head1 OBJECT METHODS

=head2 _get_from_cache(file => $file)

Checks the cache for a file object with the name of C<$file->name()>, and
returns that object if it exists in the cache, and returns C<undef> if the
file does not exist in the cache.

=cut

sub _get_from_cache {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    die q(Cache->_get_from_cache: missing 'file' argument)
        unless (exists $args{file});
    my $filename = $self->_normalize_filename(file => $args{file});
    $log->debug(q(Cache->_get_from_cache; filename: ) . $filename);
    if ( exists $_cache{$filename} ) {
        $_cache{$filename}
    } else {
        return undef;
    }
}

=head2 add(file => $file)

Add a file to the cache.  The process of adding a file will cause the Cache
manager to recursively query C<ld.so> for that file's dependencies; in other
words, the Cache manager will know the dependencies of the original file, plus
all of the files that were queried as part of the original file's
dependencies.

=cut

sub add {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    die q|Missing 'filename' arg| unless ( exists $args{filename} );
    my $file = App::SharedLibraryDeps::File->new(name => $args{filename});
    $log->debug(q(Cache->add: adding ) . $file->name());

    if ( -r $file->name() ) {
        $log->debug(q(Cache->add: ) . $file->name() . q( is readable));
        # @file_dependencies can be checked to see if the file has already
        # been cached or not
        if ( ! $self->_get_from_cache(file => $file) ) {
            # file doesn't exist in the cache; create a file object, work out
            # it's dependencies, and add it to the cache
            my @file_dependencies = $self->_query_ld_so(file => $file);
            $log->debug(q(Cache->add: _query_ld_so returned )
                . scalar(@file_dependencies) . q( dependencies));
            #$log->debug(join(":", @file_dependencies));
            # FIXME
            # - make sure to resolve symlinks somewhere, and store them in the
            # file object
            # - store symlinks in the cache object, with a reference to the
            # original LibraryFile object
            foreach my $dependency ( @file_dependencies ) {
                $log->debug(qq(Cache->add: Checking for $dependency in cache));
                if ( ! $self->_get_from_cache(file => $file) ) {
                    $self->add(filename => $dependency);
                } else {
                    $log->debug($dependency . q( exists in cache));
                    # FIXME
                    # - add the dependency here to the object's list of
                    # dependencies
                }
            }
        } else {
            $log->debug($file->name() . q( exists in cache));
        }
    } else {
        $log->warn("Cache->add: " . $file->name() . " is *not* readable");
    }
}

=head2 dependencies_for_file(file => $file, order_by => $sort_order)

Return a list of L<App::SharedLibraryDeps::File> objects for the filename
given as C<$file>, ordered by C<$sort_order>.  C<$sort_order> can be one of
the following:

=over

=item time_asc

The time the file object was created by the C<Cache> object, ascending.

=item time_desc

The time the file object was created by the C<Cache> object, descending.

=item alpha

Alphabetical by filename and file path

=back

The default sort is C<time_asc>.

=begin internal

=head2 _query_ld_so(file => $file)

Queries the local cache for C<$file>, and if the file is not found in the
local cache, queries C<ldd> for file C<$file>, and caches it's dependencies as
new L<App::SharedLibraryDeps::File> objects.

=end internal

=cut

sub _query_ld_so {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    die q|Missing file object (file => $file)| unless ( exists $args{file} );
    my $file = $args{file};
    my $cmd = q(/usr/bin/ldd ) . $file->name();
    my @ldd_output = qx/$cmd/;
    my @dependencies;
    chomp(@ldd_output);
    #say "Dependencies for " . $file->name() . " are:";
    #print join(qq(\n), @ldd_output);
    # FIXME split the output of ldd here, create new File objects for each
    # dependency, return the File objects to the caller
    foreach my $library ( @ldd_output ) {
        $library =~ s/^\s+//g;
        my ($load_address, $libfile);
        my $static_lib = 0;
        # FIXME handle linux-vdso/linux-gate here
        if ( $library =~ /([\/a-zA-Z0-9].*) => (\/.*) \((0x.*)\)/ ) {
            $libfile = $2;
            $load_address = $3;
            $log->debug(qq(Cache->_query_ld_so: adding 3-arg '$library')
                . qq( to return list as $libfile));
        } elsif ( $library =~ /([\/a-zA-Z0-9].*) =>  \((0x.*)\)/ ) {
            $log->debug(qq(Cache->_query_ld_so: adding 2-arg '$library')
                . qq( to return list as $1));
            $libfile = $1;
            $load_address = $2;
        } elsif ( $library =~ /([\/a-zA-Z0-9]) \((0x.*)\)/ ) {
            $log->debug(qq(Cache->_query_ld_so: adding simple arg '$library')
                . q( to return list as ) . $file->name());
            $libfile = $file->name();
            $load_address = $2;
        } elsif ( $library =~ /statically linked/ ) {
            $log->debug(qq(Cache->_query_ld_so: adding static lib '$library')
                . q( to return list as ) . $file->name());
            $libfile = $file->name();
            $static_lib = 1;
        } else {
            $log->logdie(qq(Can't determine dependency info for $library));
        }
        my $file = $self->_get_from_cache(file => $libfile);
        if ( defined $file ) {
            push(@dependencies, $2);
        } else {
            if ( defined $load_address ) {
                $file = App::SharedLibraryDeps::File->new(
                    name            => $libfile,
                    static_lib      => $static_lib,
                    load_address    => $load_address,
                );
            } else {
                $file = App::SharedLibraryDeps::File->new(
                    name            => $libfile,
                    static_lib      => $static_lib,
                );
            }
            $self->_add_to_cache(file => $file);
        }
    }
    return @dependencies;
}

=begin internal

=head2 _normalize_filename(file => $file)

=end internal

=cut

sub _normalize_filename {
    my $self = shift;
    my %args = @_;

    die q(Cache->_normalize_filename: missing 'file' argument)
        unless (exists $args{file});

    if ( ref($args{file}) =~ /SCALAR/ ) {
        return $args{file};
    } else {
        my $file_obj = $args{file};
        return $file_obj->name();
    }
}

=head1 AUTHOR

Brian Manning, C<< <xaoc at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
L<https://github.com/spicyjack/App-SharedLibraryDeps/issues>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::SharedLibraryDeps::Cache

You can also look for information at:

=over 4

=item * Project GitHub repo: acker

L<https://github.com/spicyjack/App-SharedLibraryDeps>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2013 Brian Manning, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of App::SharedLibraryDeps::Cache
