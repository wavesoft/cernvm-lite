
# CernVM Lite

`CernVM Lite` is a set of utilities that allows booting and using a CernVM distribution in environments where AUFS is not available, even in userland!

There are two kinds of utilities: The **building** scripts and the **booting** scripts. The *building* scripts are used for preparing the configuration file used by the *booting* scripts to boot a CernVM distribution.

# Build Scripts

The building scripts located in the `build-scripts` folder are used for creating the confiugration file, later used by the boot scripts in order to boot a CernVM distribution.

## Usage

The script `build-bootconf.py` creates a boot configuration script, using as input a directory structure-hinting ruleset, as described in the next paragraph.

The script is used like this:

    build-bootconf.py path/to/rules.rules output.boot

## Build Rules

The build rules found in the `build-scripts/rules` folder, define the attributes of the directory structure that will be applied by the boot scripts during system boot.

The syntax of the build rules is the following:

```sh
# Comments start with a hash
# Each rule is defined like this:
[pre/post-]<directive>:<path>[:<optional additional parameters>]
```

### `copy:<path>`

The `copy` directive denotes that the specified path should be copied from the upstream filesystem to the guest filesystem in a writable directory. This is effectively a costly *copy-on-write* operation that should only be used in small directories. 

For optimization purposes, the build script is creating a compressed tarball with all the files that should be eventually copied in the guest filesystem.

### `readonly:<path>`

The `readonly` directive denotes that the specified path should be mounted in read-only mode from the upstream filesystem.

### `writable:<patn>[:<structure>]`

The `writable` directive denotes that the specified path should be writable. This means creating a blank directory in the specified location.

The optional parameter `structure` is a space-separated, wildcard-capable list of sub-paths that should be created inside the base directory. For example, you can create a blank `/usr/local` structure using:

    writable:usr/local:{bin,etc,games,include,lib,lib64,libexec,sbin,src,share/{applications,info,perl5,man/man{1,1x,2,2x,3,3x,4,4x,5,5x,6,6x,7,7x,8,8x,9,9x,n}}}

### `touch:<path>`

The `touch` directive creates a blank file in the given path.

### `set:<parameter>:<value>`

The `set` directive sets the value of an arbitrary parameter used either by the build or by the boot script. Currently the following parameters are used:

 * __tag__: This is the identification number for the resulting compressed files tarball. 

# Boot Scripts

Currently there are two versions of build scripts: One used for creating a bootable root filesystem, compatible with `chroot` command, and one for directly booting the CernVM distribution entirely in userlevel using the `pboot` utility.

## cernvm-mkrootfs.sh

This script is used for creating a bootable filesystem root directory.
