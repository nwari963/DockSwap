class Dockswap < Formula
  desc "Save and switch macOS Dock presets"
  homepage "https://github.com/nwari963/DockSwap"
  url "https://github.com/nwari963/DockSwap/archive/refs/tags/0.1.2.tar.gz"
  sha256 "46feab1bf87442c5b37df6a7eb58a4239d8d4e49bfb509d783219e7c3be299c7"
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
