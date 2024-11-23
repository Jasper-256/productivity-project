/*
To run the code:
swiftc -o StatusMenuApp AppDelegate.swift -framework AppKit
./StatusMenuApp
*/

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var runningProcess: Process?

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
        menu.addItem(NSMenuItem(title: "Run Program", action: #selector(runProductivityScript), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Stop Program", action: #selector(stopProductivityScript), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc func showTabSuggestions() {
    let filePath = "suggested_tabs.txt" // Ensure this matches the Python output path
    var suggestions = "No suggestions available."
    
    if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
        suggestions = content
    }
    
    let alert = NSAlert()
    alert.messageText = "Suggested Tabs to Close"
    alert.informativeText = suggestions
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
}


    @objc func runProductivityScript() {
        let process = Process()
        self.runningProcess = process
        process.executableURL = URL(fileURLWithPath: "venv/bin/python3")
        process.arguments = ["productivity.py"]
        
        DispatchQueue.global().async {
            do {
                try process.run()
                process.waitUntilExit()
                print("Python script executed successfully.")
            } catch {
                print("Failed to run Python script: \(error)")
            }
        }
    }
    
    @objc func stopProductivityScript() {
        runningProcess?.terminate()
        runningProcess = nil
        print("Python script terminated.")
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
