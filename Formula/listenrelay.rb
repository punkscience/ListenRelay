class Listenrelay < Formula
  desc "Bridge between VLC and Listenbrainz with Nostr support"
  homepage "https://github.com/punkscience/listenrelay"
  version "1.0.0"

  on_macos do
    if Hardware::CPU.intel?
      url "https://github.com/punkscience/listenrelay/releases/download/v1.0.0/listenrelay-macos-amd64.tar.gz"
      sha256 "3022b95cbc859d38f7d51b9038ce3aa4f186af4d236787779d04a35c9f141b35"
    else
      url "https://github.com/punkscience/listenrelay/releases/download/v1.0.0/listenrelay-macos-arm64.tar.gz"
      sha256 "0fda4e5afdb4be4cf16483ae5977b57ae577d2ca9b77ff48bb215a558426119f"
    end
  end

  on_linux do
    url "https://github.com/punkscience/listenrelay/releases/download/v1.0.0/listenrelay-linux-amd64.tar.gz"
    sha256 "8cb6dde615e9e046d8b16e120beb56473b0ec33a7a3c0aa68f15bcc203ceb148"
  end

  def install
    bin.install "listenrelay"
    pkgshare.install "listenrelay.lua"
  end

  def post_install
    return unless OS.mac?

    vlc_ext_dir = File.expand_path("~/Library/Application Support/org.videolan.vlc/lua/extensions/")
    FileUtils.mkdir_p(vlc_ext_dir)
    
    begin
      FileUtils.ln_sf(opt_pkgshare/"listenrelay.lua", vlc_ext_dir/"listenrelay.lua")
      ohai "Successfully symlinked VLC extension to #{vlc_ext_dir}"
    rescue
      opoo "Could not symlink VLC extension. Please do it manually."
    end
  end

  def caveats
    <<~EOS
      ListenRelay is now installed!
      
      To complete the setup:
      1. Start the background service:
         listenrelay &
      
      2. The VLC extension should have been linked automatically. 
         If not, you can link it manually:
         ln -s #{opt_pkgshare}/listenrelay.lua ~/Library/Application\\ Support/org.videolan.vlc/lua/extensions/
    EOS
  end
end
