#!/bin/bash
#
# CernVM Lite Boot Script 
# Copyright (C) 2014-2015  Ioannis Charalampidis, PH-SFT, CERN

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

# Configuration
BASE_DIR=/mnt/.ro/cvm3

# Require a path to the boot script
[ -z "$1" ] && echo "ERROR: Please specify the boot script to use!" && exit 0
BOOT_SCRIPT=$1
shift

# Create a temporary destination directory
GUEST_DIR=$(mktemp -d)

################################################
# Read-only mount from $1 in host to $1 in guest
function MACRO_RO {
	ln -s ${BASE_DIR}/$1 ${GUEST_DIR}/$1
}
# Create writable directory in $1
function MACRO_RW {
	mkdir -p ${GUEST_DIR}/$1
}
# Create directoriy in $*
function MACRO_MKDIR {
	mkdir -p ${GUEST_DIR}/$1
}
################################################

# Source boot script
. ${BOOT_SCRIPT}

# Prepare filesystem
MACRO_PREPARE_FS ${GUEST_DIR}

# Chroot
chroot ${GUEST_DIR}
