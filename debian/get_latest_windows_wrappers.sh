#!/bin/bash

coreurl="http://boinc.berkeley.edu/dl/"

if [ "-h" == "$1" -o "--help" == "$1" -o "-help" == "$1" ]; then
	cat <<EOHELP
Usage: $(basename $0) [destdir]

The script fetches Windows binaries for the wrapper from the official BOINC repository at $coreurl.
EOHELP
	exit 0
fi

destdir=$1
if [ -z "$destdir" ]; then
	destdir="."
fi

if [ ! -d "$destdir" ]; then
	echo "E: Cannot find destination directory '$destdir'."
	exit 1
fi

set -e

filename_32=$(wget $coreurl -O - | egrep ">wrapper_.*_windows_intelx86.zip<"|tail -n 1 |tr "<>" "\n"|grep "^wrapper")
filename_64=$(wget $coreurl -O - | egrep ">wrapper_.*_windows_x86_64.zip<"|tail -n 1 |tr "<>" "\n"|grep "^wrapper")

for i in $filename_32 $filename_64
do
	echo "I: Downloading '$i'"
	wget $coreurl/$i -O "/var/tmp/$i"
	(cd $destdir && unzip  /var/tmp/$i)
	n=$(echo $i|sed -e 's/zip$/exe/')
	mv $destdir/$n $destdir/$(echo $n|cut -f1,3,4,5 -d_)
	echo "I: Removing '/var/tmp/$i'"
	rm -f "/var/tmp/$i"
done
