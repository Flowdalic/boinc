#!/usr/bin/make -f

# Uncomment this to turn on verbose mode.
#export DH_VERBOSE=1

DEB_HOST_GNU_TYPE  ?= $(shell dpkg-architecture -qDEB_HOST_GNU_TYPE)
DEB_BUILD_GNU_TYPE ?= $(shell dpkg-architecture -qDEB_BUILD_GNU_TYPE)

# Most BOINC projects only provide applications for i686.
ifeq ($(DEB_BUILD_GNU_TYPE), i486-linux-gnu)
  DEB_BUILD_GNU_TYPE = i686-linux-gnu
endif

CFLAGS += -g -Wall
CXXFLAGS += -g -Wall

CFLAGS_boinc-client := $(CFLAGS)
CXXFLAGS_boinc-client := $(CXXFLAGS)

ifneq (,$(findstring noopt,$(DEB_BUILD_OPTIONS)))
  DEB_OPT_FLAG = -O0
  DEB_OPT_FLAG_boinc-client = -O0
else
  DEB_OPT_FLAG = -O2
  DEB_OPT_FLAG_boinc-client = -O3 -ffast-math
endif

CFLAGS += $(DEB_OPT_FLAG)
CXXFLAGS += $(DEB_OPT_FLAG)

CFLAGS_boinc-client += $(DEB_OPT_FLAG_boinc-client)
CXXFLAGS_boinc-client += $(DEB_OPT_FLAG_boinc-client)

CFGFLAGS = \
  --build=$(DEB_BUILD_GNU_TYPE) \
  --host=$(DEB_HOST_GNU_TYPE) \
  --prefix=/usr \
  --enable-client \
  --enable-server \
  CFLAGS="$(CFLAGS)" \
  CXXFLAGS="$(CXXFLAGS)"

CFGFLAGS_boinc-client = \
  --build=$(DEB_BUILD_GNU_TYPE) \
  --host=$(DEB_HOST_GNU_TYPE) \
  --enable-client \
  --disable-server \
  CFLAGS="$(CFLAGS_boinc-client)" \
  CXXFLAGS="$(CXXFLAGS_boinc-client)"

pre-build:
	aclocal-1.9 -I m4 && autoheader && automake-1.9 && autoconf
	
	docbook2x-man debian/manpages/boinc_client.xml
	docbook2x-man debian/manpages/boinc_cmd.xml
	docbook2x-man debian/manpages/boincmgr.xml

build: pre-build
build: build-stamp

build-stamp: build-stamp-boinc-client
	dh_testdir
	./configure $(CFGFLAGS)
	$(MAKE)
	touch $@

build-stamp-boinc-client:
	dh_testdir
	./configure $(CFGFLAGS_boinc-client)
	$(MAKE)
	cp client/boinc_client client/boinc_client.optimized
	touch $@

clean: clean-boinc-client
	dh_testdir
	dh_testroot
	rm -f build-stamp
	-$(MAKE) clean
	-$(MAKE) distclean
	
	dh_clean \
	  boinc_client.1 \
	  boinc_cmd.1 \
	  boincmgr.1
	  
	dh_clean \
	  api/Makefile.in \
	  apps/Makefile.in \
	  client/Makefile.in \
	  clientgui/Makefile.in \
	  db/Makefile.in \
	  lib/Makefile.in \
	  m4/Makefile.in \
	  py/Makefile.in \
	  py/Boinc/Makefile.in \
	  sched/Makefile.in \
	  sched/status \
	  sched/stop \
	  sea/Makefile.in \
	  test/Makefile.in \
	  tools/Makefile.in \
	  zip/Makefile.in \
	  zip/unzip/Makefile.in \
	  zip/zip/Makefile.in \
	  Makefile.in \
	  aclocal.m4 \
	  config.h.in \
	  configure

clean-boinc-client:
	dh_testdir
	dh_testroot
	rm -f build-stamp-boinc-client
	dh_clean client/boinc_client.optimized

install: build
	dh_testdir
	dh_testroot
	dh_clean -k
	dh_installdirs
	
	$(MAKE) install DESTDIR=$(CURDIR)/debian/tmp
	
	dh_install
	
	#
	# boinc-manager
	#
	install -D debian/tmp/usr/bin/boinc_gui \
	  debian/boinc-manager/usr/bin/boincmgr
	
	for i in `ls locale/client`; do \
	  if [ -f "locale/client/$$i/BOINC Manager.mo" ]; then \
	    install -D -m644 "locale/client/$$i/BOINC Manager.mo" \
	      "debian/boinc-manager/usr/share/locale/$$i/LC_MESSAGES/BOINC Manager.mo"; \
	  fi; \
	done;
	
	#
	# boinc-dev
	#
	cd debian/boinc-dev/usr/share/boinc/api && \
	  ln -s ../../../include/boinc/api/* . && \
	  ln -s ../../../lib/boinc/api/* .
	
	cd debian/boinc-dev/usr/share/boinc/lib && \
	  ln -s ../../../include/boinc/lib/* . && \
	  ln -s ../../../lib/boinc/lib/* .

binary-indep: build install

binary-arch: build install
	dh_testdir -a
	dh_testroot
	dh_installchangelogs -a
	dh_installdocs -a
	dh_installmenu -pboinc-manager
	dh_desktop -pboinc-manager
	dh_installinit -a
	dh_installman -a
	dh_python -pboinc-server
	dh_link -a
	dh_strip -a
	dh_compress -a
	dh_fixperms -a
	dh_installdeb -a
	dh_shlibdeps -a
	dh_gencontrol -a
	dh_md5sums -a
	dh_builddeb -a

binary: binary-indep binary-arch
.PHONY: build clean binary-indep binary-arch binary install
