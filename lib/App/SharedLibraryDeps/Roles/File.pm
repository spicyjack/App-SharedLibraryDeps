package App::SharedLibraryDeps::Roles::File;

use strict;
use warnings;
use 5.010;
use File::stat;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use Moo::Role;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;

=head1 NAME

App::SharedLibraryDeps::Roles::File - A file role, that encapsulates physical
file attributes such as filename, size, permissions, C<[c|a|m]time>, and so
on.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    my $filename = q(/path/to/a/binary/or/library);
    use App::SharedLibraryDeps::File;
    my $file = App::SharedLibraryDeps::File->new(filename => $filename);
    my @deps = $file->get_shared_library_dependencies();
    ...

=head1 OBJECT METHODS

=head2 add_dep($dep)

Accepts an L<App::SharedLibraryDeps::BinFile> or
L<App::SharedLibraryDeps::LibFile> object, and adds that object as a dependency
for this file object.  Returns the current dependencies hash for this L<File>
object.

=cut

sub add_dep {
    my $self = shift;
    my $dep = shift;
    my $log = get_logger("");

    my %deps;
    $log->debug(q(Adding dependency ) . $dep->hashname()
        . q( to ) . $self->hashname());
    if ( defined $self->_deps ) {
        $log->debug(q(Regurgitated deps for ') . $self->shortname()
            . q(' are:));
        %deps = %{$self->_deps};
        $log->debug(Dumper {%deps});
    }
    $deps{$dep->filename}++;
    $log->debug(q(Deps for ') . $self->shortname() . q(' are now:));
    $log->debug(Dumper {%deps});
    $self->_deps(\%deps);
    my %return = %deps;
    return %return;
}

=head2 get_deps()

Returns an array containing the filenames of files that are dependencies of
this file.

=cut

sub get_deps {
    my $self = shift;

    if ( defined $self->_deps ) {
        my %return = %{$self->_deps};
        return sort(keys(%return));
    } else {
        return ();
    }
}

=head2 get_deps_count()

Returns the number of dependencies that this file has.

=cut

sub get_deps_count {
    my $self = shift;

    if ( defined $self->_deps ) {
        return scalar(keys(%{$self->_deps}));
    } else {
        return 0;
    }
}

=head2 add_reverse_dep($dep)

Accepts an L<App::SharedLibraryDeps::BinFile> or
L<App::SharedLibraryDeps::LibFile> object, and adds that object as a "reverse
dependency" for this file object.  Returns the current dependencies hash for
this L<File> object.

=cut

sub add_reverse_dep {
    my $self = shift;
    my $dep = shift;
    my $log = get_logger("");

    my %rev_deps;
    $log->debug(q(Adding reverse dependency ) . $dep->hashname()
        . q( to ) . $self->hashname());
    if ( defined $self->_reverse_deps ) {
        $log->debug(q(regurgitated reverse deps for ') . $self->shortname()
            . q(' are:));
        %rev_deps = %{$self->_reverse_deps};
        $log->debug(Dumper {%rev_deps});
    }
    $rev_deps{$dep->filename}++;
    $log->debug(q(reverse deps for ') . $self->shortname() . q(' are now:));
    $log->debug(Dumper {%rev_deps});
    $self->_reverse_deps(\%rev_deps);
    my %return = %rev_deps;
    return %return;
}

=head2 get_reverse_deps()

Returns a hash containing the "reverse dependencies" of this file, along with
their "hit counts", or how many times that file is referenced by another file
in the cache.

=cut

sub get_reverse_deps {
    my $self = shift;
    my %return = %{$self->_reverse_deps};
    return sort(keys(%return));
}

=head2 get_reverse_deps_count()

Returns the number of "reverse" dependencies (files that depend on this file)
that this file has.

=cut

sub get_reverse_deps_count {
    my $self = shift;

    if ( defined $self->_deps ) {
        return scalar(keys(%{$self->_reverse_deps}));
    } else {
        return 0;
    }
}

=head1 OBJECT ATTRIBUTES

=over

=item filename

B<Required> - The name of the file on the filesystem.

=cut

has filename => (
    is          => q(ro),
    # check for a file readable on the filesystem,
    # or the kernel virtual stub file
    isa         => sub { -r $_[0] || $_[0] =~ /linux-[vdso|gate]/ },
    required    => 1,
    trigger     => sub {
                    my $self = shift;
                    my $arg = shift;
                    # XXX *NIX specific path
                    my @path = split(q(/), $arg);
                    $self->shortname($path[-1]);
                    my $hashname = $self;
                    $hashname =~ s/.*(\(0x[0-9a-f]+\))$/$1/;
                    $self->hashname($path[-1] . qq( $hashname));
    },
);

=item filestat

A L<File::stat> object that represents the C<stat()> attributes for the file
that this object represents.

=back

=cut

has filestat => (
    is          => q(rw),
);

=item shortname

The file name of the file on the filesystem.  This attribute is updated when
the C<filename> attribute (above) is set.

=back

=cut

has shortname => (
    is          => q(rw),
);

=item hashname

A combination of C<shortname> plus the memory location of the object within
Perl.  Used for debugging the possibility of multiple objects for the same
file in a dependency/reverse dependency list somewhere.  This attribute is
updated when the C<filename> attribute (above) is set.

=back

=cut

has hashname => (
    is          => q(rw),
);

has _deps => (
    is          => q(rw),
    isa         => sub {
                    if ( ref($_[0]) eq q(HASH) ) {
                        return 1;
                    } else {
                        warn q(File->_deps: received non-HASH value);
                        return 0;
                    }
    },
);

has _reverse_deps => (
    is          => q(rw),
    isa         => sub {
                    if ( ref($_[0]) eq q(HASH) ) {
                        return 1;
                    } else {
                        warn q(File->_reverse_deps: received non-HASH value);
                        return 0;
                    }
    },
);

=head1 AUTHOR

Brian Manning, C<< <xaoc at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
L<https://github.com/spicyjack/App-SharedLibraryDeps/issues>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::SharedLibraryDeps::File

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

1; # End of App::SharedLibraryDeps::File
