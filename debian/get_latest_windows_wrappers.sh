#!/bin/bash

coreurl="http://boinc.berkeley.edu/dl/"

if [ "-h" == "$1" -o "-help" == "$1" -o "--help" == "$1" ]; then
	cat <<EOHELP
$(basename $0|tr "a-z" "A-Z")                   BOINC-SERVER-MAKER                   $(basename $0|tr "a-z" "A-Z")

NAME

  $(basename $0) - retrieve Mac and Windows binaries for the wrapper from the official BOINC repository at $coreurl

SYNOPSIS

  $(basename $0) [<destdir>|--help]

DESCRIPTION

  The script fetches Windows binaries for the wrapper from the official BOINC repository at $coreurl.

SEE ALSO

	http://wiki.debian.org/BOINC
	http://mgltools.scripps.edu
	http://autodock.scripps.edu

COPYRIGHT

  This script is released under the same license as BOINC.

AUTHORS

  Steffen Moeller <moeller@debian.org>
    with contributions from
  Christian Beer <djangofett@gmx.net>
  Natalia Nikitina <nevecie@yandex.ru>

EOHELP
	exit 0
fi

set -e

destdir=$1
if [ -z "$destdir" ]; then
	destdir="."
fi

if [ ! -d "$destdir" ]; then
	echo "E: Cannot find destination directory '$destdir'."
	exit 1
fi

filename_32_win=$(wget $coreurl -O - | egrep ">wrapper_.*_windows_intelx86.zip<"|tail -n 1 |tr "<>" "\n"|grep "^wrapper")
filename_64_win=$(wget $coreurl -O - | egrep ">wrapper_.*_windows_x86_64.zip<"|tail -n 1 |tr "<>" "\n"|grep "^wrapper")
filename_32_mac=$(wget $coreurl -O - | egrep ">wrapper_.*_i686-apple-darwin.zip<"|tail -n 1 |tr "<>" "\n"|grep "^wrapper")
filename_64_mac=$(wget $coreurl -O - | egrep ">wrapper_.*_x86_64-apple-darwin.zip<"|tail -n 1 |tr "<>" "\n"|grep "^wrapper")

for i in $filename_32_win $filename_64_win $filename_32_mac $filename_64_mac
do
	echo "I: Downloading '$i'"
	(cd /var/tmp && wget -N $coreurl/$i)
	(cd $destdir && unzip  /var/tmp/$i)
	n=$(echo $i|sed -e 's/.zip$//')
	if echo $i | grep -q windows; then
		n=$(echo $i|sed -e 's/zip$/exe/')
	fi
	mv $destdir/$n $destdir/$(echo $n|cut -f1,3,4,5 -d_)
	echo "I: Removing '/var/tmp/$i'"
	rm -f "/var/tmp/$i"
done
