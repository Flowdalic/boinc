#!/bin/sh

set -ex

UPSTREAM_VERSION=$2
ORIG_TARBALL=$3

REAL_TARBALL=`readlink -f ${ORIG_TARBALL}`

WORKING_DIR=`dirname ${ORIG_TARBALL}`

ORIG_TARBALL_DFSG=`echo ${ORIG_TARBALL} | sed -e "s/\(${UPSTREAM_VERSION}\)\(\.orig\)/\1+dfsg/g"`
ORIG_TARBALL_DIR=`echo ${ORIG_TARBALL_DFSG} | sed -e "s/_\(${UPSTREAM_VERSION}\)/-\1/g" -e "s/\.tar\.gz//g"`
ORIG_TARBALL_DIR_STRIP=`basename ${ORIG_TARBALL_DIR}`
DEST_TARBALL_NAME=`echo ${ORIG_TARBALL_DIR} | sed -e "s#-\(${UPSTREAM_VERSION}\)#_\1#g"`.orig.tar.xz

mkdir -p ${ORIG_TARBALL_DIR}
tar --directory=${ORIG_TARBALL_DIR} --strip 1 -xzf ${REAL_TARBALL} || exit 1
rm -f  ${ORIG_TARBALL} ${REAL_TARBALL}

find ${ORIG_TARBALL_DIR}/ -name *.dll -delete
find ${ORIG_TARBALL_DIR}/ -name *.exe -delete
find ${ORIG_TARBALL_DIR}/ -name *.so -delete
# compiled samples ... also for Linux shall not be with the source
rm -rfv ${ORIG_TARBALL_DIR}/samples/example_app/bin
rm -rfv ${ORIG_TARBALL_DIR}/api/ttf
# license fails to explicitly express that is allows modifications
rm -rfv ${ORIG_TARBALL_DIR}/api/ttfont.cpp
rm -rfv ${ORIG_TARBALL_DIR}/api/ttfont.h
# redundant with GLUT library, license does not express clearly freedom to modify
rm -rfv ${ORIG_TARBALL_DIR}/samples/glut
# [non-free] File is licensed under the BOINC Public License which is
# DFSG-incompatible.
rm -rfv ${ORIG_TARBALL_DIR}/zip/configure
# DFSG-incompatible Apple Public Source License (APSL).
rm -rfv ${ORIG_TARBALL_DIR}/lib/mac
# [non-free] The file lib/mac/dyld_gdb.h is licensed under the
# [unneeded] This 3rd party software is already in Debian and we added
# them to boinc's Build-Depends.
rm -rfv ${ORIG_TARBALL_DIR}/curl
rm -rfv ${ORIG_TARBALL_DIR}/samples/jpeglib
# [unneeded] Cruft that is not needed to build the BOINC software.
rm -rfv ${ORIG_TARBALL_DIR}/.vimrc
# [non-free, unneeded] Unneeded build systems and binaries without
# source.
rm -rfv ${ORIG_TARBALL_DIR}/coprocs
find ${ORIG_TARBALL_DIR} -name win_build -type d -print0 | xargs -0 rm -r --
find ${ORIG_TARBALL_DIR} -name mac_build -type d -print0 | xargs -0 rm -r --
rm -rfv ${ORIG_TARBALL_DIR}/clientgui/mac
rm -rfv ${ORIG_TARBALL_DIR}/mac_installer
rm -rfv ${ORIG_TARBALL_DIR}/client/app_stats_mac.cpp
# released under CC-NC license and useless
rm -rfv ${ORIG_TARBALL_DIR}/android/BOINC/res/drawable*/*.png
# released under non-free Monotype license
rm -rfv ${ORIG_TARBALL_DIR}/clientscr/progress/simt
# modified in build process
rm -rfv ${ORIG_TARBALL_DIR}/version.h
# autogenerated visual c++ files
rm -rfv ${ORIG_TARBALL_DIR}/clientctrl/boincsvcctrl.h
rm -rfv ${ORIG_TARBALL_DIR}/clientctrl/boincsvcctrl.rc
rm -rfv ${ORIG_TARBALL_DIR}/clientgui/BOINCGUIApp.rc
rm -rfv ${ORIG_TARBALL_DIR}/clientgui/resource.h
rm -rfv ${ORIG_TARBALL_DIR}/clientscr/boinc_ss.h
rm -rfv ${ORIG_TARBALL_DIR}/clientscr/boinc_ss.rc
rm -rfv ${ORIG_TARBALL_DIR}/clientscr/boinc_ss_opengl.h
rm -rfv ${ORIG_TARBALL_DIR}/clientscr/boinc_ss_opengl.rc
rm -rfv ${ORIG_TARBALL_DIR}/clienttray/boinc_tray.h
rm -rfv ${ORIG_TARBALL_DIR}/clienttray/boinc_tray.rc
rm -rfv ${ORIG_TARBALL_DIR}/client/win/boinc_cli.h
rm -rfv ${ORIG_TARBALL_DIR}/client/win/boinc_cli.rc
rm -rfv ${ORIG_TARBALL_DIR}/client/win/boinc_cmd.h
rm -rfv ${ORIG_TARBALL_DIR}/client/win/boinc_cmd.rc
rm -rfv ${ORIG_TARBALL_DIR}/client/win/boinc_log.h
rm -rfv ${ORIG_TARBALL_DIR}/client/win/boinc_log.rc
rm -rfv ${ORIG_TARBALL_DIR}/samples/vboxwrapper/vboxwrapper_win.h
rm -rfv ${ORIG_TARBALL_DIR}/samples/vboxwrapper/vboxwrapper_win.rc
rm -rfv ${ORIG_TARBALL_DIR}/samples/wrapper/wrapper_win.h
rm -rfv ${ORIG_TARBALL_DIR}/samples/wrapper/wrapper_win.rc
rm -rfv ${ORIG_TARBALL_DIR}/samples/gfx_html/browser_win.h
rm -rfv ${ORIG_TARBALL_DIR}/samples/gfx_html/browser_win.rc
rm -rfv ${ORIG_TARBALL_DIR}/build
# bzr stuff and debian directory aren't needed
# if you use the same source tree for building the latest version
# with this debian revision https://code.launchpad.net/~costamagnagianfranco/+junk/boinc-upstream-merge
# you can erroneously export these directories too
rm -rfv ${ORIG_TARBALL_DIR}/.bzr
rm -rfv ${ORIG_TARBALL_DIR}/.bzrignore
rm -rfv ${ORIG_TARBALL_DIR}/debian

tar --exclude debian --directory ${WORKING_DIR} -cJf ${DEST_TARBALL_NAME} ${ORIG_TARBALL_DIR_STRIP} || exit 1
rm -rf ${ORIG_TARBALL_DIR}
echo "Done, now you can run git-import-orig ${DEST_TARBALL_NAME}"
