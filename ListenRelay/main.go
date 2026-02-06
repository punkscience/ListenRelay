package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"syscall"

	"github.com/lxn/walk"
	. "github.com/lxn/walk/declarative"
)

var (
	kernel32        = syscall.NewLazyDLL("kernel32.dll")
	procAllocConsole = kernel32.NewProc("AllocConsole")
)

func AllocConsole() {
	procAllocConsole.Call()
}

func main() {
	// 0. Parse Flags
	debug := flag.Bool("debug", false, "Enable debug mode with console output")
	flag.Parse()

	if *debug {
		AllocConsole()
		stdout, _ := os.OpenFile("CONOUT$", os.O_WRONLY, 0)
		stderr, _ := os.OpenFile("CONOUT$", os.O_WRONLY, 0)
		os.Stdout = stdout
		os.Stderr = stderr
		log.SetOutput(stdout)
		fmt.Println("Debug mode enabled. Console allocated.")
	}

	// 1. Load Configuration
	cfg, err := LoadConfig()
	if err != nil {
		log.Printf("Warning: Could not load config: %v", err)
	}
	UpdateToken(cfg.UserToken)

	// Track State
	var currentArtist, currentTrackName, currentAlbum string

	// 2. Start Background Server
	go StartServer()

	// 3. Setup Walk GUI
	var mw *walk.MainWindow
	var tokenParams, nostrKeyParams *walk.LineEdit
	var statusLabel *walk.Label
	var ni *walk.NotifyIcon

	if err := (MainWindow{
		AssignTo: &mw,
		Title:    "ListenRelay Settings",
		MinSize:  Size{Width: 400, Height: 300},
		Size:     Size{Width: 400, Height: 300},
		Layout:   VBox{},
		Visible:  false,
		Children: []Widget{
			Label{Text: "Listenbrainz User Token:"},
			LineEdit{
				AssignTo: &tokenParams,
				Text:     cfg.UserToken,
			},
			Label{Text: "Nostr Private Key (Hex):"},
			LineEdit{
				AssignTo: &nostrKeyParams,
				Text:     cfg.NostrPrivateKey,
				PasswordMode: true,
			},
			PushButton{
				Text: "Save",
				OnClicked: func() {
					cfg.UserToken = tokenParams.Text()
					cfg.NostrPrivateKey = nostrKeyParams.Text()
					if err := SaveConfig(cfg); err != nil {
						statusLabel.SetText("Status: Error saving config")
					} else {
						UpdateToken(cfg.UserToken)
						statusLabel.SetText("Status: Configuration Saved!")
						walk.MsgBox(mw, "Success", "Configuration Saved!", walk.MsgBoxIconInformation)
						mw.Hide()
					}
				},
			},
			VSpacer{},
			Label{
				AssignTo: &statusLabel,
				Text:     "Status: Running on :19485",
			},
		},
	}.Create()); err != nil {
		log.Fatal(err)
	}

	// 4. Setup System Tray
	ni, err = walk.NewNotifyIcon(mw)
	if err != nil {
		log.Fatal(err)
	}
	defer ni.Dispose()

	if icon, err := walk.NewIconFromFile("icon.ico"); err == nil {
		ni.SetIcon(icon)
	} else {
		if icon, err := walk.NewIconFromSysDLL("shell32.dll", 1); err == nil {
			ni.SetIcon(icon)
		}
	}

	ni.SetToolTip("ListenRelay: Idle")

	// Register callback
	OnTrackReceived = func(artist, track, album string) {
		mw.Synchronize(func() {
			currentArtist = artist
			currentTrackName = track
			currentAlbum = album
			ni.SetToolTip(fmt.Sprintf("Scrobbling: %s - %s", artist, track))
		})
	}

	// Context Menu
	publishAction := walk.NewAction()
	publishAction.SetText("Publish to Nostr")
	publishAction.Triggered().Attach(func() {
		if cfg.NostrPrivateKey == "" {
			walk.MsgBox(mw, "Error", "Please configure your Nostr Private Key in Settings.", walk.MsgBoxIconError)
			return
		}
		if currentArtist == "" || currentTrackName == "" {
			walk.MsgBox(mw, "Info", "No track is currently playing (or detected yet).", walk.MsgBoxIconInformation)
			return
		}

		go func() {
			// Run in background to avoid blocking UI
			err := PublishTrackToNostr(cfg.NostrPrivateKey, currentArtist, currentTrackName, currentAlbum)
			mw.Synchronize(func() {
				if err != nil {
					ni.ShowCustom("Nostr Error", fmt.Sprintf("Failed to publish: %v", err), ni.Icon())
				} else {
					ni.ShowCustom("Nostr Success", "Published track to Nostr!", ni.Icon())
				}
			})
		}()
	})

	settingsAction := walk.NewAction()
	settingsAction.SetText("Settings")
	settingsAction.Triggered().Attach(func() {
		mw.Show()
		mw.SetFocus()
	})

	exitAction := walk.NewAction()
	exitAction.SetText("Quit")
	exitAction.Triggered().Attach(func() { walk.App().Exit(0) })

	ni.ContextMenu().Actions().Add(publishAction)
	ni.ContextMenu().Actions().Add(walk.NewSeparatorAction())
	ni.ContextMenu().Actions().Add(settingsAction)
	ni.ContextMenu().Actions().Add(walk.NewSeparatorAction())
	ni.ContextMenu().Actions().Add(exitAction)

	ni.SetVisible(true)

	if cfg.UserToken == "" {
		mw.Show()
	}

	mw.Closing().Attach(func(canceled *bool, reason walk.CloseReason) {
		*canceled = true
		mw.Hide()
	})

	mw.Run()
}