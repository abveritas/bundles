#!/bin/bash
if [ ! -d $HOME/.bluefish ]
then
	cp ./usr/lib/bluefish $HOME/.bluefish -a
	cp ./usr/share/bluefish/bflang $HOME/.bluefish -a
fi

./usr/bin/bluefish
