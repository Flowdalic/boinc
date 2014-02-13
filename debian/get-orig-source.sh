#!/bin/sh
UPSTREAM_TAG=$2
UPSTREAM_TAG_LOCATION=$3
EXB=/tmp/export-boinc
wget -O $EXB "http://git.debian.org/?p=pkg-boinc/scripts.git;a=blob_plain;f=export-boinc;hb=HEAD" --quiet; \
chmod +x $EXB
$EXB -r $UPSTREAM_TAG -t ..
rm -f $EXB $UPSTREAM_TAG_LOCATION
