# Copyright (c) 2024, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

class Libguestfs < Formula
  desc "Set of tools for accessing and modifying virtual machine (VM) disk images"
  homepage "https://libguestfs.org/"
  url "https://github.com/libguestfs/libguestfs.git", revision: "5b8b7baefd42e99bbb2628c2bcea4e993126ab94"
  version "1.53.4"
  license "LGPL-2.0-or-later"

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "coreutils" => :build
  depends_on "gnu-sed" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "augeas"
  depends_on "glib"
  depends_on "hivex"
  depends_on "jansson"
  depends_on "libmagic"
  depends_on "libvirt"
  depends_on "ocaml"
  depends_on "ocaml-findlib"
  depends_on "pcre2"
  depends_on "qemu"
  depends_on "readline"
  depends_on "xorriso"
  depends_on "xz"
  depends_on "zstd"

  # Download fixed appliance from libguestfs website
  resource "fixed-appliance" do
    url "https://download.libguestfs.org/binaries/appliance/appliance-1.53.4.tar.xz"
    sha256 "078836811e1936c9468c109c44b6e4b06b83114264c13b956761d2dbe790f6ed"
  end

  # ocaml: INSTALL_OCAMLLIB Makefile parameter
  # qemu: Add HVF to the accelerators list
  # configure: Use -map in script flags
  # lib: Fix environ on MacOS
  # build: Link libvirt-is-version with libgnu
  patch :DATA

  def install
    ENV.prepend_path "PATH", Formula["gnu-sed"].libexec/"gnubin" if OS.mac?

    system "autoreconf", "-i"

    args = [
      "--disable-dependency-tracking",
      "--disable-silent-rules",
      "--disable-probes",
      "--disable-appliance",
      "--disable-daemon",
      "--disable-lua",
      "--disable-haskell",
      "--disable-erlang",
      "--disable-gtk-doc-html",
      "--disable-gobject",
      "--disable-php",
      "--disable-perl",
      "--disable-golang",
      "--disable-python",
      "--disable-ruby",
    ]

    system "./configure", *std_configure_args, *args

    system "make", "-j#{ENV.make_jobs}"

    ENV["REALLY_INSTALL"] = "yes"
    system "make", "install", "INSTALL_OCAMLLIB=#{lib}/ocaml"
  end

  def post_install
    resource("fixed-appliance").stage(var/"appliance")
  end

  def caveats
    <<~EOS
      To use guestfs tools you need to add the following to your profile:
      export LIBGUESTFS_PATH="#{var}/appliance"
    EOS
  end

  test do
    ENV["LIBGUESTFS_PATH"] = "#{var}/appliance"
    system "#{bin}/libguestfs-test-tool", "-t 30"
  end
end

__END__
diff --git a/lib/Makefile.am b/lib/Makefile.am
index 4adf17ecd..0ed1576f8 100644
--- a/lib/Makefile.am
+++ b/lib/Makefile.am
@@ -178,10 +178,12 @@ libvirt_is_version_SOURCES = libvirt-is-version.c
 
 libvirt_is_version_LDADD = \
 	$(LIBVIRT_LIBS) \
-	$(LTLIBINTL)
+	$(LTLIBINTL) \
+	$(top_builddir)/gnulib/lib/.libs/libgnu.a
 
 libvirt_is_version_CPPFLAGS = \
-	-DLOCALEBASEDIR=\""$(datadir)/locale"\"
+	-DLOCALEBASEDIR=\""$(datadir)/locale"\" \
+	-I$(top_srcdir)/gnulib/lib -I$(top_builddir)/gnulib/lib
 
 libvirt_is_version_CFLAGS = \
 	$(WARN_CFLAGS) $(WERROR_CFLAGS) \
diff --git a/lib/guestfs-internal.h b/lib/guestfs-internal.h
index 57f0eb173..174ca135f 100644
--- a/lib/guestfs-internal.h
+++ b/lib/guestfs-internal.h
@@ -26,6 +26,11 @@
 #ifndef GUESTFS_INTERNAL_H_
 #define GUESTFS_INTERNAL_H_
 
+#ifdef __APPLE__
+#include <crt_externs.h>
+#define environ (*_NSGetEnviron())
+#endif // __APPLE__
+
 #include <stdbool.h>
 #include <assert.h>
 
diff --git a/lib/handle.c b/lib/handle.c
index f1f33e737..df8e4284f 100644
--- a/lib/handle.c
+++ b/lib/handle.c
@@ -27,6 +27,7 @@
 #include <stdlib.h>
 #include <string.h>
 #include <libintl.h>
+#include <errno.h>
 
 #include <libxml/parser.h>
 #include <libxml/xmlversion.h>
diff --git a/lib/qemu.c b/lib/qemu.c
index 71115a27e..027790e4e 100644
--- a/lib/qemu.c
+++ b/lib/qemu.c
@@ -309,7 +309,7 @@ test_qemu_devices (guestfs_h *g, struct qemu_data *data)
 #ifdef MACHINE_TYPE
                            MACHINE_TYPE ","
 #endif
-                           "accel=kvm:tcg");
+                           "accel=kvm:hvf:tcg");
   guestfs_int_cmd_add_arg (cmd, "-device");
   guestfs_int_cmd_add_arg (cmd, "?");
   guestfs_int_cmd_clear_capture_errors (cmd);
@@ -574,7 +574,7 @@ generic_qmp_test (guestfs_h *g, struct qemu_data *data,
 #ifdef MACHINE_TYPE
                                      MACHINE_TYPE ","
 #endif
-                                     "accel=kvm:tcg");
+                                     "accel=kvm:hvf:tcg");
   guestfs_int_cmd_add_string_unquoted (cmd, " -qmp stdio");
   guestfs_int_cmd_clear_capture_errors (cmd);
 
diff --git a/m4/guestfs-c.m4 b/m4/guestfs-c.m4
index c6d33183d..8035a9729 100644
--- a/m4/guestfs-c.m4
+++ b/m4/guestfs-c.m4
@@ -57,7 +57,7 @@ CFLAGS="$CFLAGS -fno-strict-overflow -Wno-strict-overflow"
 dnl Work out how to specify the linker script to the linker.
 VERSION_SCRIPT_FLAGS=-Wl,--version-script=
 `/usr/bin/ld --help 2>&1 | grep -- --version-script >/dev/null` || \
-    VERSION_SCRIPT_FLAGS="-Wl,-M -Wl,"
+    VERSION_SCRIPT_FLAGS="-Wl,-map -Wl,"
 AC_SUBST(VERSION_SCRIPT_FLAGS)
 
 dnl Use -fvisibility=hidden by default in the library.
diff --git a/m4/ocaml.m4 b/m4/ocaml.m4
index fddd6a0c2..91896f386 100644
--- a/m4/ocaml.m4
+++ b/m4/ocaml.m4
@@ -17,6 +17,9 @@ AC_DEFUN([AC_PROG_OCAML],
      OCAMLVERSION=`$OCAMLC -v | sed -n -e 's|.*version* *\(.*\)$|\1|p'`
      AC_MSG_RESULT([OCaml version is $OCAMLVERSION])
      OCAMLLIB=`$OCAMLC -where 2>/dev/null || $OCAMLC -v|tail -1|cut -d ' ' -f 4`
+     if test "x$INSTALL_OCAMLLIB" = "x"; then
+        INSTALL_OCAMLLIB=$OCAMLLIB
+     fi
      AC_MSG_RESULT([OCaml library path is $OCAMLLIB])
 
      AC_SUBST([OCAMLVERSION])
diff --git a/ocaml/Makefile.am b/ocaml/Makefile.am
index 63713ee68..f7621a8fa 100644
--- a/ocaml/Makefile.am
+++ b/ocaml/Makefile.am
@@ -185,16 +185,16 @@ data_hook_files += *.cmx *.cmxa
 endif
 
 install-data-hook:
-	mkdir -p $(DESTDIR)$(OCAMLLIB)
-	mkdir -p $(DESTDIR)$(OCAMLLIB)/stublibs
-	rm -rf $(DESTDIR)$(OCAMLLIB)/guestfs
-	rm -rf $(DESTDIR)$(OCAMLLIB)/stublibs/dllmlguestfs.so*
+	mkdir -p $(DESTDIR)$(INSTALL_OCAMLLIB)
+	mkdir -p $(DESTDIR)$(INSTALL_OCAMLLIB)/stublibs
+	rm -rf $(DESTDIR)$(INSTALL_OCAMLLIB)/guestfs
+	rm -rf $(DESTDIR)$(INSTALL_OCAMLLIB)/stublibs/dllmlguestfs.so*
 	$(OCAMLFIND) install \
-	  -ldconf ignore -destdir $(DESTDIR)$(OCAMLLIB) \
+	  -ldconf ignore -destdir $(DESTDIR)$(INSTALL_OCAMLLIB) \
 	  guestfs \
 	  $(data_hook_files)
-	rm -f $(DESTDIR)$(OCAMLLIB)/guestfs/bindtests.*
-	rm $(DESTDIR)$(OCAMLLIB)/guestfs/libguestfsocaml.a
+	rm -f $(DESTDIR)$(INSTALL_OCAMLLIB)/guestfs/bindtests.*
+	rm $(DESTDIR)$(INSTALL_OCAMLLIB)/guestfs/libguestfsocaml.a
 
 CLEANFILES += $(noinst_DATA) $(check_DATA)
 
