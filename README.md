
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

The pre/post prefix defines if the rule should be applied before or after the expansion of the files collected with the `copy` directive. By default all directives are assumed to be prefixed with the term `pre-`.

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

This script is used for creating a bootable filesystem root directory. This is useful when you want to *chroot* or create a *linux container* in the resulting directory.

### Usage

The script has the following syntax:

    cernvm-mkrootfs.sh <cvmfs base> <root> <boot script>

Where:

 * __cvmfs base__ is the base directory in CVMFS where the root filesystem files are located.
 * __root__ is the root directory where you want to deploy the CernVM filesystem.
 * __boot script__ is the boot script to use for setting-up the root filesystem.

## cernvm-userboot.sh

This script is used for booting CernVM entirely in userspace using the `proot` utility. This is a compact script, that automatically downloads the proot binary, sets-up and mounts the cvmfs repository and starts a jailed shell.

The only requirement is for the `cvmfs2` binary to exist in the environment.

### Usage:

The script has the following syntax:

    cernvm-userboot.sh <boot script>

Where:

 * __boot script__ is the boot script to use for setting-up the root filesystem.

# Configuration File Format

The configuration file is essentialy a shell script library which consists of a single function called `prepare_root`. For identification and protection against malicious uses, the file begins with the following header:

    #!/bin/false
    #BOOT_CONFIG=1.0

The `/bin/false` hashbang is used in order to prevent accidental run of the script, while the second line defines the version of the boot script configuration. Both lines must be present in order to be considered a valid boot script file.

The function itself is just a sequence of macros, following the same order as in the ruleset file. These macros should be pre-defined before the script file is included. This way, the boot script can define different booting behaviours using the same base ruleset.

The macros used are the following:

 * __MACRO_RO__ `<path>`: Perform a read-only mount from the `${BASE_DIR}/<path>` to `${GUEST_DIR}/<path>`. This is equivalent to either a *symbolic link* or to a *bind-mount* between the two directories.
 * __MACRO_RW__ `<path>`: Create a blank, writable directory in `${GUEST_DIR}/<path>`. This is equivalent to *mkdir* or to *bind-mount* to a writable scratch storage.
 * __MACRO_MKDIR__ `<path>`: Create a new directory. This is called for a directory previous created with `MACRO_RW` in order to create the internal directory structure.
 * __MACRO_EXPAND__ `<tag_id>`: Expand the list of files (collected with the `copy` directive in the rules file) with the specified tag ID. The script could either be located in the same folder with the boot script, or in a particular directory in the CVMFS repository.

# License 

CernVM Environment Lite Scripts 
Copyright (C) 2015  Ioannis Charalampidis, PH-SFT, CERN

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
