#!/usr/bin/python
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

import urllib
import sys
import os

def show_help():
	print "CernVM in userland boot script"
	print "This "
	print "Usage:"
	print ""
	print "  cvmu [-b <script>] [-c <cvmfs_repos>] <command> ..."
	print ""
	print "Where:"
	print ""
	print "  -b <script>      : Override the default boot script."
	print "  -c <cvmfs_repos> : Specify one or more CVMFS repositories to"
	print "                     make available in your CernVM environment."
	print "         <command> : The command to execute after setting-up the"
	print "                     environment (default is '/bin/bash')."
	print ""

def 