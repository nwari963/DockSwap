class Dockswap < Formula
  desc "Save and switch macOS Dock presets"
  homepage "https://github.com/nwari963/dockswap"
  url "https://github.com/nwari963/dockswap/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "[SHA256_HERE]"
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
