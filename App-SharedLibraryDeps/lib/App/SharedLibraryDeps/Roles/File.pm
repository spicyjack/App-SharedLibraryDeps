package App::SharedLibraryDeps::Roles::File;

use warnings;
use strict;
use Moo::Role;

my (%_deps);

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
);

=head1 OBJECT METHODS

=head2 add_dep($dep)

Add a library dependency for this file object.

=cut

sub add_dep {
    my $self = shift;
    my $dep = shift;
    $_deps{$dep->filename()}++;
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
