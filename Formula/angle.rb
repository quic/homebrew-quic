# Copyright (c) 2023-2024, Qualcomm Innovation Center, Inc. All rights reserved.
  # We can not use the default git strategy as it would fail while pulling submodules.
  # So we get the archived sources, unfortunately the archived sources do not build...
  url "https://github.com/google/angle/archive/refs/heads/chromium/6503.zip", using: :nounzip
  sha256 "eeef0c09322c5b8bba28ed472a67b4f662bd2aa789b020213e614816fb26c898"
  version "chromium-6503"
    sha256 cellar: :any, arm64_sonoma: "f5e99a5c836e67668552409942beaff90e9cea3556e5bfa5b6154d46c023d205"
  depends_on "python3" => :build
  depends_on "curl" => :build
  depends_on "git" => :build
  resource "depot-tools" do
    url "https://chromium.googlesource.com/chromium/tools/depot_tools.git", revision: "97246c4f73e6692065ea4d3c87c63641a810f064"
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