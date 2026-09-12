class Dockswap < Formula
  desc "Save and switch macOS Dock presets"
  homepage "https://github.com/nwari963/DockSwap"
  url "https://github.com/nwari963/DockSwap/archive/refs/tags/0.1.1.tar.gz"
  sha256 "1bb56470b154a5a449668a140be179a6f8bc88faec337c179b630042c2ede65e"
  license "MIT"

  depends_on :macos
  depends_on "dockutil"

  def install
    system "swift", "build", "-c", "release"
    bin.install ".build/release/dockswap"
  end

  test do
    system "#{bin}/dockswap", "--version"
  end
end
