# ListenRelay (lbvlc) Context

This document provides a summary of the project for Gemini's context.

## Purpose
ListenRelay is a bridge between **VLC Media Player** and **Listenbrainz**. It consists of a VLC Lua extension and a Go-based sidecar application for Windows.

## Components
1.  **VLC Extension (`listenrelay.lua`)**:
    -   Monitors playback state and metadata in VLC.
    -   Sends HTTP POST requests to `http://127.0.0.1:19485/scrobble` with track info.
    -   Handles deduplication of tracks.

2.  **Go Sidecar (`ListenRelay/`)**:
    -   **HTTP Server**: Listens on port `19485`.
    -   **Listenbrainz API Client**: Submits listens to `api.listenbrainz.org`.
    -   **GUI/System Tray**: Built with the `walk` library for Windows. Allows configuration of the Listenbrainz token.
    -   **Configuration**: Stores user token in `%APPDATA%/ListenRelay/config.json`.

## Key Files
-   `listenrelay.lua`: The entry point for VLC.
-   `ListenRelay/main.go`: Entry point for the Go application and GUI setup.
-   `ListenRelay/server.go`: HTTP handler and Listenbrainz API logic.
-   `ListenRelay/config.go`: Configuration persistence logic.

## Technical Stack
-   **Lua**: VLC Extension API.
-   **Go**: Backend service, Windows GUI (`github.com/lxn/walk`).
-   **Listenbrainz API**: `submit-listens` endpoint.
