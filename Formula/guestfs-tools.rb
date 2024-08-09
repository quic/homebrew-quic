# Copyright (c) 2024, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

class GuestfsTools < Formula
  desc "Set of tools for accessing and modifying virtual machine (VM) disk images"
  homepage "https://libguestfs.org/"
  url "https://github.com/libguestfs/guestfs-tools.git", revision: "daf2b71e0ef18a04928f82688278673ad57d4c4b"
  version "1.53.2"
  license "GPL-2.0-or-later"

  depends_on "automake" => :build
  depends_on "autoconf" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "coreutils" => :build
  depends_on "gnu-getopt" => :build
  depends_on "bison" => :build
  depends_on "gpg2"
  depends_on "libosinfo"
  depends_on "quic/quic/libguestfs"

  patch :DATA

  def install
    system "autoreconf", "-i"
    system "./configure", *std_configure_args
    system "make", "-j#{ENV.make_jobs}"
    system "make", "install"
  end

  def caveats
    <<~EOS
      To use virt-builder you need to add the following to your profile:
      export VIRT_BUILDER_DIRS="#{HOMEBREW_PREFIX}/etc"
    EOS
  end
end

__END__
diff --git a/builder/sigchecker.ml b/builder/sigchecker.ml
index 343f0bae..d592d498 100644
--- a/builder/sigchecker.ml
+++ b/builder/sigchecker.ml
@@ -42,7 +42,7 @@ let import_keyfile ~gpg ~gpghome ~tmpdir ?(trust = true) keyfile =
     gpg gpghome (quote status_file) (quote keyfile)
     (if verbose () then "" else " >/dev/null 2>&1") in
   let r = shell_command cmd in
-  if r <> 0 then
+  if r <> 0 && r <> 2 then
     error (f_"could not import public key\n\
               Use the ‘-v’ option and look for earlier error messages.");
   let status = read_whole_file status_file in
@@ -110,7 +110,7 @@ let rec create ~gpg ~gpgkey ~check_signature ~tmpdir =
       let cmd = sprintf "%s --homedir %s --list-keys%s"
         gpg gpgtmpdir (if verbose () then "" else " >/dev/null 2>&1") in
       let r = shell_command cmd in
-      if r <> 0 then
+      if r <> 0 && r <> 2 then
         error (f_"GPG failure: could not run GPG the first time\n\
                   Use the ‘-v’ option and look for earlier error messages.");
       match gpgkey with
