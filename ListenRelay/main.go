package main

import (
	"flag"
	"log"
)

func main() {
	// 0. Parse Flags
	debug := flag.Bool("debug", false, "Enable debug mode with console output")
	flag.Parse()

	if *debug {
		setupDebug()
	}

	// 1. Load Configuration
	cfg, err := LoadConfig()
	if err != nil {
		log.Printf("Warning: Could not load config: %v", err)
	}
	UpdateToken(cfg.UserToken)

	// 2. Start Background Server
	go StartServer()

	// 3. Run UI (GUI on Windows, CLI on others)
	if currentUI != nil {
		currentUI.Run(cfg)
	} else {
		log.Fatal("No UI implementation found for this platform.")
	}
}