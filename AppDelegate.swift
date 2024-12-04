/*
To run the code:
swiftc -o StatusMenuApp AppDelegate.swift -framework AppKit
./StatusMenuApp
*/

import Cocoa  // Import Cocoa framework for macOS development

class AppDelegate: NSObject, NSApplicationDelegate {
    // The status bar item displayed in the menu bar
    var statusItem: NSStatusItem?
    // The running Python process
    var runningProcess: Process?
    // Current directory path
    let currentDir = FileManager.default.currentDirectoryPath
    // Boolean flag indicating whether the program is running
    var isProgramRunning = false
    // Window used to display the overlay border
    var productiveWindow: NSWindow?
    // Timer to periodically check productivity status
    var statusCheckTimer: Timer?

    // Called when the application has finished launching
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set up the status bar item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Path to the default logo image
            let imagePath = "\(self.currentDir)/logo.png"
            // Load the custom image from the current directory
            if let customImage = NSImage(contentsOfFile: imagePath) {
                customImage.isTemplate = true // Allows the image to adapt to light/dark mode

                // Resize the image to match the menu bar icon size
                let iconSize = NSSize(width: 20, height: 20)
                customImage.size = iconSize

                // Set the button's image to the custom image
                button.image = customImage
            } else {
                print("Failed to load image at path: \(imagePath)")
            }
        }

        // Initialize the menu items
        updateMenu()
    }

    // Updates the status bar menu based on whether the program is running
    func updateMenu() {
        let menu = NSMenu()
        if isProgramRunning {
            // If the program is running, show 'Stop Program' and 'Show Tab Suggestions' options
            menu.addItem(NSMenuItem(title: "Stop Program", action: #selector(stopProductivityScript), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Show Tab Suggestions", action: #selector(showTabSuggestions), keyEquivalent: ""))
        } else {
            // If the program is not running, show 'Run Program' option
            menu.addItem(NSMenuItem(title: "Run Program", action: #selector(runProductivityScript), keyEquivalent: ""))
        }
        // Add a separator
        menu.addItem(NSMenuItem.separator())
        // Add 'Quit' option with 'q' as the keyboard shortcut
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApplication), keyEquivalent: "q"))
        // Assign the menu to the status item
        statusItem?.menu = menu
    }

    // Shows the suggested tabs to close in an alert
    @objc func showTabSuggestions() {
        let filePath = "suggested_tabs.txt" // Ensure this matches the Python output path
        var suggestions = "No suggestions available."
        
        // Try to read the content of the suggested tabs file
        if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            suggestions = content
        }
        
        // Create and display an alert with the suggestions
        let alert = NSAlert()
        alert.messageText = "Suggested Tabs to Close"
        alert.informativeText = suggestions
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // Starts the productivity script and updates the UI accordingly
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

        // Run the Python script asynchronously
        DispatchQueue.global().async {
            do {
                try process.run()
                print("Python script started.")
            } catch {
                print("Failed to run Python script: \(error)")
                // If an error occurs, update the UI on the main thread
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
    
    // Stops the productivity script and updates the UI accordingly
    @objc func stopProductivityScript() {
        print("Stop Program clicked")
        // Terminate the running Python process
        runningProcess?.terminate()
        runningProcess = nil
        isProgramRunning = false
        updateMenu()
        print("Python script terminated.")

        // Invalidate the timer on the main thread
        DispatchQueue.main.async {
            self.statusCheckTimer?.invalidate()
            self.statusCheckTimer = nil
        }

        // Remove the overlay border
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

    // Resets the status bar icon to the default image
    @objc func resetIconToDefault() {
        let imagePath = "\(self.currentDir)/logo.png"
        if let button = statusItem?.button, let customImage = NSImage(contentsOfFile: imagePath) {
            customImage.isTemplate = true
            customImage.size = NSSize(width: 20, height: 20)
            button.image = customImage
        }
    }

    // Quits the application and cleans up resources
    @objc func quitApplication() {
        print("Quitting application...")
        // Terminate the running process if any
        runningProcess?.terminate()
        runningProcess = nil

        // Invalidate the timer
        DispatchQueue.main.async {
            self.statusCheckTimer?.invalidate()
            self.statusCheckTimer = nil
        }

        // Remove the overlay border
        removeOutline()

        // Terminate the application
        NSApplication.shared.terminate(self)
    }

    // Checks the productivity status from the status file and updates the overlay border
    @objc func checkProductivityStatus() {
        let filePath = "productivity_status.txt"
        
        // Read the productivity status from the file
        guard let status = try? String(contentsOfFile: filePath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else {
            print("Failed to read status file.")
            return
        }
        
        // Update the overlay border on the main thread based on the status
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

    // Creates a productive window on the main thread if it doesn't already exist
    func createProductiveWindow() {
        // Ensure all UI updates occur on the main thread
        DispatchQueue.main.async {
            // Check if the productiveWindow is nil (not yet created)
            if self.productiveWindow == nil {
                // Initialize a new NSWindow with the specified frame dimensions (1440x900)
                // and style masks for a titled and resizable window
                self.productiveWindow = NSWindow(contentRect: NSMakeRect(0, 0, 1440, 900),
                                                 styleMask: [.titled, .resizable],
                                                 backing: .buffered,
                                                 defer: false)
                // Enable the use of Core Animation layers on the window's content view
                self.productiveWindow?.contentView?.wantsLayer = true
                // Make the window visible and bring it to the front
                self.productiveWindow?.makeKeyAndOrderFront(nil)

                // Set the background color of the window's content view to white
                self.productiveWindow?.contentView?.layer?.backgroundColor = NSColor.white.cgColor
            }
        }
    }

    // Creates or updates an overlay window with a colored border
    func createOverlayWindow(borderColor: CGColor) {
        if productiveWindow == nil {
            // Get the main screen size
            guard let screen = NSScreen.main else { return }
            let screenFrame = screen.frame

            // Create a transparent overlay window covering the entire screen
            productiveWindow = NSWindow(contentRect: screenFrame,
                                        styleMask: [.borderless],
                                        backing: .buffered,
                                        defer: false)
            productiveWindow?.isOpaque = false
            productiveWindow?.backgroundColor = .clear
            productiveWindow?.ignoresMouseEvents = true
            productiveWindow?.level = .screenSaver
            productiveWindow?.contentView?.wantsLayer = true

            // Add the border to the window's content view
            productiveWindow?.contentView?.layer?.borderWidth = 3.0
            productiveWindow?.contentView?.layer?.borderColor = borderColor

            // Display the window
            productiveWindow?.makeKeyAndOrderFront(nil)
        } else {
            // If the window already exists, update the border color
            productiveWindow?.contentView?.layer?.borderColor = borderColor
        }
    }

    // Applies a green outline to the screen to indicate productivity
    func applyGreenOutline() {
        DispatchQueue.main.async {
            self.createOverlayWindow(borderColor: NSColor.green.cgColor)
        }
    }

    // Applies a red outline to the screen to indicate unproductivity
    func applyRedOutline() {
        DispatchQueue.main.async {
            self.createOverlayWindow(borderColor: NSColor.red.cgColor)
        }
    }

    // Removes the overlay border window
    func removeOutline() {
        DispatchQueue.main.async {
            self.productiveWindow?.close()
            self.productiveWindow = nil
        }
    }

}

// Explicit entry point for the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
