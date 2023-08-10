# Copyright (c) 2023, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

class Sdl2 < Formula
  desc "Low-level access to audio, keyboard, mouse, joystick, and graphics"
  homepage "https://github.com/libsdl-org/SDL"
  url "https://github.com/libsdl-org/SDL.git", revision: "adf31f6ec0be0f9ba562889398f71172c7941023"
  version "2.26.3"
  license "Zlib"

  depends_on "cmake" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "quic/quic/libepoxy"

  # Cocoa GLES: do not unload EGL when context is destroy
  patch :DATA

  def install
    mkdir "build" do
      system "cmake", "-S..", "-B.", "-GNinja", *std_cmake_args
      system "ninja", "-v"
      system "ninja", "install", "-v"
    end
  end

  test do
    assert_match "2.26.3", shell_output("#{bin}/sdl2-config --version 2>&1")
  end
end

__END__
diff --git a/src/video/cocoa/SDL_cocoaopengles.m b/src/video/cocoa/SDL_cocoaopengles.m
index 3efcb4756..2dffe7d99 100644
--- a/src/video/cocoa/SDL_cocoaopengles.m
+++ b/src/video/cocoa/SDL_cocoaopengles.m
@@ -95,7 +95,6 @@ Cocoa_GLES_DeleteContext(_THIS, SDL_GLContext context)
 { @autoreleasepool
 {
     SDL_EGL_DeleteContext(_this, context);
-    Cocoa_GLES_UnloadLibrary(_this);
 }}
 
 int
