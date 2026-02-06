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
		// Manually allocate a console for debug mode
		AllocConsole()
		
		// Redirect standard streams to the new console
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

	// 2. Start Background Server
	go StartServer()

	// 3. Setup Walk GUI
	var mw *walk.MainWindow
	var tokenParams *walk.LineEdit
	var statusLabel *walk.Label
	var ni *walk.NotifyIcon

	if err := (MainWindow{
		AssignTo: &mw,
		Title:    "ListenRelay Settings",
		MinSize:  Size{Width: 400, Height: 200},
		Size:     Size{Width: 400, Height: 200},
		Layout:   VBox{},
		Visible:  false, // Start hidden unless needed
		Children: []Widget{
			Label{Text: "Listenbrainz User Token:"},
			LineEdit{
				AssignTo: &tokenParams,
				Text:     cfg.UserToken,
			},
			PushButton{
				Text: "Save",
				OnClicked: func() {
					cfg.UserToken = tokenParams.Text()
					if err := SaveConfig(cfg); err != nil {
						statusLabel.SetText("Status: Error saving config")
					} else {
						UpdateToken(cfg.UserToken)
						statusLabel.SetText("Status: Configuration Saved!")
						walk.MsgBox(mw, "Success", "Configuration Saved!", walk.MsgBoxIconInformation)
						mw.Hide() // Hide after save
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

	// Set Tray Icon
	if icon, err := walk.NewIconFromFile("icon.ico"); err == nil {
		ni.SetIcon(icon)
	} else {
		// Fallback to Shell32 icon
		if icon, err := walk.NewIconFromSysDLL("shell32.dll", 1); err == nil {
			ni.SetIcon(icon)
		}
	}

	ni.SetToolTip("ListenRelay: Idle")

	// Register callback to update tooltip on track reception
	OnTrackReceived = func(artist, track, album string) {
		mw.Synchronize(func() {
			ni.SetToolTip(fmt.Sprintf("Scrobbling: %s - %s", artist, track))
		})
	}

	// Context Menu
	exitAction := walk.NewAction()
	exitAction.SetText("Quit")
	exitAction.Triggered().Attach(func() { walk.App().Exit(0) })

	settingsAction := walk.NewAction()
	settingsAction.SetText("Settings")
	settingsAction.Triggered().Attach(func() {
		mw.Show()
		mw.SetFocus()
	})

	ni.ContextMenu().Actions().Add(settingsAction)
	ni.ContextMenu().Actions().Add(walk.NewSeparatorAction())
	ni.ContextMenu().Actions().Add(exitAction)

	ni.SetVisible(true)

	// If token is missing, show settings on start
	if cfg.UserToken == "" {
		mw.Show()
	}

	// Prevent closing the window, just hide it
	mw.Closing().Attach(func(canceled *bool, reason walk.CloseReason) {
		*canceled = true
		mw.Hide()
	})

	mw.Run()
}
