#!/bin/sh
# vim:set ts=2 sw=2 et:

__base_dir="$(dirname ${0})"

pushd "${__base_dir}/usr/lib/chromium" &>/dev/null
  ./chromium --ppapi-flash-path="${__base_dir}/opt/google/chrome/PepperFlash/libpepflashplayer.so" \
             --ppapi-flash-version="11.3.31.103" \
             "${@}"
  __rc="${?}"
popd &>/dev/null

exit "${__rc}"