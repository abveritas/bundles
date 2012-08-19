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

from cStringIO import StringIO
import subprocess
import shlex, os
import re

def run(args, sudo=True, out=subprocess.PIPE, err=subprocess.PIPE):
    '''
    Invokes pacman with or without superuser rights.
    '''
    myenv = os.environ.copy()
    myenv['LANG'] = 'C'

    command = []
    if (sudo):
        command.append('sudo')
    command.append('pacman')
    if isinstance(args, list):
        command.extend(args)
    elif isinstance(args, str):
        command.extend(shlex.split(args))
    else:
        raise TypeError, 'args cannot be of type "{0}" (must be either "list" or "str")'.format(args.__class__.__name__)

    process = subprocess.Popen(command, env=myenv, stdout=out, stderr=err)
    stdout, stderr = process.communicate()
    if process.returncode != 0:
        raise RuntimeError(stderr)
    return stdout

def sync():
    '''
    Asks Pacman to synchronize the databases and upgrade the packages, if needed.
    '''
    return run('-Syu', out=None)

def upgrade(package):
    '''
    Installs the package from the specified URL, upgrading it if needed.
    '''
    return run('-U --noconfirm "{0}"'.format(package), out=None)

def query(package):
    '''
    Wrapper for run, used for querying the database.

    This will return the -Sii info, if any, or it will fallback to -Qi. Throws a
    RuntimeError if no info is available.

    Runs with the launcher user's privileges - it will not use sudo.
    '''
    try:
        return run('-Sii "{0}"'.format(package))
    except RuntimeError:
        return run('-Qi "{0}"'.format(package))

def packagesInRepository(repository):
    '''
    Returns a list of packages contained in the specified repository.
    '''
    def _filterFieldList(n, source):
        '''
        Takes a multiline string (usually a program output) in the 'source'
        parameter, splits it by spaces, and appends the 'n'-th field to a list.
        The list of tokens extracted this way is returned to the caller.
        '''
        packages = []
        for line in source.splitlines():
            packages.append(line.split()[n])
        return packages
    return _filterFieldList(1, run('-Sl {0}'.format(repository), False))

def packagesRequiredBy(package):
    '''
    Returns a set of dependencies required by the specified package.
    '''
    pattern = re.compile(r'^Depends On *: (.*)$', re.MULTILINE)
    match = pattern.search(query(package))
    packages = re.findall(r'[^ ]+', match.group(1))
    if len(packages) == 1 and packages[0] == 'None':
        packages = []
    return set([ re.findall(r'[^>=<]+', p)[0] for p in packages ])

def packagesProvidedBy(package):
    '''
    Returns a set of package names provided by the specified package.
    '''
    pattern = re.compile(r'^Provides *: (.*)$', re.MULTILINE)
    match = pattern.search(query(package))
    packages = re.findall(r'[^ ]+', match.group(1))
    if len(packages) == 1 and packages[0] == 'None':
        packages = []
    return set([ re.findall(r'[^>=<]+', p)[0] for p in packages ])

def providerPackagesFor(package):
    '''
    Returns a set of packages that provide the specified package name.
    '''
    try:
        output = run('-Ssq -- "^{0}((<|>|=|<=|>=)?.*)$"'.format(package), False)
        return set(re.findall(r'[\w]+', output))
    except RuntimeError:
        return set()

# vim:set ts=4 sw=4 et:
