#!/bin/bash

# This script shall support the initial setup 
# of a BOINC server by assisting in the download
# of example applications from Debian.
#
# This script is released under the same license
# as BOINC, created and copyright by
# Steffen Moeller <moeller@debian.org>
# with contributions by Christian Beer <djangofett@gmx.net>.
#
# Modified by
# Natalia Nikitina <nevecie@yandex.ru>

set -e

if [ "-h" = "$1" -o "-help" = "$1" -o "--help" = "$1" ]; then
	cat <<EOHELP

Usage: $0 [<boinc project root dir>|--help]

  This script collects the binaries for multiple platforms of a Debian
  package.  All parameters are specified by environment variables.

    installroot        path to install directory that together with the
    projectname        defines the project's root directory.
    packagename        determines the name of the Debian package to install

  Optional:
    version            what version exactly shall be installed
    sourcepackagename  name of source package from which binary is produced,
                       autoretrieved by 'apt-cache show \$packagename'
    downloaddir        directory into which the Debian packages are downloaded,
                       defaults to 'collection'
    appsdir            directory to harbor unpackaged binaries and project
                       signatures, defaults to '\$projectroot/apps'

  If the packagename is not specified, then it defaults to
  boinc-app-examples.

EOHELP
	exit 1
fi

declare -A deb2boinc
deb2boinc[armel]="armel-linux-gnu"
deb2boinc[alpha]="alpha-linux-gnu"
deb2boinc[amd64]="x86_64-pc-linux-gnu"
deb2boinc[i386]="i686-pc-linux-gnu"
deb2boinc[powerpc]="powerpc-linux-gnu"
deb2boinc[powerpc64]="ppc64-linux-gnu"
deb2boinc[ia64]="ia64-linux-gnu"
deb2boinc[sparc]="sparc-linux-gnu"
deb2boinc[sparc64]="sparc64-linux-gnu"
deb2boinc[mips]="mips-linux-gnu"
deb2boinc[s390]="s390-linux-gnu"

if [ -z "$packagename" ]; then
	packagename=boinc-app-examples 
fi
if [ -z "$mirror" ]; then
	mirror="http://ftp.de.debian.org/debian"
fi

version=$(apt-cache show $packagename | grep ^Version | tail -1 | cut -f2 -d\  )
if [ -z "$version" ]; then
	echo "E: apt-cache does not know any version for package '$packagename'."
	exit 1
fi

if [ -z "$sourcepackagename" ]; then
	sourcepackagename=$(apt-cache show $packagename|grep ^Source:|sort -u|cut -f2 -d\ |head -n 1)
	if [ -z "$sourcepackagename" ]; then
		echo "I: Could not determine source package name of '$packagename'"
		exit 1
	else
		echo "I: Determined source package of '$packagename' as '$sourcepackagename'"
	fi
fi
# first letter or libL to constrain download directory
spn=$(echo $sourcepackagename|sed -e 's/^\(lib.\|.\).*/\1/')

if [ -n "$1" ]; then
	projectroot=$1
elif [ -z "$projectroot" ]; then
	if [ -n "$installroot" -a -n "$projectname" ]; then
		projectroot="$installroot/$projectname"
	else
		echo "E: Please specify the project root directory via the 'projectroot' environment variable."
		exit 1
	fi
fi

sign="$projectroot/bin/sign_executable"
key="$projectroot/keys/code_sign_private"

shortver=$(echo $version|cut -d . -f-2)

if [ -z "$appsdir" ]; then
	if [ -d "$projectroot/apps" ]; then
		echo "W: 'appsdir' not specified, chose '\$projectroot/apps'."
		appsdir="$projectroot/apps"
	else
		echo "W: 'appsdir' not specified, and no apps directory in \$projectroot, decided for 'apps'.".
		appsdir="apps"
	fi
fi

if [ -z "$downloaddir" ]; then
	downloaddir="collection"
fi

if [ -d "$appsdir" ]; then
	echo "E: Directory '$appsdir' is already existing. Please clean this up first."
	exit
fi

echo "I: Retrieving application for all of Debian's architectures."

for arch in ${!deb2boinc[@]}
do
  if [ -d $downloaddir/$arch ]; then
    echo "W: Destination directory '$downloaddir/$arch' already exiting ... skipping."
    continue
  fi

  if [ ! -r $arch.deb ]; then 
    url="$mirror/pool/main/${spn}/${sourcepackagename}/${packagename}_${version}_${arch}.deb"
    if ! wget --quiet -O - $url > ${arch}.deb ; then
       echo "E: Platform '$arch' failed to download .... skipping."
       rm -f ${arch}.deb
       continue
    fi
  fi

  ar xvf ${arch}.deb data.tar.xz
  echo "I: Untaring for architecture ${arch}"
  tar xfJ data.tar.xz ./usr/lib/boinc-server/apps/  
  echo -n "I: Contents:"
  ls ./usr/lib/boinc-server/apps/
  mkdir -p $downloaddir
  mv ./usr/lib/boinc-server/apps $downloaddir/$arch
  mv usr deleteThisDir
  rm -rf deleteThisDir data.tar.xz ${arch}.deb
done

if [ -d "$appsdir" ]
then
    echo "E: App directory '$appsdir' already exists, exiting!!"
    exit
fi

echo "I: Creating directories for all applications in folder '$downloaddir' now in folder '$appsdir'."
for f in `find collection -type f | xargs -r -l basename| sort -u`
do
    appname=`echo $f|cut -d / -f3`
    for arch in ${!deb2boinc[@]}
    do
      mkdir -p $appsdir/$appname/$shortver/${deb2boinc[$arch]}
    done

done

for app in $appsdir/*
do 
    appname=$(basename $app)
    echo "I: Copying files for application '$appname'"
    echo -n "  "
    for folder in $downloaddir/*
    do 
      archname=$(echo $folder|cut -d / -f2)
      echo -n " $archname"
      cp $folder/$appname $appsdir/$appname/$shortver/${deb2boinc[$archname]}/${appname}_${shortver}_${deb2boinc[$archname]}
    done
    echo
done

if [ ! -x "$sign" ]; then
	echo "I: You need to sign the applications, still. This is to be performed specifically for your project."
	cat <<EOINSTRUCTIONS
   Follow the following scheme:
     sign="\$projectroot/bin/sign_executable"
     key="\$projectroot/keys/code_sign_private"
     for binary in $appsdir/*/*/*/*
     do
        \$sign \$binary \$key > ${binary}.sig
     done
EOINSTRUCTIONS
else
	for binary in $appsdir/*/*/*/*
	do
	    echo Signing $binary
	    $sign $binary $key > ${binary}.sig
	done
fi
