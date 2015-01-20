#!/bin/bash
#
# CernVM Lite Script Building Utility 
# Copyright (C) 2015  Ioannis Charalampidis, PH-SFT, CERN

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
# ==================================================

# Base directory where to read the files from
BASE=/mnt/.ro/cvm3/

# ==================================================

# Usage function
function usage {
	echo "USAGE: mkarchive.sh <rules> <archive>"
}

# Apply template function
function template {
	local NAME=$1
	
}

# Validate input
[ -z "$1" ] && echo "ERROR: Please specify source rules file" && usage && exit 1
[ -z "$2" ] && echo "ERROR: Please specify destination script file" && usage && exit 1
F_RULES=$1
F_ARCHIVE=$2

# We are going to produce a final script, so create the temporary file that is 
# going to hold the intermediate content
F_SCRIPT=$(mktemp)

# Tar CMDline parameters
ARG_DIRS=""
ARG_EXCLUDE=""

# Process files
while read FL; do

        # Check for invalid/comment lines
        [ $(echo "$FL" | grep -Ec '^\s*#|^\s*$') -ne 0 ] && continue

        # Get base and exclude
        ACTION=$(echo "${FL}" | awk -F':' '{ print $1 }' | tr [A-Z] [a-z])
        A=$(echo "${FL}" | awk -F':' '{ print $2 }')
        B=$(echo "${FL}" | awk -F':' '{ print $3 }')

        # Handle different actions in the ruleset
		case "$1" in

			# Copy directory $A from the base filesystem to the new filesystem,
			# excluding directories in $B. 
			copy)

				# In order to optimize the fetching and deploying procedure, an
				# archive will be created with all the files to be copiled.

    	    	# Append directories to collect
	    	    ARG_DIRS="${ARG_DIRS} ${A}"

		        # Append directories to exclude
		        for F in $B; do
	    	    	ARG_EXCLUDE="${ARG_EXCLUDE} --exclude='$F'"
		        done
				break ;;

			# Bind-mount the directory specified in $A from the base filesystem
			# to the new filesystem.
			bind)
				
				# Use the appropriate template script for binding
				template "bind" "$A" >> $F_SCRIPT
				break ;;

			# Create a blank filename in the specified location
			touch)
				break ;;

			# Make the directory specified in $A writable, and optionally
			# create the directory structure specified in $B
			writable)
				break ;;

		esac

done < $F_RULES

# Create archive
COMPRESS="-z"
if [ $(echo "$F_ARCHIVE" | grep -c 'bz2$') -ne 0 ]; then
        COMPRESS="-j"
fi

# Create archive
echo "Creating archive..."
eval "tar ${COMPRESS} -c -v -f $F_ARCHIVE -C $BASE $ARG_EXCLUDE $ARG_DIRS"
