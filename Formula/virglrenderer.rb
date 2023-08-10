# Copyright (c) 2023, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

class Virglrenderer < Formula
  desc "Virtual 3D GPU library allowing a guest OS to use host GPU acceleration"
  homepage "https://gitlab.freedesktop.org/virgl/virglrenderer"
  url "https://gitlab.freedesktop.org/virgl/virglrenderer.git", revision: "88b9fe3bfc64b23a701e4875006dbc0e769f14f6"
  version "0.10.4"
  license "MIT"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "quic/quic/libepoxy"

  # Do not require libdrm
  patch :DATA

  def install
    mkdir "build" do
      system "meson", "setup", *std_meson_args, ".."
      system "ninja", "-v"
      system "ninja", "install", "-v"
    end
  end

  test do
    system "true"
  end
end

__END__
diff --git a/meson.build b/meson.build
index ddb74daa..373e4baf 100644
--- a/meson.build
+++ b/meson.build
@@ -66,7 +66,6 @@ add_project_arguments(cc.get_supported_arguments(flags), language : 'c')
 
 prog_python = import('python').find_installation('python3')
 
-libdrm_dep = dependency('libdrm', version : '>=2.4.50')
 thread_dep = dependency('threads')
 epoxy_dep = dependency('epoxy', version: '>= 1.5.4')
 m_dep = cc.find_library('m', required : false)
@@ -205,8 +204,9 @@ endif
 
 if with_egl
    if cc.has_header('epoxy/egl.h', dependencies: epoxy_dep) and epoxy_dep.get_pkgconfig_variable('epoxy_has_egl') == '1'
+      libdrm_dep = dependency('libdrm', required: require_egl, version : '>=2.4.50')
       gbm_dep = dependency('gbm', version: '>= ' + _gbm_ver, required: require_egl)
-      have_egl = gbm_dep.found()
+      have_egl = libdrm_dep.found() and gbm_dep.found()
       if (have_egl)
          conf_data.set('HAVE_EPOXY_EGL_H', 1)
       else
diff --git a/src/meson.build b/src/meson.build
index d78ac8c9..4a5b245c 100644
--- a/src/meson.build
+++ b/src/meson.build
@@ -171,7 +171,6 @@ video_sources = [
 virgl_depends = [
    gallium_dep,
    epoxy_dep,
-   libdrm_dep,
    thread_dep,
    m_dep,
 ]
@@ -188,7 +187,7 @@ virgl_sources += vrend_sources
 
 if have_egl
    virgl_sources += vrend_winsys_egl_sources
-   virgl_depends += [gbm_dep]
+   virgl_depends += [libdrm_dep, gbm_dep]
 endif
 
 if have_glx
diff --git a/src/vrend_winsys.c b/src/vrend_winsys.c
index 6a73b7fd..31c93b3c 100644
--- a/src/vrend_winsys.c
+++ b/src/vrend_winsys.c
@@ -22,6 +22,7 @@
  *
  **************************************************************************/
 
+#include "vrend_debug.h"
 #include "vrend_winsys.h"
 
 #ifdef HAVE_EPOXY_GLX_H
@@ -30,6 +31,8 @@
 
 #include <stddef.h>
 
+#include "util/macros.h"
+
 enum {
    CONTEXT_NONE,
    CONTEXT_EGL,
@@ -135,7 +138,7 @@ int vrend_winsys_init_external(void *egl_display)
    return 0;
 }
 
-virgl_renderer_gl_context vrend_winsys_create_context(struct virgl_gl_ctx_param *param)
+virgl_renderer_gl_context vrend_winsys_create_context(UNUSED struct virgl_gl_ctx_param *param)
 {
 #ifdef HAVE_EPOXY_EGL_H
    if (use_context == CONTEXT_EGL)
@@ -148,7 +151,7 @@ virgl_renderer_gl_context vrend_winsys_create_context(struct virgl_gl_ctx_param
    return NULL;
 }
 
-void vrend_winsys_destroy_context(virgl_renderer_gl_context ctx)
+void vrend_winsys_destroy_context(UNUSED virgl_renderer_gl_context ctx)
 {
 #ifdef HAVE_EPOXY_EGL_H
    if (use_context == CONTEXT_EGL) {
@@ -164,7 +167,7 @@ void vrend_winsys_destroy_context(virgl_renderer_gl_context ctx)
 #endif
 }
 
-int vrend_winsys_make_context_current(virgl_renderer_gl_context ctx)
+int vrend_winsys_make_context_current(UNUSED virgl_renderer_gl_context ctx)
 {
    int ret = -1;
 #ifdef HAVE_EPOXY_EGL_H
diff --git a/src/vrend_winsys_gbm.h b/src/vrend_winsys_gbm.h
index 84943fba..52b15444 100644
--- a/src/vrend_winsys_gbm.h
+++ b/src/vrend_winsys_gbm.h
@@ -25,7 +25,9 @@
 #ifndef VIRGL_GBM_H
 #define VIRGL_GBM_H
 
+#ifdef HAVE_EPOXY_EGL_H
 #include <gbm.h>
+#endif
 #include "vrend_iov.h"
 #include "virglrenderer.h"
 
@@ -101,6 +103,8 @@ struct virgl_gbm {
    struct gbm_device *device;
 };
 
+#ifdef HAVE_EPOXY_EGL_H
+
 struct virgl_gbm *virgl_gbm_init(int fd);
 
 void virgl_gbm_fini(struct virgl_gbm *gbm);
@@ -124,3 +128,5 @@ bool virgl_gbm_external_allocation_preferred(uint32_t flags);
 bool virgl_gbm_gpu_import_required(uint32_t flags);
 
 #endif
+
+#endif
