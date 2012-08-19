#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess, shlex
import sys, os
import re

def pacman(cmdline, **kwargs):
    """Invokes pacman with the specified arguments and returns its output."""

    arguments = shlex.split("pacman " + cmdline)
    devnull = open(os.devnull, 'ab')

    try:
        proc = subprocess.Popen(arguments,
            stdin=open(os.devnull, 'r'),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env={'LC_ALL': 'C'})

        stdout, stderr = proc.communicate()

        if proc.returncode != 0:
            raise RuntimeError(stderr)

        return stdout
    finally:
        devnull.close()

def providedby(package):
    """Returns a set of packages that provide the specified package name."""

    try:
        output = pacman("-Ssq -- \"^{0}((<|>|=|<=|>=)?.*)$\"".format(package))
        return set(re.findall(r'[\w]+', output))
    except RuntimeError:
        return set()

def dependson(package):
    """Returns a set of dependencies required by the specified package."""

    try:
        output = pacman("-Sii {0}".format(package))
    except RuntimeError:
        # Fallback to the local database if the package is not found
        # in the remote database.
        output = pacman("-Qi {0}".format(package))

    pattern = re.compile(r'^Depends On *: (.*)$', re.MULTILINE)
    match = pattern.search(output)

    packages = re.findall(r'[^ ]+', match.group(1))

    if len(packages) == 1 and packages[0] == 'None':
        packages = []

    return set([ re.findall(r'[^>=<]+', p)[0] for p in packages ])

def dependencies(package, deps=None):
    """Return a complete set made of the specified package and the packages required by it and by all of its dependencies."""

    if deps == None:
        deps = set()

    deps.add( package )

    try:
        for p in dependson(package):
            if p not in deps:
                dependencies(p, deps)
    except RuntimeError:
        print ' :: Skipping "{0}"... (probably a provider package)'.format(package)
    finally:
        return deps

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print " :: Exactly one argument is needed!"
        print "Usage: {0} <packagename>".format(sys.argv[0])
        sys.exit(-1)

    for package in dependencies(sys.argv[1]):
        print package,

# vim: et:ts=4:sw=4:fenc="utf-8"
