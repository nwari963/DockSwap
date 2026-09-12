class Dockswap < Formula
  desc "Save and switch macOS Dock presets"
  homepage "https://github.com/nwari963/DockSwap"
  url "https://github.com/nwari963/DockSwap/archive/refs/tags/0.1.3.tar.gz"
  sha256 "191e2a4c59d20b77a8cbc828bee94f66eac620776831be14c66f2477e0aac869"
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
