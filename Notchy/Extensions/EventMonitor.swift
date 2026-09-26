//
//  EventMonitor.swift
//  Notchy
//
//  Wraps global + local NSEvent monitors (NotchDrop pattern).
//  Global monitors observe events delivered to OTHER apps and work
//  even when our (accessory) app is in the background.
//

import AppKit

final class EventMonitor {
    enum Scope {
        case global
        case local
        case both
    }

    private let mask: NSEvent.EventTypeMask
    private let scope: Scope
    private let handler: (NSEvent) -> Void
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(mask: NSEvent.EventTypeMask, scope: Scope = .both, handler: @escaping (NSEvent) -> Void) {
        self.mask = mask
        self.scope = scope
        self.handler = handler
    }

    func start() {
        if scope == .global || scope == .both {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        }
        if scope == .local || scope == .both {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [handler] event in
                handler(event)
                return event
            }
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    deinit {
        stop()
    }
}
