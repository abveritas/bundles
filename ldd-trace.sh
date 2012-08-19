#!/bin/bash

# ldd-trace.sh, find a given bundle's actual linkages and copy the sofiles

#
# Copyright (c) 2010 - Drake Justice <djustice@chakra-project.org>
#
#


for sofile in $(ldd .$1 | cut -d' ' -f3 | grep -v dynamic | grep lib) ; do
    if [ "$sofile" == "not" ] ; then
        echo "ld-trace.sh: error: missing sofiles. check the environment."
        continue
    fi

    if [ ! -e .$sofile ] ; then
      mkdir -p .${sofile%/*}
      cp -fv $sofile .$sofile
    fi
done
