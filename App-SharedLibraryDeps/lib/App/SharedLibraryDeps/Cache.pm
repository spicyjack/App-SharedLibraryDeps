package App::SharedLibraryDeps::Cache;

use warnings;
use strict;

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

=head1 OBJECT METHODS

=head2 function1

=cut

sub function1 {
}

=head2 function2

=cut

sub function2 {
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
