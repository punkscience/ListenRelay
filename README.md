# ListenRelay: VLC Listenbrainz Plugin

ListenRelay connects VLC Media Player to Listenbrainz using a lightweight Lua extension and a robust background Go application.

## Prerequisites
-   **VLC Media Player** (Installed)
-   **Listenbrainz User Token** (Get it from your [Listenbrainz Profile](https://listenbrainz.org/profile/))

## Installation

### 1. Install the ListenRelay App
1.  Navigate to the `ListenRelay` folder.
2.  (Optional) If you have not built it yet, run: `go build -ldflags -H=windowsgui -o ListenRelay.exe`
3.  Ensure `ListenRelay.exe.manifest` is in the same folder as `ListenRelay.exe` (this is required for visual styling).
4.  Double-click **`ListenRelay.exe`** to start it.
    -   You will see an icon in your System Tray (near the clock).
5.  Right-click the tray icon and select **Settings**.
6.  Paste your **Listenbrainz User Token** and click **Save**.

> [!TIP]
> To ensure your listens are always tracked, add `ListenRelay.exe` to your Windows Startup folder (Win+R -> `shell:startup`).

### 2. Install the VLC Extension
1.  Locate the file **`listenrelay.lua`** in the project root.
2.  Copy this file to your VLC Lua Extensions directory:
    -   **Windows**: `%APPDATA%\vlc\lua\extensions\`
        -   (e.g., `C:\Users\YourName\AppData\Roaming\vlc\lua\extensions\`)
    -   *Note*: You may need to create the `lua` and `extensions` folders if they don't exist.

### 3. Verify
1.  Restart VLC Media Player (if it was open).
2.  Play a music track.
3.  Check the **View** menu in VLC to ensure "ListenRelay" is listed (though you don't need to click it, it runs automatically).
4.  Check your Listenbrainz profile to see the "Listening Now" status or submitted track.

## Troubleshooting
-   **Logs**: Check `ListenRelay` logs (if running from a console) or VLC's Messages window (`Ctrl+M`, set verbosity to 2).
-   **Connection Error**: Ensure `ListenRelay.exe` is running in the background. The VLC script tries to connect to `localhost:19485`.
