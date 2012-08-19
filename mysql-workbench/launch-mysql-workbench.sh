#!/bin/sh

here="${0%/launch-mysql-workbench.sh}"

echo " [::] Starting MySQL Workbench..."
"${here}/usr/bin/mysql-workbench" "${@}"
rc=${?}

echo " [::] Exiting with status ${rc}."
exit ${rc}
