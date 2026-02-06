$body = @{
    artist = "Debug Artist"
    track  = "Debug Track"
    album  = "Debug Album"
    length = 300
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:19485/scrobble" -Method Post -Body $body -ContentType "application/json"
