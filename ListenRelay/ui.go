package main

// UI defines the interface for different platform implementations
type UI interface {
	Run(cfg *Config)
	Notify(title, message string)
	UpdateStatus(artist, track, album string)
}

var currentUI UI
