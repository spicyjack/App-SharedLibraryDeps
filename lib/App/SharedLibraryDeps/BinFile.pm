package App::SharedLibraryDeps::BinFile;

use warnings;
use strict;
use Moo;

with(q(App::SharedLibraryDeps::Roles::File));

=head1 NAME

App::SharedLibraryDeps::BinFile - An object that represents a binary file on
the filesystem, which may have dependencies.  Inherits from
L<App::SharedLibraryDeps::Roles::File>; see that module for a list of
attributes and methods that are inherited by this class.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    my $filename = q(/path/to/a/binary/or/library);
    use App::SharedLibraryDeps::BinFile;
    my $file = App::SharedLibraryDeps::BinFile->new(filename => $filename);
    my @deps = $file->get_shared_library_dependencies();
    ...

=head1 OBJECT ATTRIBUTES

=over

=item libname

B<Required> - The name of the library file that will be used by the linker
when linking that library into a binary.  In the output of C<ldd>, this is the
name of the library on the B<left> hand side of each line of the output.

=head1 AUTHOR

Brian Manning, C<< <xaoc at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
L<https://github.com/spicyjack/App-SharedLibraryDeps/issues>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::SharedLibraryDeps::BinFile

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

1; # End of App::SharedLibraryDeps::BinFile
