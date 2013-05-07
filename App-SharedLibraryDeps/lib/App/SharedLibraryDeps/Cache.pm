package App::SharedLibraryDeps::Cache;

# system modules
use strict;
use 5.010;
use warnings;
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

=head2 exists_in_cache(file => $file)

See if a file exists in the cache object.  Returns C<0> if the file does not
exist, and C<1> if the file does exist.

=cut

sub exists_in_cache {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    die q(Cache->exists_in_cache: missing 'file' argument)
        unless (exists $args{file});
    my $filename = $self->normalize_filename(file => $args{file});
    $log->debug(q(Cache->exists_in_cache; filename: ) . $filename);
    if ( exists $_cache{$filename} ) {
        return 1;
    } else {
        return 0;
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

    die q|Missing 'filename' arg)| unless ( exists $args{filename} );
    my $file = App::SharedLibraryDeps::File->new(name => $args{filename});
    $log->debug("Cache->add: adding " . $file->name());

    if ( -r $file ) {
        # @file_dependencies can be checked to see if the file has already
        # been cached or not
        if ( ! $self->exists_in_cache(file => $file) ) {
            # file doesn't exist in the cache; create a file object, work out
            # it's dependencies, and add it to the cache
            my @file_dependencies = $self->_query_ld_so(file => $file);
            # FIXME
            # - make sure to resolve symlinks somewhere, and store them in the
            # file object
            # - store symlinks in the cache object, with a reference to the
            # original LibraryFile object
            foreach my $dependency ( @file_dependencies ) {
                if ( ! $self->exists_in_cache(file => $file) ) {
                    $self->add(file => $dependency->filename());
                } else {
                    warn $file->name() . " exists in cache";
                    # FIXME
                    # - add the dependency here to the object's list of
                    # dependencies
                }
            }
        }
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

Queries the local cache for C<$file>, and the file is not found, then queries
C</etc/ld.so.cache> via C<ldconfig --print-cache> for file C<$file>, and
caches it's dependencies as new L<App::SharedLibraryDeps::File> objects.

=end internal

=cut

sub _query_ld_so {
    my $self = shift;
    my %args = @_;

    warn "query_ld_so";
    die q|Missing file object (file => $file)| unless ( exists $args{file} );
    my $file = $args{file};
    my $cmd = q(/usr/bin/ldd ) . $file->name();
    my @dependencies = qx/$cmd/;
    say "Dependencies for " . $file->name() . " are:";
    print join(qq(\n), @dependencies);
    # FIXME
    # - stat /etc/ld.so.cache and warn if the date is older than say a week
    #   - add an option to the command line to supress the warning
}

=begin internal

=head2 _normalize_filename(file => $file)

=end internal

=cut

sub _normalize_filename {
    my $self = shift;
    my %args = @_;

    die q(Cache->exists_in_cache: missing 'file' argument)
        unless (exists $args{file});

    if ( ref($args{file}) !~ /SCALAR/ ) {
        return $args{file};
    } else {
        my $file_obj = $args{file};
        return $file_obj->filename();
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
