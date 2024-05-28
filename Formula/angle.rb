# Copyright (c) 2023-2024, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

class Angle < Formula
  desc "Almost Native Graphics Layer Engine"
  homepage "https://chromium.googlesource.com/angle/angle/"
  # We can not use the default git strategy as it would fail while pulling submodules.
  # So we get the archived sources, unfortunately the archived sources do not build...
  url "https://github.com/google/angle/archive/refs/heads/chromium/6503.zip", using: :nounzip
  sha256 "eeef0c09322c5b8bba28ed472a67b4f662bd2aa789b020213e614816fb26c898"
  version "chromium-6503"
  license "BSD-3-Clause"

  bottle do
    root_url "https://ghcr.io/v2/quic/quic"
    sha256 cellar: :any, arm64_sonoma: "f5e99a5c836e67668552409942beaff90e9cea3556e5bfa5b6154d46c023d205"
  end

  depends_on "python3" => :build
  depends_on "curl" => :build
  depends_on "git" => :build

  on_macos do
    # `gn gen` requires `xcodebuild` which is provided by a full regular Xcode
    depends_on :xcode => :build
  end

  resource "depot-tools" do
    url "https://chromium.googlesource.com/chromium/tools/depot_tools.git", revision: "97246c4f73e6692065ea4d3c87c63641a810f064"
  end

  def install
    resource("depot-tools").stage(buildpath/"depot-tools")
    ENV.append_path "PATH", "#{buildpath}/depot-tools"

    ENV["NO_AUTH_BOTO_CONFIG"] = ENV["HOMEBREW_NO_AUTH_BOTO_CONFIG"]

    # Make sure private libraries can be found from lib
    ENV.prepend "LDFLAGS", "-Wl,-rpath,#{rpath(target: libexec)}"

    puts "Downloading ANGLE and its dependencies."
    puts "This may take a while, based on your internet connection speed."
    # We clone angle from here to avoid brew default strategy of pulling submodules
    system "git", "clone", "https://github.com/google/angle.git", "--depth=1", "--single-branch", "--branch=chromium/6503"
    Dir.chdir("angle")
    system "curl", "https://raw.githubusercontent.com/quic/homebrew-quic/main/Patches/0001-gn-Add-install-target.patch",
        "--output", "0001-gn-Add-install-target.patch"
    system "git", "apply", "-v", "0001-gn-Add-install-target.patch"
    # Use -headerpad_max_install_names in the build,
    # otherwise updated load commands won't fit in the Mach-O header.
    system "curl", "https://raw.githubusercontent.com/quic/homebrew-quic/main/Patches/0002-gn-Headerpad-config.patch",
        "--output", "0002-gn-Headerpad-config.patch"
    system "git", "apply", "-v", "0002-gn-Headerpad-config.patch"

    # Start configuring ANGLE
    system "python3", "scripts/bootstrap.py"
    # This is responsible for pulling the submodules for us
    system "gclient", "sync", "--no-history", "--shallow", "-v"
    system "gn", "gen",
      "--args=use_custom_libcxx=false is_component_build=false install_prefix=\"#{prefix}\"",
      "./out"
    system "ninja", "-j", ENV.make_jobs, "-C", "out", "install_angle"
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
