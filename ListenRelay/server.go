package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

type ScrobbleRequest struct {
	Artist string `json:"artist"`
	Track  string `json:"track"`
	Album  string `json:"album"`
	Length int    `json:"length"` // Duration in seconds
}

type ListenPayload struct {
	ListenType string          `json:"listen_type"`
	Payload    []ListenDetails `json:"payload"`
}

type ListenDetails struct {
	TrackMetadata TrackMetadata `json:"track_metadata"`
	ListenedAt    int64         `json:"listened_at"`
}

type TrackMetadata struct {
	ArtistName  string `json:"artist_name"`
	TrackName   string `json:"track_name"`
	ReleaseName string `json:"release_name,omitempty"`
}

var currentToken string
var OnTrackReceived func(artist, track, album string)

func UpdateToken(token string) {
	currentToken = token
}

func StartServer() {
	http.HandleFunc("/scrobble", handleScrobble)
	log.Println("Server listening on :19485")
	if err := http.ListenAndServe(":19485", nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}

func handleScrobble(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if currentToken == "" {
		log.Println("Error: No User Token configured")
		http.Error(w, "User Token not configured", http.StatusUnauthorized)
		return
	}

	var req ScrobbleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate basic requirements
	if req.Artist == "" || req.Track == "" {
		http.Error(w, "Missing artist or track", http.StatusBadRequest)
		return
	}

	// Update GUI if callback is registered
	if OnTrackReceived != nil {
		OnTrackReceived(req.Artist, req.Track, req.Album)
	}

	// Basic Validation logic to match Listenbrainz rules (can be expanded)
	// "A track should only be submitted as a listen if the user has listened to at least half the track or four minutes of it"
	// The Lua script sends this event when the track parses 'done' or similar logic, assuming validity.
	// For now, we trust the client (Lua script) to send valid 'listens'.

	go submitListen(req) // Process in background

	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "Scrobble received")
}

func submitListen(req ScrobbleRequest) {
	data := ListenPayload{
		ListenType: "single",
		Payload: []ListenDetails{
			{
				TrackMetadata: TrackMetadata{
					ArtistName:  req.Artist,
					TrackName:   req.Track,
					ReleaseName: req.Album,
				},
				ListenedAt: time.Now().Unix(),
			},
		},
	}

	payloadBytes, err := json.Marshal(data)
	if err != nil {
		log.Printf("Error marshalling payload: %v", err)
		return
	}

	client := &http.Client{Timeout: 10 * time.Second}
	lbReq, err := http.NewRequest("POST", "https://api.listenbrainz.org/1/submit-listens", bytes.NewBuffer(payloadBytes))
	if err != nil {
		log.Printf("Error creating request: %v", err)
		return
	}

	lbReq.Header.Set("Authorization", "Token "+currentToken)
	lbReq.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(lbReq)
	if err != nil {
		log.Printf("Error submitting listen: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Printf("Listenbrainz API returned error: %s", resp.Status)
		// You might want to read the body here for more details
		buf := new(bytes.Buffer)
		buf.ReadFrom(resp.Body)
		log.Printf("Response body: %s", buf.String())
	} else {
		log.Printf("Successfully scrobbled: %s - %s", req.Artist, req.Track)
	}
}
