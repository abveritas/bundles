#!/bin/sh

_xulver=$(echo $(${PWD}/usr/lib/xulrunner-1.9.2/xulrunner --version 2>&1) | cut -d " " -f 3)

if [ "$(uname -m)" != "x86_64" ]; then
    _arch=x86
else
    _arch=x86_64
fi

echo "[${_xulver}]
GRE_PATH=${PWD}/usr/lib/xulrunner-1.9.2
xulrunner=true
abi=${_arch}-gcc3" > /etc/cb.conf.d/${_xulver}.system.conf &&
sudo chmod a+w /etc/cb.conf.d/${_xulver}.system.conf

${PWD}/usr/lib/firefox-3.6/firefox $1
