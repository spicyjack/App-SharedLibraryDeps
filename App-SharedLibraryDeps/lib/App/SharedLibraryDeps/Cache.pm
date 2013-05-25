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
use App::SharedLibraryDeps::BinFile;
use App::SharedLibraryDeps::LibFile;

# for storing file objects once they've been queried via ld.so
my %_cache;

=head1 NAME

App::SharedLibraryDeps::Cache - A cache of L<App::SharedLibraryDeps::LibFile>
objects.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    my $filename = q(/path/to/a/binary/or/library);
    use App::SharedLibraryDeps::Cache;
    use App::SharedLibraryDeps::BinFile;
    my $cache = App::SharedLibraryDeps::Cache->new();
    my $file = App::SharedLibraryDeps::BinFile->new(filename => $filename);
    my @deps = $cache->get_deps(file => $file);
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

=head2 get_deps(filename => $file, [sort => $sort, return_format => $type])

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

sub get_deps {
    my $self = shift;
    my %args = @_;
    my $log = get_logger("");

    # sort and return_type are optional
    die q|Missing filename argument (filename => $filename)|
        unless ( exists $args{filename} );

    my $filename = $args{filename};
    my $sort_order = $args{sort};
    my $return_type = $args{return_type};
    # current file object
    my $file;
    my @dependencies;

    if ( ! defined $filename ) {
        $log->warn(q|Cache->get_deps; 'filename' argument undefined|);
        return ();
    }
    if ( -r $filename ) {
        $log->debug(q(Cache->get_deps: ) . $filename . q( is readable));
        # @file_dependencies can be checked to see if the file has already
        # been cached or not
        $file = App::SharedLibraryDeps::BinFile->new(
            filename    => $filename,
        );
        #push(@dependencies, $self->get_deps(filename => $file->filename() ));
    } elsif ( $filename =~ /linux-[gate|vdso].*/ ) {
        $log->debug(qq(Cache->get_deps: $filename is a virtual file));
        $file = App::SharedLibraryDeps::LibFile->new(
            filename    => $filename,
            virtual_lib => 1,
        );
        #push(@dependencies, $self->query_file(file => $file));
    } else {
        $log->warn("Cache->get_deps: " . $filename
            . " is *not* readable");
        return ();
    }

    # query 'ldd'
    my $cmd = q(/usr/bin/ldd ) . $file->filename();
    # remove PATH from the environment, we don't need it for this
    delete @ENV{q(PATH)};
    my @ldd_output = qx/$cmd/;
    chomp(@ldd_output);
    if ( $log->is_debug() ) {
        $log->debug(qq(Dependencies found my 'ldd' for )
            . $file->filename() . q( are:));
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
                my $virtual_file = App::SharedLibraryDeps::LibFile->new(
                    libname         => $libname,
                    filename        => $libname,
                    static_lib      => 0,
                    virtual_lib     => 1,
                    load_address    => $load_address,
                );
                $log->debug(qq(Cache->get_deps: adding virtual file )
                    . qq('$libname' to deps list));
                push(@dependencies, $virtual_file);
                $self->_add_to_cache(file => $virtual_file);
                next LDD_LINE;
            } else {
                $log->debug(qq(Cache->get_deps: adding 2-arg '$ldd_line')
                    . qq( to deps list as filename $libfile));
            }
        } elsif ( $ldd_line =~ /^statically linked/ ) {
            my $static_file = App::SharedLibraryDeps::LibFile->new(
                libname         => $file->filename(),
                filename        => $file->filename(),
                static_lib      => 1,
                virtual_lib     => 0,
            );
            $log->debug(qq(Cache->get_deps: adding static lib ')
                . $file->filename() . q(' to deps list));
            push(@dependencies, $file);
            $self->_add_to_cache(file => $static_file);
            next LDD_LINE;
        } elsif ( $ldd_line
                =~ /^([\/a-zA-Z0-9\-\+_].*) => (\/.*) \((0x.*)\)/ ) {
            $libname = $1;
            $libfile = $2;
            $load_address = $3;
            $log->debug(qq(Cache->get_deps: adding 3-arg '$ldd_line')
                . qq( to deps list as filename $libfile));
        } elsif ( $ldd_line =~ /^([\/a-zA-Z0-9\-\+_].*) \((0x.*)\)/ ) {
            $libname = $1;
            $libfile = $libname;
            $load_address = $2;
            $log->debug(qq(Cache->get_deps: adding simple 2 arg '$ldd_line')
                . q( to deps list as ) . $1);
        } else {
            $log->logdie(q(Cache->get_deps: )
                . qq(Can't determine dependency info for $ldd_line));
        }

        # this will retrieve the file object from the cache, if the file
        # object has already been added to the cache
        $log->debug(qq(Cache->get_deps: Checking for $libfile in cache));
        my $cache_file = $self->_get_from_cache(filename => $libfile);
        if ( defined $cache_file ) {
            $log->info(qq(Cache->get_deps: Adding ) . $cache_file->filename()
                . qq( to dependencies for ) . $file->filename());
            push(@dependencies, $cache_file->filename());
        } else {
            #if ( ! $virtual_lib ) {
            #    $log->info(qq(Cache->get_deps: recursing with $libfile));
            #    $self->query_file(file => $libfile);
            #}
            my $file_obj;
            if ( defined $load_address ) {
                $file_obj = App::SharedLibraryDeps::LibFile->new(
                    libname         => $libname,
                    filename        => $libfile,
                    static_lib      => $static_lib,
                    load_address    => $load_address,
                    virtual_lib     => $virtual_lib,
                );
            } else {
                $file_obj = App::SharedLibraryDeps::LibFile->new(
                    libname         => $libname,
                    filename        => $libfile,
                    static_lib      => $static_lib,
                    virtual_lib     => $virtual_lib,
                );
            }
            $log->info(q(Cache->get_deps: Adding ) . $file_obj->libname()
                . q( to cache and dependencies));
            $self->_add_to_cache(file => $file_obj);
            push(@dependencies, $file_obj);
            # FIXME verify this will work
            #$file_obj->deps($file->filename());
        }
    }
    $log->info(qq(Cache->get_deps: returning; ) . $file->filename()
        . q( has ) . scalar(@dependencies) . q( dependencies));
    $log->debug(qq(Cache->get_deps: dependencies for ) . $file->filename());
    foreach my $dep ( sort(@dependencies) ) {
        $log->debug( q( - ) . $dep->filename() );
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

Adds the L<App::SharedLibraryDeps::LibFile> object passed in as C<$file> to
the cache.

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

    $log->debug(q(Cache->_add_to_cache; checking if ')
        . $file->libname() . q(' already exists in cache));
    if ( exists $_cache{$file->filename()} ) {
        $log->info(q(Cache->_add_to_cache; ) . $file->libname()
            . q( already exists in cache!));
        $return_value = undef;
    } else {
        $log->info(q(Cache->_add_to_cache; added ) . $file->libname()
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
