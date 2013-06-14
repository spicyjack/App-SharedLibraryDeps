# App::SharedLibraryDeps #

Given one or more dynamically linked binary files or libraries, calculate the
dependencіes of those files recursively, so that a list of files required to
run the original binaries or libraries can be generated.

## Todo ##
- Generate this README or the regular docs from POD
- Write tests
  - Use `libm` as the example library to parse dependencies for
  - Keep a canned copy of the output for `ldd libm.so` in the test to test
    against
- Add `stat()` to the `File` role
- Create output modules (kernel filelist, plaintext)

vim: filetype=markdown shiftwidth=2 tabstop=2
