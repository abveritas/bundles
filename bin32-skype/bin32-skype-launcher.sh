#!/bin/bash
_my_pwd="$(dirname "${0}")"
${_my_pwd}/usr/lib32/ld-linux.so.2 --library-path ${_my_pwd}/usr/lib32 ${_my_pwd}/usr/bin/skype --resources=${_my_pwd}/usr/share/skype ${@}
