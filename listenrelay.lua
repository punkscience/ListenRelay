-- ListenRelay: VLC Extension for Listenbrainz (via Go Sidecar)
-- Author: Darryl G. Wright

function descriptor()
    return {
        title = "ListenRelay",
        version = "1.0",
        author = "Punk Science Studios Inc.",
        url = "https://github.com/punkscience/ListenRelay",
        shortdesc = "Submit listens to Listenbrainz via ListenRelay",
        description = "Sends track metadata to a local Go service which handles the Listenbrainz submission.",
        capabilities = {"input-listener", "playing-listener", "meta-listener"}
    }
end

local last_artist = nil
local last_title = nil

function activate()
    vlc.msg.info("[ListenRelay] Activated")
    -- Send a test scrobble to verify connection immediately
    -- send_scrobble("Connectivity", "Test", "Debug", 100)
end

function deactivate()
    vlc.msg.info("[ListenRelay] Deactivated")
end

function close()
    vlc.msg.info("[ListenRelay] Closed")
    deactivate()
end

function input_changed()
    vlc.msg.dbg("[ListenRelay] Input changed")
    -- Reset state on input change
    last_artist = nil
    last_title = nil
end

function playing_changed()
    vlc.msg.dbg("[ListenRelay] Playing status: " .. vlc.playlist.status())
    process_metadata()
end

function meta_changed()
    vlc.msg.dbg("[ListenRelay] Metadata changed")
    process_metadata()
end

function process_metadata()
    local status = vlc.playlist.status()
    vlc.msg.info("[ListenRelay] Debug: Playlist status is '" .. tostring(status) .. "'")

    if status ~= "playing" then 
        vlc.msg.info("[ListenRelay] Debug: Not playing, ignoring.")
        return 
    end
    
    -- vlc.item is often for playlist scripts. Extensions use vlc.input.item()
    local item = vlc.input.item()
    if not item then 
        -- Fallback check just in case
        item = vlc.item
    end

    if not item then 
        vlc.msg.info("[ListenRelay] Debug: No vlc.input.item() or vlc.item found.")
        return 
    end
    
    local metas = item:metas()
    if not metas then 
        vlc.msg.info("[ListenRelay] Debug: No metadata found for item.")
        return 
    end
    
    local artist = metas["artist"]
    local title = metas["title"]
    local album = metas["album"]
    local duration = item:duration()
    local uri = item:uri()

    vlc.msg.info("[ListenRelay] Debug: Found Metadata - Artist: '" .. tostring(artist) .. "', Title: '" .. tostring(title) .. "', URI: '" .. tostring(uri) .. "'")

    if not artist or not title then
        vlc.msg.info("[ListenRelay] Debug: Missing artist or title, ignoring.")
        return
    end

    -- Deduplication: Only send if track info changed
    if artist ~= last_artist or title ~= last_title then
        vlc.msg.info("[ListenRelay] Debug: New track detected. Previous was '" .. tostring(last_artist) .. " - " .. tostring(last_title) .. "'")
        last_artist = artist
        last_title = title
        vlc.msg.info("[ListenRelay] Detect: " .. artist .. " - " .. title)
        send_scrobble(artist, title, album, duration, uri)
    else
        vlc.msg.info("[ListenRelay] Debug: Duplicate track ignored.")
    end
end

function send_scrobble(artist, title, album, duration, uri)
    -- JSON Escape function
    local function json_escape(str)
        if not str then return "" end
        str = string.gsub(str, '\\', '\\\\')
        str = string.gsub(str, '"', '\\"')
        str = string.gsub(str, '\n', '\\n')
        str = string.gsub(str, '\r', '\\r')
        return str
    end

    local json_body = string.format(
        '{"artist": "%s", "track": "%s", "album": "%s", "length": %d, "uri": "%s"}',
        json_escape(artist),
        json_escape(title),
        json_escape(album or ""),
        math.floor(duration or 0),
        json_escape(uri or "")
    )

    local host = "127.0.0.1"
    local port = 19485
    local path = "/scrobble"
    
    -- Construct HTTP POST Request
    local request = "POST " .. path .. " HTTP/1.1\r\n" ..
                    "Host: " .. host .. ":" .. port .. "\r\n" ..
                    "Content-Type: application/json\r\n" ..
                    "Content-Length: " .. string.len(json_body) .. "\r\n" ..
                    "Connection: close\r\n" ..
                    "\r\n" ..
                    json_body

    vlc.msg.dbg("[ListenRelay] Sending Request to " .. host .. ":" .. port)

    -- Use vlc.net.connect_tcp
    local fd = vlc.net.connect_tcp(host, port)
    if fd >= 0 then
        -- poll not always available or needed for simple blocking send/close? 
        -- vlc.net.send is not exposed in all versions, we might need write. 
        -- Actually, vlc.net.write functionality is often just using the fd.
        -- Wait, the VLC Lua API for 'net' is low level.
        -- 'vlc.net.send(fd, data)' or 'vlc.net.write(fd, data)'
        
        -- Let's check common usage. 
        -- Some instances use `vlc.net.write(fd, request)`
        -- Others use `net.send(fd, request)`
        
        -- Based on documented VLC Lua API (README.txt in lua/):
        -- "vlc.net.send( fd, string, [length] )"
        
        vlc.net.send(fd, request)
        vlc.net.close(fd)
        vlc.msg.info("[ListenRelay] Sent scrobble data for " .. title)
    else
        vlc.msg.err("[ListenRelay] Failed to connect to ListenRelay Go Service at " .. host .. ":" .. port)
    end
end
