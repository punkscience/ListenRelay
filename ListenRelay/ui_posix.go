//go:build !windows

package main

import (
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
)

type PosixUI struct{}

func (ui *PosixUI) Run(cfg *Config, minimized bool) {
	log.Println("ListenRelay running in headless mode.")
	log.Println("Press Ctrl+C to exit.")

	if cfg.UserToken == "" {
		log.Println("WARNING: Listenbrainz User Token is empty. Please check your config file.")
	}

	OnTrackReceived = func(artist, track, album, uri string) {
		ui.UpdateStatus(artist, track, album)
	}

	// Keep alive until signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan
	log.Println("Shutting down...")
}

func (ui *PosixUI) Notify(title, message string) {
	fmt.Printf("[%s] %s\n", title, message)
}

func (ui *PosixUI) UpdateStatus(artist, track, album string) {
	log.Printf("Currently Playing: %s - %s (%s)", artist, track, album)
}

func init() {

	currentUI = &PosixUI{}

}



func setupDebug() {

	// POSIX systems usually already have a terminal if run from one.

	// We don't need to allocate a console like on Windows.

	fmt.Println("POSIX debug mode: using standard terminal output.")

}
