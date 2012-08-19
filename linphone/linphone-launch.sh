#!/bin/sh
BaseDir="$(dirname $(which ${0}))"
cd $BaseDir/usr/share/linphone/
${PWD}/linphone $1