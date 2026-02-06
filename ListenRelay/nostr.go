package main

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip19"
)

var defaultRelays = []string{
	"wss://relay.damus.io",
	"wss://nos.lol",
	"wss://relay.primal.net",
}

func PublishTrackToNostr(privateKey string, artist, track, album string) error {
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

	// 2. Create Event
	content := fmt.Sprintf("Currently listening to %s by %s", track, artist)
	if album != "" {
		content += fmt.Sprintf(" from the album %s", album)
	}
	content += ".\n\n#nowplaying #music"

	ev := nostr.Event{
		PubKey:    pub,
		CreatedAt: nostr.Now(),
		Kind:      nostr.KindTextNote,
		Content:   content,
		Tags:      nostr.Tags{},
	}

	// 3. Sign Event
	if err := ev.Sign(hexKey); err != nil {
		return fmt.Errorf("failed to sign event: %v", err)
	}

	// 4. Publish to Relays
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
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
