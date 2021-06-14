# jpm

JPM is the Panet Project Manager tool. It is for automating builds and downloading
dependencies of Janet projects. This project is a port of the original `jpm` tool
(which started as a single file script) to add more functionality, clean up code, make
more portable and configuable, and
refactor `jpm` into independant, reusable pieces that can be imported as normal Janet modules.

This also introduces parallel builds, possible MSYS support, a `jpm` configuation file, and more
CLI options. Other improvements are planned such as parallel dependency downloading, more
out of the box support for non-C toolchains and pkg-config, installation from sources besides git
such as remote tarballs, zipfiles, or local directories, and more.

This is a WIP and functionality may not be up-to-date/compatible with the normal `jpm` script, although
we are trying to keep most functionality a drop-in replacement where it makes sense.

## Bootstrapping

To replace the original `jpm` tool with this port (or just install this tool in the first place), run

```
$ [sudo] janet cli.janet install
```

