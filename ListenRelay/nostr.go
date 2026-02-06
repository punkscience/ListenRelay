package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/dhowden/tag"
	"github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip19"
)

var defaultRelays = []string{
	"wss://relay.damus.io",
	"wss://nos.lol",
	"wss://relay.primal.net",
}

func PublishTrackToNostr(privateKey, template, artist, track, album, uri string) error {
	if privateKey == "" {
		return fmt.Errorf("no private key provided")
	}

	hexKey := privateKey
	if strings.HasPrefix(privateKey, "nsec") {
		_, data, err := nip19.Decode(privateKey)
		if err != nil {
			return fmt.Errorf("failed to decode nsec: %v", err)
		}
		var ok bool
		hexKey, ok = data.(string)
		if !ok {
			return fmt.Errorf("decoded nsec data is not a string")
		}
	}

	// 1. Get Public Key
	pub, err := nostr.GetPublicKey(hexKey)
	if err != nil {
		return fmt.Errorf("invalid private key: %v", err)
	}

	// 2. Prepare Content from Template
	if template == "" {
		template = "Currently listening to [Track] by [Artist] from the album [Album]."
	}
	content := template
	content = strings.ReplaceAll(content, "[Track]", track)
	content = strings.ReplaceAll(content, "[Artist]", artist)
	content = strings.ReplaceAll(content, "[Album]", album)

	// 3. Extract and Upload Album Art if URI is local file
	imageUrl := ""
	if uri != "" && strings.HasPrefix(uri, "file://") {
		localPath := uriToPath(uri)
		imgData, mimeType, err := extractAlbumArt(localPath)
		if err == nil && imgData != nil {
			imageUrl, err = uploadToVoidCat(imgData, mimeType, filepath.Base(localPath))
			if err != nil {
				log.Printf("Nostr: Image upload failed: %v", err)
			}
		} else if err != nil {
			log.Printf("Nostr: Album art extraction failed: %v", err)
		}
	}

	if imageUrl != "" {
		content += "\n" + imageUrl
	}
	content += "\n\n#nowplaying #music"

	ev := nostr.Event{
		PubKey:    pub,
		CreatedAt: nostr.Now(),
		Kind:      nostr.KindTextNote,
		Content:   content,
		Tags:      nostr.Tags{},
	}

	// 4. Sign Event
	if err := ev.Sign(hexKey); err != nil {
		return fmt.Errorf("failed to sign event: %v", err)
	}

	// 5. Publish to Relays
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	successCount := 0
	for _, url := range defaultRelays {
		relay, err := nostr.RelayConnect(ctx, url)
		if err != nil {
			log.Printf("Nostr: Failed to connect to %s: %v", url, err)
			continue
		}
		
		err = relay.Publish(ctx, ev)
		relay.Close()

		if err != nil {
			log.Printf("Nostr: Failed to publish to %s: %v", url, err)
		} else {
			log.Printf("Nostr: Published to %s", url)
			successCount++
		}
	}

	if successCount == 0 {
		return fmt.Errorf("failed to publish to any relay")
	}

	return nil
}

func uriToPath(uri string) string {
	// Simple file:// conversion for Windows/Unix
	p := strings.TrimPrefix(uri, "file://")
	if os.PathSeparator == '\\' && strings.HasPrefix(p, "/") {
		p = strings.TrimPrefix(p, "/")
	}
	// URL Unescape
	decoded, err := url.PathUnescape(p)
	if err == nil {
		return decoded
	}
	return p
}

func extractAlbumArt(filePath string) ([]byte, string, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, "", err
	}
	defer f.Close()

	m, err := tag.ReadFrom(f)
	if err != nil {
		return nil, "", err
	}

	pic := m.Picture()
	if pic == nil {
		return nil, "", nil
	}

	return pic.Data, pic.MIMEType, nil
}

func uploadToVoidCat(data []byte, mimeType, filename string) (string, error) {
	hasher := sha256.New()
	hasher.Write(data)
	sha256Hash := hex.EncodeToString(hasher.Sum(nil))

	req, err := http.NewRequest("POST", "https://void.cat/upload?cli=true", bytes.NewReader(data))
	if err != nil {
		return "", err
	}

	req.Header.Set("V-Content-Type", mimeType)
	req.Header.Set("V-Full-Digest", sha256Hash)
	req.Header.Set("V-Filename", filename)

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("void.cat status %s", resp.Status)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}

	return strings.TrimSpace(string(body)), nil
}