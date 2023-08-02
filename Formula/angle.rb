# Copyright (c) 2023, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

class Angle < Formula
  desc "Almost Native Graphics Layer Engine"
  homepage "https://chromium.googlesource.com/angle/angle/"
  url "https://chromium.googlesource.com/angle/angle.git", revision: "db3b2875723b255fbf4569f6346e9bd6d1cac78e"
  version "chromium-5682"
  license "BSD-3-Clause"

  depends_on "python3"

  on_macos do
    # `gn gen` requires `xcodebuild` which is provided by a full regular Xcode
    depends_on :xcode => :build
  end

  resource "depot_tools" do
    url "https://chromium.googlesource.com/chromium/tools/depot_tools.git", revision: "4a7343007c7c6f45124eb4e01f8a4fddaec79a11"
  end

  # gn: Add install target
  patch :DATA

  def install
    resource("depot_tools").stage do
      puts "Using depot_tools in " + Dir.pwd
      path = PATH.new(ENV["PATH"], Dir.pwd)
      no_auth_boto_config = ENV["HOMEBREW_NO_AUTH_BOTO_CONFIG"]
      with_env(PATH: path, NO_AUTH_BOTO_CONFIG: no_auth_boto_config) do
        Dir.chdir(buildpath)
        system "python3", "scripts/bootstrap.py"
        system "gclient", "sync"
        system "gn",
          "gen",
          "--args=use_custom_libcxx=false is_component_build=false install_prefix=\"#{prefix}\"",
          "./out"
        system "ninja", "-C", "out", "install_angle"
      end
    end
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <EGL/egl.h>
      #include <GLES2/gl2.h>
      #include <stdio.h>

      // Do not reorder
      #include <EGL/eglext.h>

      #define CHECK_TRUE(CALL, MSG)        \
        {                                  \
          EGLBoolean result = CALL;        \
          if (result != EGL_TRUE) {        \
            fprintf(stderr, "%s\\n", MSG); \
            return 1;                      \
          }                                \
        }

      #define CHECK_VALID(PTR, MSG)      \
        if (PTR == NULL) {               \
          fprintf(stderr, "%s\\n", MSG); \
          return 1;                      \
        }

      int main(int argc, char **argv) {
        EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        CHECK_VALID(display, "Failed to get EGL default display");

        CHECK_TRUE(eglInitialize(display, NULL, NULL), "Failed to initialize EGL");

        EGLint config_attribs[] = {EGL_SURFACE_TYPE,
                                   EGL_PBUFFER_BIT,
                                   EGL_RED_SIZE,
                                   1,
                                   EGL_GREEN_SIZE,
                                   1,
                                   EGL_BLUE_SIZE,
                                   1,
                                   EGL_ALPHA_SIZE,
                                   1,
                                   EGL_RENDERABLE_TYPE,
                                   EGL_OPENGL_ES2_BIT,
                                   EGL_NONE};

        EGLint num_configs;
        EGLConfig egl_config;
        CHECK_TRUE(
          eglChooseConfig(display, config_attribs, &egl_config, 1, &num_configs),
          "Failed to choose EGL config");
        if (num_configs != 1 || egl_config == EGL_NO_CONFIG_KHR) {
          fprintf(stderr, "No EGL config found\\n");
          return 1;
        }

        EGLint pbuffer_attribs[] = {
          EGL_WIDTH, 512, EGL_HEIGHT, 512, EGL_NONE,
        };
        EGLSurface surface =
          eglCreatePbufferSurface(display, egl_config, pbuffer_attribs);
        CHECK_VALID(surface, "Failed to create EGL Surface");

        CHECK_TRUE(eglBindAPI(EGL_OPENGL_ES_API), "Failed to bind OpenGL ES API");

        EGLint context_attribs[] = {EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE};
        EGLContext context =
          eglCreateContext(display, egl_config, EGL_NO_CONTEXT, context_attribs);
        CHECK_VALID(context, "Failed to create EGL Context");

        CHECK_TRUE(eglMakeCurrent(display, NULL, NULL, context),
                   "Failed to make EGL context current");

        const GLubyte *renderer = glGetString(GL_RENDERER);
        printf("%s\\n", renderer);

        return 0;
      }
    EOS

    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lEGL", "-lGLESv2", "-o", "test", "-v"
    assert_match "ANGLE", shell_output("#{testpath}/test 2>&1")
  end
end

__END__
diff --git a/BUILD.gn b/BUILD.gn
index 8da4a02ce..d8ed82318 100644
--- a/BUILD.gn
+++ b/BUILD.gn
@@ -74,6 +74,9 @@ declare_args() {
     # Use Android TLS slot to store current context.
     angle_use_android_tls_slot = !build_with_chromium
   }
+
+  # Prefix where the artifacts should be installed on the system
+  install_prefix = ""
 }
 
 if (angle_build_all) {
@@ -1787,3 +1790,51 @@ group("angle_static") {
     ":translator",
   ]
 }
+
+template("install_target") {
+  install_deps = []
+
+  foreach(_lib, invoker.libs) {
+    install_deps += [ ":install_${_lib}" ]
+
+    source = "${root_build_dir}/${_lib}${angle_libs_suffix}${shlib_extension}"
+
+    action("install_${_lib}") {
+      deps = [ ":${_lib}" ]
+      script = "scripts/install_target.py"
+      sources = [ source ]
+      # This is a trick to rerun this target every time
+      outputs = [ "${root_build_dir}/out/install_${_lib}.stamp" ]
+      args = [
+        "--name", _lib,
+        "--prefix", "$install_prefix",
+        "--libs", rebase_path(source),
+      ]
+    }
+  }
+
+  install_deps += [ ":install_includes" ]
+  action("install_includes") {
+    script = "scripts/install_target.py"
+    configs = invoker.configs
+    # This is a trick to rerun this target every time
+    outputs = [ "${root_build_dir}/out/install_${target_name}.stamp" ]
+    args = [
+      "--prefix", "$install_prefix",
+      "{{include_dirs}}"
+    ]
+  }
+
+  group("install_${target_name}") {
+    deps = install_deps
+  }
+}
+
+install_target("angle") {
+  libs = [
+    "libEGL",
+    #"libGLESv1_CM",
+    "libGLESv2"
+  ]
+  configs = [ ":includes_config" ]
+}
diff --git a/scripts/install_target.py b/scripts/install_target.py
new file mode 100755
index 000000000..28cadb0c6
--- /dev/null
+++ b/scripts/install_target.py
@@ -0,0 +1,127 @@
+#! /usr/bin/env python3
+# Copyright 2023 Google Inc.  All rights reserved.
+# Use of this source code is governed by a BSD-style license that can be
+# found in the LICENSE file.
+"""Install script for ANGLE targets"""
+
+import argparse
+import os
+import shutil
+import sys
+from pathlib import Path
+
+def install2(src_list: list, dst_dir: str):
+    """Installs a list of files or directories in `src_list` to the `install_dst_dir`"""
+    if not os.path.exists(dst_dir):
+        os.makedirs(dst_dir)
+    for src in src_list:
+        if not os.path.exists(src):
+            raise FileNotFoundError("Failed to find {}".format(src))
+        basename = os.path.basename(src)
+        dst = os.path.join(dst_dir, basename)
+        print("Installing {} to {}".format(src, dst))
+        if os.path.isdir(src):
+            shutil.copytree(src, dst, dirs_exist_ok=True)
+        else:
+            shutil.copy2(src, dst)
+
+PC_TEMPLATE = """prefix={prefix}
+libdir=${{prefix}}/lib
+includedir=${{prefix}}/include
+
+Name: {name}
+Description: {description}
+Version: {version}
+Libs: -L${{libdir}} {link_libraries}
+Cflags: -I${{includedir}}
+"""
+
+def gen_link_libraries(libs: list):
+    """Generates a string that can be used for the `Libs:` entry of a pkgconfig file"""
+    link_libraries = ""
+    for lib in libs:
+        # Absolute paths to file names only -> libEGL.dylib
+        basename = os.path.basename(lib)
+        # lib name only -> libEGL
+        libname: str = os.path.splitext(basename)[0]
+        # name only -> EGL
+        name = libname.strip('lib')
+        link_libraries += '-l{}'.format(name)
+    return link_libraries
+
+def gen_pkgconfig(name: str, version: str, prefix: os.path.abspath, libs: list):
+    """Generates a pkgconfig file for the current target""" 
+    # Remove lib from name -> EGL
+    no_lib_name = name.strip('lib')
+    description = "ANGLE's {}".format(no_lib_name)
+    name_lowercase = no_lib_name.lower()
+    link_libraries = gen_link_libraries(libs)
+    pc_content = PC_TEMPLATE.format(
+        name=name_lowercase,
+        prefix=prefix,
+        description=description,
+        version=version,
+        link_libraries=link_libraries)
+    
+    lib_pkgconfig_path = os.path.join(prefix, 'lib/pkgconfig')
+    if not os.path.exists(lib_pkgconfig_path):
+        os.makedirs(lib_pkgconfig_path)
+
+    pc_path = os.path.join(lib_pkgconfig_path, '{}.pc'.format(name_lowercase))
+    print("Generating {}".format(pc_path))
+    with open(pc_path, 'w+') as pc_file:
+        pc_file.write(pc_content)
+
+def install(name, version, prefix: os.path.abspath, libs: list, includes: list):
+    """Installs under `prefix`
+    - the libraries in the `libs` list
+    - the include directories in the `includes` list
+    - the pkgconfig file for current target if name is set"""
+    install2(libs, os.path.join(prefix, "lib"))
+
+    for include in includes:
+        assert(os.path.isdir(include))
+        incs = [inc.path for inc in os.scandir(include)]
+        install2(incs, os.path.join(prefix, "include"))
+
+    if name:
+        gen_pkgconfig(name, version, prefix, libs)
+
+def main():
+    parser = argparse.ArgumentParser(description='Install script for ANGLE targets')
+    parser.add_argument(
+        '--name',
+        help='Name of the target (e.g., EGL or GLESv2). Set it to generate a pkgconfig file',
+    )
+    parser.add_argument(
+        '--version',
+        help='SemVer of the target (e.g., 0.1.0 or 2.1)',
+        default= '0.0.0'
+    )
+    parser.add_argument(
+        '--prefix',
+        help='Install prefix to use (e.g., out/install or /usr/local/)',
+        default='',
+        type=os.path.abspath
+    )
+    parser.add_argument(
+        '--libs',
+        help='List of libraries to install (e.g., libEGL.dylib or libGLESv2.so)',
+        default=[],
+        nargs='+',
+        type=os.path.abspath
+    )
+    parser.add_argument(
+        '-I',
+        '--includes',
+        help='List of include directories to install (e.g., include or ../include)',
+        default=[],
+        nargs='+',
+        type=os.path.abspath
+    )
+
+    args = parser.parse_args()
+    install(args.name, args.version, args.prefix, args.libs, args.includes)
+
+if __name__ == '__main__':
+    sys.exit(main())
