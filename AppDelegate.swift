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
    var productiveWindow: NSWindow?
    var statusCheckTimer: Timer?

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
            menu.addItem(NSMenuItem(title: "Show Tab Suggestions", action: #selector(showTabSuggestions), keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Run Program", action: #selector(runProductivityScript), keyEquivalent: ""))
        }
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
                print("Python script started.")
            } catch {
                print("Failed to run Python script: \(error)")
                DispatchQueue.main.async {
                    self.isProgramRunning = false
                    self.updateMenu()
                    self.resetIconToDefault()
                }
                return
            }
        }

        // Schedule the timer to check productivity status every second
        DispatchQueue.main.async {
            self.statusCheckTimer = Timer.scheduledTimer(timeInterval: 1.0, 
                                                     target: self, 
                                                     selector: #selector(self.checkProductivityStatus), 
                                                     userInfo: nil, 
                                                     repeats: true)
        }
    }
    
    @objc func stopProductivityScript() {
        print("Stop Program clicked")
        runningProcess?.terminate()
        runningProcess = nil
        isProgramRunning = false
        updateMenu()
        print("Python script terminated.")

        // Invalidate the timer
        DispatchQueue.main.async {
            self.statusCheckTimer?.invalidate()
            self.statusCheckTimer = nil
        }

        // Remove the outline
        removeOutline()

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
        runningProcess = nil

        // Invalidate the timer
        DispatchQueue.main.async {
            self.statusCheckTimer?.invalidate()
            self.statusCheckTimer = nil
        }

        // Remove the outline
        removeOutline()

        NSApplication.shared.terminate(self)
    }

    // Check the productivity status from the status file
    @objc func checkProductivityStatus() {
        let filePath = "productivity_status.txt"
        
        guard let status = try? String(contentsOfFile: filePath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else {
            print("Failed to read status file.")
            return
        }
        
        DispatchQueue.main.async {
            if status == "productive" {
                self.applyGreenOutline()
            } else if status == "unproductive" {
                self.applyRedOutline()
            } else {
                self.removeOutline()
            }
        }
    }

    func createProductiveWindow() {
    DispatchQueue.main.async {
        if self.productiveWindow == nil {
            self.productiveWindow = NSWindow(contentRect: NSMakeRect(0, 0, 1440, 900),
                                             styleMask: [.titled, .resizable],
                                             backing: .buffered,
                                             defer: false)
            self.productiveWindow?.contentView?.wantsLayer = true
            self.productiveWindow?.makeKeyAndOrderFront(nil)

            self.productiveWindow?.contentView?.layer?.backgroundColor = NSColor.white.cgColor
            }
        }
    }

    func createOverlayWindow(borderColor: CGColor) {
    if productiveWindow == nil {
        // Get screen size
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Create a transparent overlay window
        productiveWindow = NSWindow(contentRect: screenFrame,
                                     styleMask: [.borderless],
                                     backing: .buffered,
                                     defer: false)
        productiveWindow?.isOpaque = false
        productiveWindow?.backgroundColor = .clear
        productiveWindow?.ignoresMouseEvents = true
        productiveWindow?.level = .screenSaver
        productiveWindow?.contentView?.wantsLayer = true

        // Add the border
        productiveWindow?.contentView?.layer?.borderWidth = 3.0
        productiveWindow?.contentView?.layer?.borderColor = borderColor

        productiveWindow?.makeKeyAndOrderFront(nil)
    } else {
        // Update the border color if the window already exists
        productiveWindow?.contentView?.layer?.borderColor = borderColor
    }
}

    func applyGreenOutline() {
        DispatchQueue.main.async {
            self.createOverlayWindow(borderColor: NSColor.green.cgColor)
        }
    }

    func applyRedOutline() {
        DispatchQueue.main.async {
            self.createOverlayWindow(borderColor: NSColor.red.cgColor)
        }
    }

    func removeOutline() {
        DispatchQueue.main.async {
            self.productiveWindow?.close()
            self.productiveWindow = nil
        }
    }

}

// Explicit entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
