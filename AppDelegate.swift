/*
To run the code:
swiftc -o StatusMenuApp AppDelegate.swift -framework AppKit
./StatusMenuApp
*/

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var runningProcess: Process?
    let currentDir = FileManager.default.currentDirectoryPath
    var isProgramRunning = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set up the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Load your custom image from the current directory
            let imagePath = "\(self.currentDir)/logo.png"
            if let customImage = NSImage(contentsOfFile: imagePath) {
                customImage.isTemplate = true // Adapt for light/dark mode

                // Resize the image to match the menu bar icon size
                let iconSize = NSSize(width: 20, height: 20)
                customImage.size = iconSize

                button.image = customImage
            } else {
                print("Failed to load image at path: \(imagePath)")
            }
        }

        // Initialize the menu
        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()
        if isProgramRunning {
            menu.addItem(NSMenuItem(title: "Stop Program", action: #selector(stopProductivityScript), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Run Program", action: #selector(runProductivityScript), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func runProductivityScript() {
        print("Run Program clicked")
        let process = Process()
        self.runningProcess = process
        isProgramRunning = true
        updateMenu()

        // Update the path to the Python executable and script
        process.executableURL = URL(fileURLWithPath: "\(self.currentDir)/venv/bin/python3")
        process.arguments = ["\(self.currentDir)/productivity.py"]

        // Load and set the active icon
        let activeImagePath = "\(self.currentDir)/activelogo.png"
        if let button = statusItem?.button, let activeImage = NSImage(contentsOfFile: activeImagePath) {
            activeImage.isTemplate = true
            activeImage.size = NSSize(width: 20, height: 20)
            button.image = activeImage
        } else {
            print("Failed to load active logo image at path: \(activeImagePath)")
        }

        DispatchQueue.global().async {
            do {
                try process.run()
                process.waitUntilExit()
                print("Python script executed successfully.")
                DispatchQueue.main.async {
                    self.isProgramRunning = false
                    self.updateMenu()
                    self.resetIconToDefault()
                }
            } catch {
                print("Failed to run Python script: \(error)")
                DispatchQueue.main.async {
                    self.isProgramRunning = false
                    self.updateMenu()
                    self.resetIconToDefault()
                }
            }
        }
    }

    @objc func stopProductivityScript() {
        print("Stop Program clicked")
        runningProcess?.terminate()
        runningProcess = nil
        isProgramRunning = false
        updateMenu()
        print("Python script terminated.")

        // Load and set the inactive icon
        let inactiveImagePath = "\(self.currentDir)/inactivelogo.png"
        if let button = statusItem?.button, let inactiveImage = NSImage(contentsOfFile: inactiveImagePath) {
            inactiveImage.isTemplate = true
            inactiveImage.size = NSSize(width: 20, height: 20)
            button.image = inactiveImage
        } else {
            print("Failed to load inactive logo image at path: \(inactiveImagePath)")
        }
    }

    @objc func resetIconToDefault() {
        let imagePath = "\(self.currentDir)/logo.png"
        if let button = statusItem?.button, let customImage = NSImage(contentsOfFile: imagePath) {
            customImage.isTemplate = true
            customImage.size = NSSize(width: 20, height: 20)
            button.image = customImage
        }
    }

    @objc func quitApplication() {
        print("Quitting application...")
        runningProcess?.terminate()
        NSApplication.shared.terminate(self)
    }
}

// Explicit entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
