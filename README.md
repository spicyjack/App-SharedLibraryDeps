# App::SharedLibraryDeps #

Given one or more dynamically linked binary files or libraries, calculate the
dependencіes of those files recursively, so that a list of files required to
run the original binaries or libraries can be generated.

# Todos #
- Generate this README or the regular docs from POD

# INSTALLATION #

To install this module, run the following commands:

    perl Makefile.PL
	  make
	  make test
	  make install

# USAGE #

    perl shared_lib_deps.pl --http-user=foo --http-pass=bar \
    --url https://example.com/jenkins/job/chocolate-doom --verbose

## Support and Documentation ##

After installing, you can find documentation for this module with the
perldoc command.

    perldoc App::SharedLibraryDeps

You can also look for information at:

    Project GitHub repo
        https://github.com/spicyjack/App-SharedLibraryDeps

    Project GitHub issue tracker
        https://github.com/spicyjack/App-SharedLibraryDeps/issues

COPYRIGHT AND LICENCE

Copyright (C) 2013 Brian Manning

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

vim: filetype=markdown shiftwidth=2 tabstop=2
