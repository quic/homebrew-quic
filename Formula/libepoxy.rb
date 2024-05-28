# Copyright (c) 2023-2024, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

class Libepoxy < Formula
  desc "Library for handling OpenGL function pointer management"
  homepage "https://github.com/anholt/libepoxy"
  url "https://github.com/akihikodaki/libepoxy.git", revision: "b0d6d609d64dcf71845801233d1d3680b9d50288"
  version "20240320"
  license "MIT"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "quic/quic/angle"

  bottle do
    root_url "https://ghcr.io/v2/quic/quic"
    sha256 cellar: :any, arm64_sonoma: "7d90d9818f893a74f854c48cb53317942fea84dcc737a1c1a9c0e12259aa0274"
  end

  def install
    mkdir "build" do
      system "meson", "setup", *std_meson_args, "-Degl=yes", "-Dx11=false", ".."
      system "ninja", "-v"
      system "ninja", "install", "-v"
    end
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <epoxy/egl.h>
      #include <epoxy/gl.h>
      #include <stdio.h>

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

    system ENV.cc, "test.c", "-L#{lib}", "-lepoxy", "-Wl,-rpath,#{HOMEBREW_PREFIX}/lib", "-o", "test", "-v"
    assert_match "ANGLE", shell_output("#{testpath}/test 2>&1")
  end
end

__END__
diff --git a/meson.build b/meson.build
index c5a589b..d0422ec 100644
--- a/meson.build
+++ b/meson.build
@@ -179,7 +179,7 @@ egl_dep = dependency('egl', required: false)
 if not egl_dep.found()
   egl_dep = cc.find_library('EGL', required: false)
 endif
-if not egl_dep.found() and host_machine == 'windows'
+if not egl_dep.found() and host_machine.system() == 'windows'
   egl_dep = cc.find_library('libEGL.dll', required: false)
 endif
 if not egl_dep.found()
@@ -190,7 +190,7 @@ gles2_dep = dependency('glesv2', required: false)
 if not gles2_dep.found()
   gles2_dep = cc.find_library('GLESv2', required: false)
 endif
-if not gles2_dep.found() and host_machine == 'windows'
+if not gles2_dep.found() and host_machine.system() == 'windows'
   gles2_dep = cc.find_library('libGLESv2.dll', required: false)
 endif
 if not gles2_dep.found()
@@ -201,7 +201,7 @@ gles1_dep = dependency('glesv1_cm', required: false)
 if not gles1_dep.found()
   gles1_dep = cc.find_library('GLESv1_CM', required: false)
 endif
-if not gles1_dep.found() and host_machine == 'windows'
+if not gles1_dep.found() and host_machine.system() == 'windows'
   gles1_dep = cc.find_library('libGLESv1_CM.dll', required: false)
 endif
