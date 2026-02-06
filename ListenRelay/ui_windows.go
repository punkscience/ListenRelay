//go:build windows

package main

import (
	"fmt"
	"log"
	"os"
	"syscall"

	"github.com/lxn/walk"
	. "github.com/lxn/walk/declarative"
)

type WindowsUI struct {
	mw            *walk.MainWindow
	ni            *walk.NotifyIcon
	currentArtist string
	currentTrack  string
	currentAlbum  string
	currentURI    string
}

func (ui *WindowsUI) Run(cfg *Config) {
	var tokenParams, nostrKeyParams, nostrTemplateParams *walk.LineEdit
	var statusLabel *walk.Label

	if err := (MainWindow{
		AssignTo: &ui.mw,
		Title:    "ListenRelay Settings",
		MinSize:  Size{Width: 450, Height: 400},
		Size:     Size{Width: 450, Height: 400},
		Layout:   VBox{},
		Visible:  false,
		Children: []Widget{
			Label{Text: "Listenbrainz User Token:"},
			LineEdit{
				AssignTo: &tokenParams,
				Text:     cfg.UserToken,
			},
			Label{Text: "Nostr Private Key (Hex or nsec):"},
			LineEdit{
				AssignTo: &nostrKeyParams,
				Text:     cfg.NostrPrivateKey,
				PasswordMode: true,
			},
			Label{Text: "Nostr Publish Template ([Track], [Artist], [Album]):"},
			LineEdit{
				AssignTo: &nostrTemplateParams,
				Text:     cfg.NostrTemplate,
			},
			PushButton{
				Text: "Save",
				OnClicked: func() {
					cfg.UserToken = tokenParams.Text()
					cfg.NostrPrivateKey = nostrKeyParams.Text()
					cfg.NostrTemplate = nostrTemplateParams.Text()
					if err := SaveConfig(cfg); err != nil {
						statusLabel.SetText("Status: Error saving config")
					} else {
						UpdateToken(cfg.UserToken)
						statusLabel.SetText("Status: Configuration Saved!")
						walk.MsgBox(ui.mw, "Success", "Configuration Saved!", walk.MsgBoxIconInformation)
						ui.mw.Hide()
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

	var err error
	ui.ni, err = walk.NewNotifyIcon(ui.mw)
	if err != nil {
		log.Fatal(err)
	}
	defer ui.ni.Dispose()

	if icon, err := walk.NewIconFromFile("icon.ico"); err == nil {
		ui.ni.SetIcon(icon)
	} else {
		if icon, err := walk.NewIconFromSysDLL("shell32.dll", 1); err == nil {
			ui.ni.SetIcon(icon)
		}
	}

	ui.ni.SetToolTip("ListenRelay: Idle")

	// Context Menu
	publishAction := walk.NewAction()
	publishAction.SetText("Publish to Nostr")
	publishAction.Triggered().Attach(func() {
		if cfg.NostrPrivateKey == "" {
			walk.MsgBox(ui.mw, "Error", "Please configure your Nostr Private Key in Settings.", walk.MsgBoxIconError)
			return
		}
		if ui.currentArtist == "" || ui.currentTrack == "" {
			walk.MsgBox(ui.mw, "Info", "No track is currently playing.", walk.MsgBoxIconInformation)
			return
		}

		go func() {
			err := PublishTrackToNostr(cfg.NostrPrivateKey, cfg.NostrTemplate, ui.currentArtist, ui.currentTrack, ui.currentAlbum, ui.currentURI)
			ui.mw.Synchronize(func() {
				if err != nil {
					ui.Notify("Nostr Error", fmt.Sprintf("Failed to publish: %v", err))
				} else {
					ui.Notify("Nostr Success", "Published track to Nostr!")
				}
			})
		}()
	})

	settingsAction := walk.NewAction()
	settingsAction.SetText("Settings")
	settingsAction.Triggered().Attach(func() {
		ui.mw.Show()
		ui.mw.SetFocus()
	})

	exitAction := walk.NewAction()
	exitAction.SetText("Quit")
	exitAction.Triggered().Attach(func() { walk.App().Exit(0) })

	ui.ni.ContextMenu().Actions().Add(publishAction)
	ui.ni.ContextMenu().Actions().Add(walk.NewSeparatorAction())
	ui.ni.ContextMenu().Actions().Add(settingsAction)
	ui.ni.ContextMenu().Actions().Add(walk.NewSeparatorAction())
	ui.ni.ContextMenu().Actions().Add(exitAction)

	ui.ni.SetVisible(true)

	if cfg.UserToken == "" {
		ui.mw.Show()
	}

	ui.mw.Closing().Attach(func(canceled *bool, reason walk.CloseReason) {
		*canceled = true
		ui.mw.Hide()
	})

	// Global callback update
	OnTrackReceived = func(artist, track, album, uri string) {
		ui.UpdateStatus(artist, track, album)
		ui.currentArtist = artist
		ui.currentTrack = track
		ui.currentAlbum = album
		ui.currentURI = uri
	}

	ui.mw.Run()
}

func (ui *WindowsUI) Notify(title, message string) {
	ui.ni.ShowCustom(title, message, ui.ni.Icon())
}

func (ui *WindowsUI) UpdateStatus(artist, track, album string) {
	ui.mw.Synchronize(func() {
		ui.ni.SetToolTip(fmt.Sprintf("Scrobbling: %s - %s", artist, track))
	})
}

func init() {
	currentUI = &WindowsUI{}
}

var (
	kernel32         = syscall.NewLazyDLL("kernel32.dll")
	procAllocConsole = kernel32.NewProc("AllocConsole")
)

func setupDebug() {
	procAllocConsole.Call()
	stdout, _ := os.OpenFile("CONOUT$", os.O_WRONLY, 0)
	stderr, _ := os.OpenFile("CONOUT$", os.O_WRONLY, 0)
	os.Stdout = stdout
	os.Stderr = stderr
	log.SetOutput(stdout)
	fmt.Println("Windows console allocated for debug mode.")
}
