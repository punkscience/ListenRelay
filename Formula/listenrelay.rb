class Listenrelay < Formula
  desc "Bridge between VLC and Listenbrainz with Nostr support"
  homepage "https://github.com/punkscience/listenrelay"
  version "1.0.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/punkscience/listenrelay/releases/download/v1.0.0/listenrelay-macos-amd64.tar.gz"
      sha256 "REPLACE_WITH_AMD64_SHA256"
    else
      url "https://github.com/punkscience/listenrelay/releases/download/v1.0.0/listenrelay-macos-arm64.tar.gz"
      sha256 "REPLACE_WITH_ARM64_SHA256"
    end
  end

  on_linux do
    url "https://github.com/punkscience/listenrelay/releases/download/v1.0.0/listenrelay-linux-amd64.tar.gz"
    sha256 "REPLACE_WITH_LINUX_SHA256"
  end

  def install
    bin.install "listenrelay"
    pkgshare.install "listenrelay.lua"
  end

  def caveats
    <<~EOS
      ListenRelay is now installed!
      
      To complete the setup:
      1. Install the VLC extension by symlinking it:
         mkdir -p ~/Library/Application\\ Support/org.videolan.vlc/lua/extensions/
         ln -s #{opt_pkgshare}/listenrelay.lua ~/Library/Application\\ Support/org.videolan.vlc/lua/extensions/
      
      2. Start the background service:
         listenrelay &
    EOS
  end
end