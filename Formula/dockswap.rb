class Dockswap < Formula
  desc "Save and switch macOS Dock presets"
  homepage "https://github.com/nwari963/DockSwap"
  url "https://github.com/nwari963/DockSwap/archive/refs/tags/0.1.0.tar.gz"
  sha256 "2679eb99c96e7c99acd9c7a0907b4364d97b95e38bb0587b587a631a4c35c145"
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
