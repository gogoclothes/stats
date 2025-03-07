//
//  popup.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 11/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public protocol Popup_p: NSView {
    var sizeCallback: ((NSSize) -> Void)? { get set }
    func settings() -> NSView?
}

internal class PopupWindow: NSWindow, NSWindowDelegate {
    private let viewController: PopupViewController = PopupViewController()
    internal var locked: Bool = false
    internal var openedBy: widget_t? = nil
    
    init(title: String, view: Popup_p?, visibilityCallback: @escaping (_ state: Bool) -> Void) {
        self.viewController.setup(title: title, view: view)
        
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: self.viewController.view.frame.width,
                height: self.viewController.view.frame.height
            ),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        
        self.viewController.visibilityCallback = { [weak self] state in
            self?.locked = false
            visibilityCallback(state)
        }
        
        self.contentViewController = self.viewController
        self.titlebarAppearsTransparent = true
        self.animationBehavior = .default
        self.collectionBehavior = .moveToActiveSpace
        self.backgroundColor = .clear
        self.hasShadow = true
        self.setIsVisible(false)
        self.delegate = self
    }
    
    func windowWillMove(_ notification: Notification) {
        self.viewController.setCloseButton(true)
        self.locked = true
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if self.locked {
            return
        }
        
        self.viewController.setCloseButton(false)
        self.setIsVisible(false)
    }
}

internal class PopupViewController: NSViewController {
    public var visibilityCallback: (_ state: Bool) -> Void = {_ in }
    private var popup: PopupView
    
    public init() {
        self.popup = PopupView(frame: NSRect(
            x: 0,
            y: 0,
            width: Constants.Popup.width + (Constants.Popup.margins * 2),
            height: Constants.Popup.height+Constants.Popup.headerHeight
        ))
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = self.popup
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        self.popup.appear()
        self.visibilityCallback(true)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        self.popup.disappear()
        self.visibilityCallback(false)
    }
    
    public func setup(title: String, view: Popup_p?) {
        self.title = title
        self.popup.setTitle(title)
        self.popup.setView(view)
    }
    
    public func setCloseButton(_ state: Bool) {
        self.popup.setCloseButton(state)
    }
}

internal class PopupView: NSView {
    private var title: String? = nil
    
    private var foreground: NSVisualEffectView
    private var background: NSView
    
    private let header: HeaderView
    private let body: NSScrollView
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: self.frame.width, height: self.frame.height)
    }
    private var windowHeight: CGFloat?
    private var containerHeight: CGFloat?
    
    override init(frame: NSRect) {
        self.header = HeaderView(frame: NSRect(
            x: 0,
            y: frame.height - Constants.Popup.headerHeight,
            width: frame.width,
            height: Constants.Popup.headerHeight
        ))
        self.body = NSScrollView(frame: NSRect(
            x: Constants.Popup.margins,
            y: Constants.Popup.margins,
            width: frame.width - Constants.Popup.margins*2,
            height: frame.height - self.header.frame.height - Constants.Popup.margins*2
        ))
        self.windowHeight = NSScreen.main?.visibleFrame.height
        self.containerHeight = self.body.documentView?.frame.height
        
        self.foreground = NSVisualEffectView(frame: frame)
        self.foreground.material = .titlebar
        self.foreground.blendingMode = .behindWindow
        self.foreground.state = .active
        self.foreground.wantsLayer = true
        self.foreground.layer?.backgroundColor = NSColor.red.cgColor
        self.foreground.layer?.cornerRadius = 6
        
        self.background = NSView(frame: frame)
        self.background.wantsLayer = true
        self.foreground.addSubview(self.background)
        
        super.init(frame: frame)
        
        self.body.drawsBackground = false
        self.body.translatesAutoresizingMaskIntoConstraints = true
        self.body.borderType = .noBorder
        self.body.hasVerticalScroller = true
        self.body.hasHorizontalScroller = false
        self.body.autohidesScrollers = true
        self.body.horizontalScrollElasticity = .none
        
        self.addSubview(self.foreground, positioned: .below, relativeTo: .none)
        self.addSubview(self.header)
        self.addSubview(self.body)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayer() {
        self.background.layer?.backgroundColor = self.isDarkMode ? .clear : NSColor.white.cgColor
    }
    
    public func setView(_ view: Popup_p?) {
        let width: CGFloat = (view?.frame.width ?? Constants.Popup.width) + (Constants.Popup.margins*2)
        let height: CGFloat = (view?.frame.height ?? 0) + Constants.Popup.headerHeight + (Constants.Popup.margins*2)
        
        self.setFrameSize(NSSize(width: width, height: height))
        self.foreground.setFrameSize(NSSize(width: width, height: height))
        self.background.setFrameSize(NSSize(width: width, height: height))
        self.header.setFrameOrigin(NSPoint(x: 0, y: height - Constants.Popup.headerHeight))
        self.body.setFrameSize(NSSize(width: (view?.frame.width ?? Constants.Popup.width), height: (view?.frame.height ?? 0)))
        
        if let view = view {
            self.body.documentView = view
            view.sizeCallback = { [weak self] size in
                self?.recalculateHeight(size)
            }
        }
    }
    
    public func setTitle(_ newTitle: String) {
        self.title = newTitle
        self.header.setTitle(newTitle)
    }
    
    public func setCloseButton(_ state: Bool) {
        self.header.setCloseButton(state)
    }
    
    internal func appear() {
        self.display()
        self.body.subviews.first?.display()
        
        if let screenHeight = NSScreen.main?.visibleFrame.height, let size = self.body.documentView?.frame.size {
            if screenHeight != self.windowHeight {
                self.recalculateHeight(size)
            }
        }
        
        if let documentView = self.body.documentView {
            documentView.scroll(NSPoint(x: 0, y: documentView.bounds.size.height))
        }
    }
    internal func disappear() {
        self.header.setCloseButton(false)
    }
    
    private func recalculateHeight(_ size: NSSize) {
        var isScrollVisible: Bool = false
        var windowSize: NSSize = NSSize(
            width: size.width + (Constants.Popup.margins*2),
            height: size.height + Constants.Popup.headerHeight + (Constants.Popup.margins*2)
        )
        let h0 = self.containerHeight ?? 0
        
        self.windowHeight = NSScreen.main?.visibleFrame.height // for height recalculate when appear/disappear
        self.containerHeight = self.body.documentView?.frame.height // for scroll diff calculation
        if let screenHeight = NSScreen.main?.visibleFrame.height, windowSize.height > screenHeight {
            windowSize.height = screenHeight - Constants.Widget.height
            isScrollVisible = true
        }
        if let screenWidth = NSScreen.main?.visibleFrame.width, windowSize.width > screenWidth {
            windowSize.width = screenWidth
        }
        
        self.window?.setContentSize(windowSize)
        self.foreground.setFrameSize(windowSize)
        self.background.setFrameSize(windowSize)
        self.body.setFrameSize(NSSize(
            width: windowSize.width - (Constants.Popup.margins*2) + (isScrollVisible ? 20 : 0),
            height: windowSize.height - Constants.Popup.headerHeight - (Constants.Popup.margins*2)
        ))
        self.header.setFrameOrigin(NSPoint(
            x: self.header.frame.origin.x,
            y: self.body.frame.height + (Constants.Popup.margins*2)
        ))
        
        if let documentView = self.body.documentView {
            let diff = h0 - (self.body.documentView?.frame.height ?? 0)
            documentView.scroll(NSPoint(
                x: 0,
                y: self.body.documentVisibleRect.origin.y - (diff < 0 ? diff : 0)
            ))
        }
    }
}

internal class HeaderView: NSStackView {
    private var titleView: NSTextField? = nil
    private var activityButton: NSButton?
    private var settingsButton: NSButton?
    
    private var title: String = ""
    private var isCloseAction: Bool = false
    
    override init(frame: NSRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.width, height: frame.height))
        
        self.orientation = .horizontal
        self.distribution = .gravityAreas
        self.spacing = 0
        
        let activity = NSButtonWithPadding()
        activity.frame = CGRect(x: 0, y: 0, width: 24, height: self.frame.height)
        activity.horizontalPadding = activity.frame.height - 24
        activity.bezelStyle = .regularSquare
        activity.translatesAutoresizingMaskIntoConstraints = false
        activity.imageScaling = .scaleNone
        activity.image = Bundle(for: type(of: self)).image(forResource: "chart")!
        if #available(OSX 10.14, *) {
            activity.contentTintColor = .lightGray
        }
        activity.isBordered = false
        activity.action = #selector(openActivityMonitor)
        activity.target = self
        activity.toolTip = localizedString("Open Activity Monitor")
        activity.focusRingType = .none
        self.activityButton = activity
        
        let title = NSTextField(frame: NSRect(x: 0, y: 0, width: frame.width/2, height: 18))
        title.isEditable = false
        title.isSelectable = false
        title.isBezeled = false
        title.wantsLayer = true
        title.textColor = .textColor
        title.backgroundColor = .clear
        title.canDrawSubviewsIntoLayer = true
        title.alignment = .center
        title.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        title.stringValue = ""
        self.titleView = title
        
        let settings = NSButtonWithPadding()
        settings.frame = CGRect(x: 0, y: 0, width: 24, height: self.frame.height)
        settings.horizontalPadding = activity.frame.height - 24
        settings.bezelStyle = .regularSquare
        settings.translatesAutoresizingMaskIntoConstraints = false
        settings.imageScaling = .scaleNone
        settings.image = Bundle(for: type(of: self)).image(forResource: "settings")!
        if #available(OSX 10.14, *) {
            settings.contentTintColor = .lightGray
        }
        settings.isBordered = false
        settings.action = #selector(openSettings)
        settings.target = self
        settings.toolTip = localizedString("Open module settings")
        settings.focusRingType = .none
        self.settingsButton = settings
        
        self.addArrangedSubview(activity)
        self.addArrangedSubview(title)
        self.addArrangedSubview(settings)
        
        NSLayoutConstraint.activate([
            title.widthAnchor.constraint(
                equalToConstant: self.frame.width - activity.intrinsicContentSize.width - settings.intrinsicContentSize.width
            )
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setTitle(_ newTitle: String) {
        self.title = newTitle
        self.titleView?.stringValue = localizedString(newTitle)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.gridColor.set()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 0, y: 0))
        line.line(to: NSPoint(x: self.frame.width, y: 0))
        line.lineWidth = 1
        line.stroke()
    }
    
    @objc func openActivityMonitor(_ sender: Any) {
        self.window?.setIsVisible(false)
        
        NSWorkspace.shared.launchApplication(
            withBundleIdentifier: "com.apple.ActivityMonitor",
            options: [.default],
            additionalEventParamDescriptor: nil,
            launchIdentifier: nil
        )
    }
    
    @objc func openSettings(_ sender: Any) {
        self.window?.setIsVisible(false)
        NotificationCenter.default.post(name: .toggleSettings, object: nil, userInfo: ["module": self.title])
    }
    
    @objc private func closePopup() {
        self.window?.setIsVisible(false)
        self.setCloseButton(false)
        return
    }
    
    public func setCloseButton(_ state: Bool) {
        if state && !self.isCloseAction {
            self.activityButton?.image = Bundle(for: type(of: self)).image(forResource: "close")!
            self.activityButton?.toolTip = localizedString("Close popup")
            self.activityButton?.action = #selector(self.closePopup)
            self.isCloseAction = true
        } else if !state && self.isCloseAction {
            self.activityButton?.image = Bundle(for: type(of: self)).image(forResource: "chart")!
            self.activityButton?.toolTip = localizedString("Open Activity Monitor")
            self.activityButton?.action = #selector(self.openActivityMonitor)
            self.isCloseAction = false
        }
    }
}
