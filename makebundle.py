#!/usr/bin/env python
# -*- coding: utf-8 -*-

#   MakeBundle, automation script for the creation and maintenance of Chakra bundles
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

import argparse, glob
import pacman, pkgbuild

def parse_module(name):
    '''
    Parses the specified module name, returning a 2-tuple containing the
    actual name of the packaging module and a boolean indicating wether the
    compilation should be forced or not.
    '''
    if name.startswith('@'):
        return (name[1:], True)
    else:
        return (name, False)

def _real_build_module(name):
    '''
    Really building the specified module.
    '''
    print
    print " :: Building \"{0}\"...".format(name)

def build_module(name):
    '''
    Make so that the specified moduled is available (i.e., build it or fetch
    it from a remote server), then install it for later usage.

    If name starts with a '@', then the package will get built locally, even if
    it is available from a remote server.
    '''
    module, force_build = parse_module(name)

    # search for prebuilt packages
    temp = glob.glob('_temp/{0}-[0-9]*-*.pkg.tar.xz'.format(module))
    pkgz = glob.glob('_pkgz/{0}-[0-9]*-*.pkg.tar.xz'.format(module))

    # a locally built package already exist, install that one
    if len(temp) != 0: pacman.upgrade(temp[-1])
    # no locally built package available, for rebuild is forced, so build it
    elif force_build: _real_build_module(module)
    # a remotely built package is available, install that one
    if len(pkgz) != 0: pacman.upgrade(pkgz[-1])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='A script that automates the building of Chakra bundles.')
    parser.add_argument('bundle', type=str,  help='the name of the bundle to build')
    parser.add_argument('-s', '--no-sync',   action='store_true', default=False,  help='sync the Pacman database or not')
    parser.add_argument('-d', '--no-build',  action='store_true', default=False,  help='build the bundle dependencies')
    parser.add_argument('-b', '--no-bundle', action='store_true', default=False,  help='perform the bundling step')
    parser.add_argument('-c', '--no-clean',  action='store_true', default=False,  help='perform the final cleaning')
    args = parser.parse_args()

    # preserve the core packages!
    packagesToKeep = pacman.packagesInRepository('core')

    # make sure we are in sync with the remote repositories
    if not args.no_sync:
        pacman.sync()

    # read the pkginfo
    variables = pkgbuild.parse('{0}/PKGBUILD'.format(args.bundle))

    # build it
    build_module(args.bundle)

# vim:set ts=4 sw=4 et:
