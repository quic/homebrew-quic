# Copyright (c) 2023, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

class Libepoxy < Formula
  desc "Library for handling OpenGL function pointer management"
  homepage "https://github.com/anholt/libepoxy"
  url "https://github.com/akihikodaki/libepoxy.git", revision: "ec54e0ff95dd98cd5d5c62b38d9ae427e4e6e747"
  version "20220529"
  license "MIT"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "quic/quic/angle"

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
