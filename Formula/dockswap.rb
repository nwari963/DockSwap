class Dockswap < Formula
  desc "Save and switch macOS Dock presets"
  homepage "https://github.com/nwari963/DockSwap"
  url "https://github.com/nwari963/DockSwap/archive/refs/tags/0.1.0.tar.gz"
  sha256 "[SHA256_HERE]" # filled in once the 0.1.0 tag exists
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
