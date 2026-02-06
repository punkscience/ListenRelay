# Technical Specification: ListenRelay

## 1. Overview
ListenRelay is a decoupled scrobbling solution for VLC Media Player. It offloads the complexity of network retries, credential management, and API interactions from the limited Lua environment of VLC to a robust background service written in Go.

## 2. System Architecture

### 2.1. The Producer (VLC Lua Extension)
- **Responsibility**: Event detection and metadata extraction.
- **Triggers**: `input_changed`, `playing_changed`, `meta_changed`.
- **Communication**: Outbound HTTP POST via low-level TCP sockets (`vlc.net.connect_tcp`).
- **Data Format**: JSON payload containing `artist`, `track`, `album`, and `length`.

### 2.2. The Consumer (Go Sidecar)
- **Responsibility**: Authentication, state management, and API submission.
- **HTTP Server**: Localhost-only listener on `127.0.0.1:19485`.
- **API Integration**: Implements the Listenbrainz `single` listen submission protocol.
- **GUI Layer**: Windows-native System Tray application for user feedback and configuration.

## 3. Data Flow
1. VLC plays a track.
2. `listenrelay.lua` extracts metadata and verifies it is a "new" track.
3. Lua script sends a raw HTTP POST to the local Go service.
4. Go service validates the payload and checks for a configured User Token.
5. Go service asynchronously submits the listen to `https://api.listenbrainz.org/1/submit-listens`.
6. Go service updates the System Tray tooltip with the current scrobbling status.

## 4. Configuration & Storage
- **Location**: `%USERPROFILE%\AppData\Roaming\ListenRelay\config.json`.
- **Schema**:
  ```json
  {
    "user_token": "your-listenbrainz-token"
  }
  ```

## 5. Security Considerations
- **Localhost Bound**: The HTTP server binds strictly to `127.0.0.1` to prevent external access.
- **Token Handling**: Tokens are stored in plaintext in the user's config directory (standard for this class of desktop app).

## 6. Implementation Details
- **GUI Framework**: `lxn/walk` (Windows-only).
- **Service Port**: `19485` (Selected to avoid common conflicts).
- **Deduplication**: Handled in Lua to prevent flooding the sidecar with redundant metadata updates from VLC's internal state machine.
