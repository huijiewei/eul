//
//  AppDelegate.swift
//  eul
//
//  Created by Gao Sun on 2020/6/21.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import Cocoa
import Combine
import Localize_Swift
import SharedLibrary
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var isSleeping = false
    private var appearanceCancellable: AnyCancellable?

    var window: NSWindow!
    @ObservedObject var preferenceStore = SharedStore.preference

    func applicationDidFinishLaunching(_: Notification) {
        let contentView = ContentView()
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.center()
        window.setFrameAutosaveName("Eul Preferences")
        window.contentView = NSHostingView(rootView: contentView.withGlobalEnvironmentObjects())
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.delegate = self

        // comment out for not showing window at login. no proper solution currently, tracking:
        // https://github.com/sindresorhus/LaunchAtLogin/issues/33
        // window.makeKeyAndOrderFront(nil)
        // NSApp.activate(ignoringOtherApps: true)

        SmcControl.shared.subscribe()
        StatusBarManager.shared.checkVisibilityIfNeeded()
        wakeUp()

        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in
            print("😪 going to sleep")
            self.sleep()
        }
        notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in
            print("🤩 woke up")
            self.wakeUp()
        }

        // Disable in Catalina to avoid protential crash
        if #available(OSX 11, *) {
            appearanceCancellable = preferenceStore.$appearanceMode.sink { mode in
                DispatchQueue.main.async {
                    self.window.appearance = mode.nsAppearance
                }
            }
        }
    }

    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        print("🤚 should terminate")
        SmcControl.shared.close()
        return .terminateNow
    }

    func wakeUp() {
        isSleeping = false
        refreshSMCRepeatedly()
        refreshNetworkRepeatedly()
    }

    func sleep() {
        isSleeping = true
    }

    func applicationWillTerminate(_: Notification) {
        // Insert code here to tear down your application
    }
}

// MARK: Static Methods

extension AppDelegate {
    static var statusBarHeight: CGFloat {
        NSStatusBar.system.thickness
    }

    static func openPreferences() {
        (NSApp.delegate as! AppDelegate).window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .StatusBarMenuShouldClose, object: nil)
    }

    static func quit() {
        NSApplication.shared.terminate(self)
    }
}

// MARK: Repeating Methods

extension AppDelegate {
    func refreshSMCRepeatedly() {
        guard !isSleeping else {
            return
        }

        NotificationCenter.default.post(name: .SMCShouldRefresh, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(preferenceStore.smcRefreshRate)) { [self] in
            refreshSMCRepeatedly()
        }
    }

    func refreshNetworkRepeatedly() {
        guard !isSleeping else {
            return
        }

        NotificationCenter.default.post(name: .NetworkShouldRefresh, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(preferenceStore.networkRefreshRate)) { [self] in
            refreshNetworkRepeatedly()
        }
    }
}
