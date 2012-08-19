#!/usr/bin/env python
# -*- coding: utf-8 -*-

#   MakeBundle, automation script for the creation and maintenance of cinstall bundles
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>
#
#    Copyright (c) 2011 by Manuel Tortosa <manutortosa[at]chakra-project[dot]org
#                          and the team behind Chakra

import subprocess
import re

_arrays = ['arch', 'source', 'depends', 'makedepends', 'setvars',
           'md5sums', 'sha1sums', 'sha256sums']

def _dump(PKGBUILD):
    '''
    Invokes ./dump-pkgbuild.sh on the specified path.
    '''
    command = ['sh', '--noprofile', '--norc', 'parsepkgbuild.sh', PKGBUILD]
    process = subprocess.Popen(command, env={}, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = process.communicate()
    if process.returncode != 0:
        raise RuntimeError(stderr)
    return stdout.splitlines()

def parse(PKGBUILD):
    '''
    Reads a PKGBUILD and returns its values as a dictionary.
    '''
    d = {}
    key = ''
    for line in _dump(PKGBUILD):
        s = line.strip()
        if s == '': continue

        if re.match(r'^%.*%$', s):
            # we're reading a new section
            key = s[1:-1].lower()
        else:
            if d.get(key) == None:
                # we're setting a new value, or...
                if key in _arrays:
                    d[key] = [s]
                else:
                    d[key] = s
            else:
                # ...extending an array
                d[key].append(s)
    return d

# vim:set ts=4 sw=4 et:
