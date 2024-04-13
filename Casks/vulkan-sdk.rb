# Copyright (c) 2024, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

cask "vulkan-sdk" do
  name "Vulkan SDK"
  desc "The Vulkan SDK enables Vulkan developers to develop Vulkan applications"
  homepage "https://vulkan.lunarg.com/sdk/home"
  url "https://sdk.lunarg.com/sdk/download/1.3.280.1/mac/vulkansdk-macos-1.3.280.1.dmg"
  sha256 "e6c3c33d011852b85b60ed610a0572573c1c0232b5ef0802a300a738ab9ff876"
  version "1.3.280.1"

  depends_on formula: "python3"

  installer script: {
    executable: "InstallVulkan.app/Contents/MacOS/InstallVulkan",
    args: [
      "--root", "#{staged_path}/#{token}", "--accept-licenses", "--default-answer",
      "--confirm-command", "install"
    ],
  }

  installer script: {
    executable: "#{HOMEBREW_PREFIX}/bin/python3",
    args: [
      "#{staged_path}/#{token}/install_vulkan.py",
      "--install-json-location",
      "#{staged_path}/#{token}"
    ],
    sudo: true,
  }

  uninstall script: {
    executable: "#{staged_path}/#{token}/uninstall.sh",
    sudo: true,
  }

  uninstall delete: [
    "#{staged_path}/#{token}"
  ]
end
