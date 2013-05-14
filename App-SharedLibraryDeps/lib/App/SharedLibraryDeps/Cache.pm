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
    #my $file = App::SharedLibraryDeps::File->new(name => $args{filename});
    my $filename = $args{filename};
    $log->debug(q(Cache->add: adding ) . $filename);

    if ( ! $self->_get_from_cache(file => $filename) ) {
        # file doesn't exist in the cache; create a file object, work out
        # it's dependencies, and add it to the cache
        my @file_dependencies = $self->_query_ldd(file => $filename);
        $log->debug(q(Cache->add: _query_ldd returned )
            . scalar(@file_dependencies) . qq( dependencies for $filename));
        #$log->debug(join(":", @file_dependencies));
        # FIXME
        # - make sure to resolve symlinks somewhere, and store them in the
        # file object
        # - store symlinks in the cache object, with a reference to the
        # original LibraryFile object
        foreach my $dependency ( @file_dependencies ) {
            $log->debug(qq(Cache->add: Checking for $dependency in cache));
            if ( ! $self->_get_from_cache(file => $filename) ) {
                # FIXME $self->add doesn't return anything; how will the
                # cache be populated?
                $self->add(filename => $dependency);
            } else {
                $log->debug($dependency . q( exists in cache));
                # FIXME
                # - add the dependency here to the object's list of
                # dependencies
            }
        }
    } else {
        $log->debug($filename . q( exists in cache));
    }
}

=head2 get_dependencies(filename => $file, [sort => $sort, return_format => $type])

Return a list of files for the filename given as C<$file> (required), ordered
by C<$sort> (optional), with a return format of C<$type> (optional).  C<$sort>
can be one of the following:

=over

=item time_asc

The time the file object was created by the C<Cache> object, ascending.

=item time_desc

The time the file object was created by the C<Cache> object, descending.

=item alpha

Alphabetical by filename and file path

=back

The default sort is C<time_asc>.  Return format can be one of the following:

=over

=item objects

An array of L<App::SharedLibraryDeps::File> objects, each object representing
a shared library dependency.

=item filelist

A text-based list of files in the same format that the Linux kernel utility
C<gen_init_cpio> uses as input to determine which files to add to an
I<initramfs> image.

=back

=cut

sub get_dependencies {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    # sort and return_type are optional
    die q|Missing filename (filename => $file)|
        unless ( exists $args{filename} );

    my $filename = $args{file};
    my $sort_order = $args{sort};
    my $return_type = $args{return_type};

    if ( ! defined $filename ) {
        $log->warn(q|Cache->dependencies; 'filename' argument undefined|);
        return ();
    }
    if ( -r $filename ) {
        $log->debug(q(Cache->dependencies: ) . $filename . q( is readable));
        # @file_dependencies can be checked to see if the file has already
        # been cached or not
        my @dependencies;
        if ( ! $self->_get_from_cache(file => $filename) ) {
            $self->add(file => $filename);
        }
    } elsif ( $filename =~ /linux-[gate|vdso].*/ ) {
        $log->debug(q(Cache->dependencies: )
            . $filename . q( is a virtual file));
        if ( ! $self->_get_from_cache(file => $filename) ) {
            $self->add(file => $filename);
        }
    } else {
        $log->warn("Cache->dependencies: " . $filename . " is *not* readable");
    }
}

=begin internal

=head2 _query_ldd(file => $file)

Queries the local cache for C<$file>, and if the file is not found in the
local cache, queries C<ldd> for file C<$file>, and caches it's dependencies as
new L<App::SharedLibraryDeps::File> objects.

=cut

sub _query_ldd {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    die q|Missing file object (file => $file)| unless ( exists $args{file} );
    my $file = $args{file};
    my $cmd = q(/usr/bin/ldd ) . $file;
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
        my $virtual_lib = 0;
        if ( $library =~ /([\/a-zA-Z0-9\-\+_].*) => (\/.*) \((0x.*)\)/ ) {
            $libfile = $2;
            $load_address = $3;
            $log->debug(qq(Cache->_query_ldd: adding 3-arg '$library')
                . qq( to return list as $libfile));
        } elsif ( $library =~ /([\/a-zA-Z0-9\-\+_].*) =>  \((0x.*)\)/ ) {
            $log->debug(qq(Cache->_query_ldd: adding 2-arg '$library')
                . qq( to return list as $1));
            $libfile = $1;
            if ( $libfile =~ /linux-vdso|linux-gate/ ) {
                $virtual_lib = 1;
            }
            $load_address = $2;
        } elsif ( $library =~ /([\/a-zA-Z0-9\-\+_].*) \((0x.*)\)/ ) {
            $log->debug(qq(Cache->_query_ldd: adding simple arg '$library')
                . q( to return list as ) . $1);
            $libfile = $1;
            $load_address = $2;
        } elsif ( $library =~ /statically linked/ ) {
            $log->debug(qq(Cache->_query_ldd: adding static lib '$library')
                . q( to return list as ) . $1);
            $libfile = $1;
            $static_lib = 1;
        } else {
            $log->logdie(qq(Can't determine dependency info for $library));
        }
        my $file = $self->_get_from_cache(file => $libfile);
        if ( defined $file ) {
            $log->info(q(Adding ) . $file->name() . q( to dependencies));
            push(@dependencies, $2);
        } else {
            if ( defined $load_address ) {
                $file = App::SharedLibraryDeps::File->new(
                    name            => $libfile,
                    static_lib      => $static_lib,
                    load_address    => $load_address,
                    virtual_lib     => $virtual_lib,
                );
            } else {
                $file = App::SharedLibraryDeps::File->new(
                    name            => $libfile,
                    static_lib      => $static_lib,
                    virtual_lib     => $virtual_lib,
                );
            }
            $log->info(q(Adding ) . $file->name()
                . q( to cache and dependencies));
            $self->_add_to_cache(file => $file);
            push( @dependencies, $file->name() );
        }
    }
    return @dependencies;
}

=head2 _normalize_filename(file => $file)

Return either the filename attribute of an object, or return the scalar passed
in as C<$file> if C<$file> is not an object.

=cut

sub _normalize_filename {
    my $self = shift;
    my %args = @_;

    die q(Cache->_normalize_filename: missing 'file' argument)
        unless (exists $args{file});

    if ( ref($args{file}) ) {
        my $file_obj = $args{file};
        return $file_obj->name();
    } else {
        return $args{file};
    }
}

=head2 _add_to_cache(file => $file)

Adds the file object passed in as C<$file> to the cache.

=cut

sub _add_to_cache {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    die q(Cache->_get_from_cache: missing 'file' argument)
        unless (exists $args{file});
    #my $filename = $self->_normalize_filename(file => $args{file});
    my $file = $args{file};
    die q(Cache->_add_to_cache: file to add to Cache is not a File object)
        unless (ref($file));
    $log->debug(q(Cache->_add_to_cache; filename: ) . $file->name());
    if ( exists $_cache{$file->name()} ) {
        $log->warn(qq(Cache->_add_to_cache; already exists in cache!));
        return undef;
    } else {
        $log->debug(q(Cache->_add_to_cache; added file));
        $_cache{$file->name()} = $file;
        return 1;
    }
}

=head2 _get_from_cache(file => $file)

Checks the cache for a file object with the name of C<$file->name()>, and
returns that object if it exists in the cache, and returns C<undef> if the
file does not exist in the cache.

=end internal

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
        $log->debug(q(Cache->_get_from_cache; file exists));
        $_cache{$filename}
    } else {
        $log->debug(q(Cache->_get_from_cache; file doesn't exist));
        return undef;
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
