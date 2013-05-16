package App::SharedLibraryDeps::File;

use warnings;
use strict;
use Moo;

my (%_deps, %reverse_deps);

=head1 NAME

App::SharedLibraryDeps::File - A file on the filesystem that may have
dependencies, or other files may be dependent on it.

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

=head1 OBJECT ATTRIBUTES

=over

=item libname

B<Required> - The name of the library file that will be used by the linker
when linking that library into a binary.  In the output of C<ldd>, this is the
name of the library on the B<left> hand side of each line of the output.

=cut

has libname => (
    is          => q(ro),
    # is the libname a "shared object" library name?
    isa         => sub { $_[0] =~ /\.so\.\d+$/ },
    required    => 1,
);

has libfile => (
    is          => q(ro),
    # check for a file readable on the filesystem,
    # or the kernel virtual stub file
    isa         => sub { -r $_[0] || $_[0] =~ /linux-[vdso|gate]/ },
    required    => 1,
);

=item static_lib

B<Required> - Whether or not this file or library is a static library (0 = not
static library, 1 = static library)

=cut

has static_lib => (
    is          => q(ro),
    isa         => sub { warn "Not a boolean value"
        unless ($_[0] =~ /n|N|0|y|Y|1/) },
    trigger     => sub {
                    # reset the value of static_lib if it's /nNyY/
                    if ( $_[0] =~ /nN/ ) { return 0; }
                    if ( $_[0] =~ /yY/ ) { return 1; }
    },
    required    => 1,
);

=item virtual_lib

B<Required> - Whether or not this file or library is a virtual library (0 = not
virtual library, 1 = virtual library)

=cut

has virtual_lib => (
    is          => q(ro),
    isa         => sub { warn "Not a boolean value"
        unless ($_[0] =~ /n|N|0|y|Y|1/) },
    trigger     => sub {
                    # reset the value of static_lib if it's /nNyY/
                    if ( $_[0] =~ /nN/ ) { return 0; }
                    if ( $_[0] =~ /yY/ ) { return 1; }
    },
    required    => 1,
);

=item load_address

Address that a shared library will load in to when called by the linker.

=cut

has load_address => (
    is          => q(ro),
    isa         => sub { $_[0] =~ /^0x[a-fA-F0-9]+$/ },
    default     => "N/A",
);

=back

=head1 OBJECT METHODS

=head2 add_dep($dep)

Add a library dependency for this file object.

=cut

sub add_dep {
    my $self = shift;
    my $dep = shift;
    $_deps{$dep}++;
}

=head2 add_reverse_dep($dep)

Add a "reverse dependency" to this file.  Useful for showing what might break
if a given library was removed from  an archive.

=cut

sub add_reverse_dep {
}

=head2 is_static_lib()

Returns true (C<1>) if a file is a static library.

=cut

sub is_static_lib {
    my $self = shift;
    return $self->static_lib();
}

=head2 is_virtual_lib()

Returns true (C<1>) if a file is a "virtual" library, or the shim library
between a Linux kernel and the other libraries on the system.  See
L<http://www.linuxjournal.com/content/creating-vdso-colonels-other-chicken>
for a more "in-depth" explanation.

=cut

sub is_virutal_lib {
    my $self = shift;
    return $self->virtual_lib();
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
