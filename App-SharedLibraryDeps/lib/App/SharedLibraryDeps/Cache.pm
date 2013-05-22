package App::SharedLibraryDeps::Cache;

# system modules
use strict;
use 5.010;
use warnings;
use Carp qw(cluck);
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;
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

=head2 sort_order

The sort order for sorting files that are returned to the caller as the list
of dependencies.  Sort order can be one of the following:

=over

=item time_asc

The time the file object was created by the C<Cache> object, ascending.

=item time_desc

The time the file object was created by the C<Cache> object, descending.

=item alpha

Alphabetical by filename and file path

=back

The default sort is C<time_asc>.

=cut

has sort_order => (
    is          => q(ro),
    isa         => sub { $_[0] =~ // },
);

=head1 OBJECT METHODS

=head2 get_dependencies(filename => $file, [sort => $sort, return_format => $type])

Return a list of files for the filename given as C<$file> (required), ordered
by C<$sort> (optional), with a return format of C<$type> (optional).  C<$sort>
is documented above for the C<sort_order> attribute.  Return format can be one
of the following:

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

    my $filename = $args{filename};
    my $sort_order = $args{sort};
    my $return_type = $args{return_type};
    my @dependencies;

    if ( ! defined $filename ) {
        $log->warn(q|Cache->dependencies; 'filename' argument undefined|);
        return ();
    }
    if ( -r $filename ) {
        $log->debug(q(Cache->dependencies: ) . $filename . q( is readable));
        # @file_dependencies can be checked to see if the file has already
        # been cached or not
        my $file = App::SharedLibraryDeps::File->new(
            filename    => $filename,
            virtual_lib => 0,
            static_lib  => 0,
        );
        push(@dependencies, $self->query_file(file => $file));
    } elsif ( $filename =~ /linux-[gate|vdso].*/ ) {
        $log->debug(qq(Cache->dependencies: $filename is a virtual file));
        my $file = App::SharedLibraryDeps::File->new(
            filename    => $filename,
            virtual_lib => 1,
        );
        push(@dependencies, $self->query_file(file => $file));
    } else {
        $log->warn("Cache->dependencies: " . $filename . " is *not* readable");
    }
    return @dependencies;
}

=head2 query_file(filename => $filename)

Query the cache for filename C<$filename>.  The process of querying for a file
will cause the Cache manager to recursively query using the C<ldd> command for
that file's dependencies; in other words, the Cache manager will know the
dependencies of the original file, plus all of the files that were queried as
part of the original file's dependencies.

Accepts a filename as C<$filename>, returns ???

=cut

sub query_file {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    die q|Missing 'file' object arg| unless ( exists $args{file} );
    my $file = $args{file};
    my @return_deps;
    $log->debug(q(Cache->query_file: entering with file ) . $file->filename());
    if ( ! $self->_get_from_cache(filename => $file->filename()) ) {
        # file doesn't exist in the cache; create a file object, work out
        # it's dependencies, and add it to the cache
        my @file_dependencies = $self->_query_ldd(file => $file);
        $log->debug(q(Cache->query_file: _query_ldd returned )
            . scalar(@file_dependencies) . qq( dependencies for )
            . $file->filename() );
        #$log->debug(join(":", @file_dependencies));
        # FIXME
        #$log->warn(q(Dumping cache));
        #warn Dumper {%_cache};
        # - make sure to resolve symlinks somewhere, and store them in the
        # file object
        # - store symlinks in the cache object, with a reference to the
        # original LibraryFile object
        foreach my $depfile ( @file_dependencies ) {
            $log->debug(qq(Cache->query_file: Checking for )
                . $depfile . q(in cache));
            if ( ! $self->_get_from_cache(filename => $depfile) ) {
                push(@return_deps, $self->query_file(file => $depfile));
            } else {
                $log->debug(qq(Cache->query_file: ) . $depfile
                    . q( exists in cache));
                push(@return_deps, $depfile);
            }
        }
    } else {
        $log->debug($file->filename() . q( exists in cache));
    }
    $log->info(qq(Cache->query_file: returning; ) . $file->filename()
        . q( has ) . scalar(@return_deps) . q( dependencies));
    $log->debug(qq(Cache->query_file: dependencies for ) . $file->filename());
    foreach my $dep ( sort(@return_deps) ) {
        $log->debug(qq( - ) . $dep->filename() );
    }
    return @return_deps;
}

=begin internal

=head2 _query_ldd(filename => $filename)

Queries the local cache for C<$filename>, and if the file is not found in the
local cache, queries C<ldd> for file C<$filename>, and caches it's
dependencies as new L<App::SharedLibraryDeps::File> objects.

Returns a list of filenames that make up the dependencies for the given
C<$filename>.

=cut

sub _query_ldd {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    die q|Missing file object argument (file => $file)|
        unless ( exists $args{file} );
    my $file = $args{file};
    my $cmd = q(/usr/bin/ldd ) . $file->filename();
    my @ldd_output = qx/$cmd/;
    my @dependencies;
    chomp(@ldd_output);
    if ( $log->is_debug() ) {
        $log->debug(qq(Dependencies for ) . $file->filename() . q( are:));
        foreach my $line ( @ldd_output ) {
            $line =~ s/^\s+//g;
            $log->debug(qq(  - $line));
        }
    }
    # Split the output of ldd here, create new File objects for each
    # dependency, return the File objects to the caller
    LDD_LINE: foreach my $ldd_line ( @ldd_output ) {
        # get rid of multiple spaces *at the beginning* of the line
        $ldd_line =~ s/^\s+//g;
        my ($load_address, $libname, $libfile);
        my $static_lib = 0;
        my $virtual_lib = 0;
        if ( $ldd_line =~ /^([\/a-zA-Z0-9\-\+_].*) =>  \((0x.*)\)/ ) {
            $libname = $1;
            $load_address = $2;
            if ( $libname =~ /linux-vdso|linux-gate/ ) {
                my $virtual_file = App::SharedLibraryDeps::File->new(
                    libname         => $libname,
                    filename        => $libname,
                    static_lib      => 0,
                    virtual_lib     => 1,
                    load_address    => $load_address,
                );
                $log->debug(qq(Cache->_query_ldd: adding virtual file )
                    . qq('$libname' to return list));
                push(@dependencies, $libname);
                $self->_add_to_cache(file => $virtual_file);
                next LDD_LINE;
            } else {
                $log->debug(qq(Cache->_query_ldd: adding 2-arg '$ldd_line')
                    . qq( to return list as filename $libfile));
            }
        } elsif ( $ldd_line =~ /^statically linked/ ) {
            my $static_file = App::SharedLibraryDeps::File->new(
                libname         => $file->filename(),
                filename        => $file->filename(),
                static_lib      => 1,
                virtual_lib     => 0,
            );
            $log->debug(qq(Cache->_query_ldd: adding static lib ')
                . $file->filename() . q(' to return list));
            # do not push anything on dependencies for a statically linked
            # file; it has no dependencies by design
            #push(@dependencies, $file);
            $self->_add_to_cache(file => $static_file);
            next LDD_LINE;
        } elsif ( $ldd_line
                =~ /^([\/a-zA-Z0-9\-\+_].*) => (\/.*) \((0x.*)\)/ ) {
            $libname = $1;
            $libfile = $2;
            $load_address = $3;
            $log->debug(qq(Cache->_query_ldd: adding 3-arg '$ldd_line')
                . qq( to return list as filename $libfile));
        } elsif ( $ldd_line =~ /^([\/a-zA-Z0-9\-\+_].*) \((0x.*)\)/ ) {
            $libname = $1;
            $libfile = $libname;
            $load_address = $2;
            $log->debug(qq(Cache->_query_ldd: adding simple 2 arg '$ldd_line')
                . q( to return list as ) . $1);
        } else {
            $log->logdie(q(Cache->_query_ldd: )
                . qq(Can't determine dependency info for $ldd_line));
        }

        # this will retrieve the file object from the cache, if the file
        # object has already been added to the cache
        $log->debug(qq(Cache->_query_ldd: Checking for $libfile in cache));
        my $cache_file = $self->_get_from_cache(filename => $libfile);
        if ( defined $cache_file ) {
            $log->info(qq(Cache->_query_ldd: Adding ) . $cache_file->filename()
                . qq( to dependencies for ) . $file->filename());
            push(@dependencies, $cache_file->filename());
        } else {
            #if ( ! $virtual_lib ) {
            #    $log->info(qq(Cache->_query_ldd: recursing with $libfile));
            #    $self->query_file(file => $libfile);
            #}
            my $file_obj;
            if ( defined $load_address ) {
                $file_obj = App::SharedLibraryDeps::File->new(
                    libname         => $libname,
                    filename        => $libfile,
                    static_lib      => $static_lib,
                    load_address    => $load_address,
                    virtual_lib     => $virtual_lib,
                );
            } else {
                $file_obj = App::SharedLibraryDeps::File->new(
                    libname         => $libname,
                    filename        => $libfile,
                    static_lib      => $static_lib,
                    virtual_lib     => $virtual_lib,
                );
            }
            $log->info(q(Cache->_query_ldd: Adding ) . $file_obj->libname()
                . q( to cache and dependencies));
            $self->_add_to_cache(file => $file_obj);
            push(@dependencies, $file_obj);
            # FIXME verify this will work
            #$file_obj->deps($file->filename());
        }
    }
    $log->info(qq(Cache->_query_ldd: returning; ) . $file->filename()
        . q( has ) . scalar(@dependencies) . q( dependencies));
    $log->debug(qq(Cache->_query_ldd: dependencies for ) . $file->filename());
    foreach my $dep ( sort(@dependencies) ) {
        $log->debug(qq( - $dep));
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
    my $log = get_logger("");

    die q(Cache->_normalize_filename: missing 'file' argument)
        unless (exists $args{file});

    #cluck(q(_normalize_filename: entering method));
    #warn Dumper {%args};
    if ( ref($args{file}) ) {
        my $file_obj = $args{file};
        $log->debug(q(Cache->_normalize_filename: object: )
            . $file_obj->filename());
        return $file_obj->filename();
    } else {
        $log->debug(q(Cache->_normalize_filename: file: ) . $args{file});
        return $args{file};
    }
}

=head2 _add_to_cache(file => $file)

Adds the L<App::SharedLibraryDeps::File> object passed in as C<$file> to the
cache.

=cut

sub _add_to_cache {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    my $return_value;
    die q(Cache->_add_to_cache: missing 'file' argument)
        unless (exists $args{file});
    my $file = $args{file};
    die q(Cache->_add_to_cache: file to add to Cache is not a File object)
        unless (ref($file));
    $log->debug(q(Cache->_add_to_cache; checking filename ')
        . $file->filename() . q('));
    if ( exists $_cache{$file->filename()} ) {
        $log->info(q(Cache->_add_to_cache; ) . $file->filename()
            . q( already exists in cache!));
        $return_value = undef;
    } else {
        $log->info(q(Cache->_add_to_cache; added ) . $file->filename()
            . q( to cache));
        $_cache{$file->filename()} = $file;
        $return_value = 1;
    }
}

=head2 _get_from_cache(filename => $filename)

Checks the cache for a file object stored with the key C<$filename>, and
returns that object if it exists in the cache, and returns C<undef> if the
file does not exist in the cache.

=end internal

=cut

sub _get_from_cache {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    die q(Cache->_get_from_cache: missing 'filename' argument)
        unless (exists $args{filename});
    my $filename = $args{filename};
    if ( exists $_cache{$filename} ) {
        $log->debug(qq(Cache->_get_from_cache: $filename exists in cache));
        return $_cache{$filename};
    } else {
        $log->debug(q(Cache->_get_from_cache: file doesn't exist in cache));
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
