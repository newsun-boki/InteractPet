import AppKit
import ApplicationServices
import Carbon

final class InputMonitor {
    var tap: CFMachPort?
    var source: CFRunLoopSource?
    var onKey: ((CGEvent)->Void)?
    var onClick: ((CGPoint)->Void)?
    func start() {
        guard tap == nil else { return }
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let mask = CGEventMask((1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue))
        tap = CGEvent.tapCreate(tap:.cgSessionEventTap,place:.headInsertEventTap,options:.listenOnly,
                               eventsOfInterest:mask,callback:{ _,type,event,ref in
            guard let ref = ref else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<InputMonitor>.fromOpaque(ref).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.tap { CGEvent.tapEnable(tap:tap,enable:true) }
            } else if (type == .leftMouseDown || type == .rightMouseDown) && !IsSecureEventInputEnabled() {
                monitor.onClick?(event.location)
            } else if type == .keyDown && !IsSecureEventInputEnabled() {
                let key = event.getIntegerValueField(.keyboardEventKeycode)
                let navigation: Set<Int64> = [48,51,53,71,115,116,117,119,121,123,124,125,126]
                if !navigation.contains(key) && !event.flags.contains(.maskCommand) && !event.flags.contains(.maskControl) {
                    monitor.onKey?(event)
                }
            }
            return Unmanaged.passUnretained(event)
        },userInfo:pointer)
        guard let tap = tap else { return }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault,tap,0)
        CFRunLoopAddSource(CFRunLoopGetMain(),source,.commonModes)
        CGEvent.tapEnable(tap:tap,enable:true)
    }
    func stop() {
        if let source = source { CFRunLoopRemoveSource(CFRunLoopGetMain(),source,.commonModes) }
        if let tap = tap { CFMachPortInvalidate(tap) }
        tap = nil;source = nil
    }
}
final class PetWindow: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class AppDelegate: NSObject,NSApplicationDelegate {
    let motion = PetMotion()
    let swarm = SwarmMotion()
    var swarmItems: [NSMenuItem] = []
    let tracker = CaretTracker()
    let keyboard = InputMonitor()
    var renderer: PetRenderer!
    var windows:[PetWindow] = []
    var views:[OverlayView] = []
    var statusItem: NSStatusItem!
    var statusRow = NSMenuItem(title:"正在连接输入位置…",action:nil,keyEquivalent:"")
    var timer: Timer?
    var start = ProcessInfo.processInfo.systemUptime
    var lastFrame = ProcessInfo.processInfo.systemUptime
    var lastExact: Double = -100
    var lastApp = ""
    var lastStatus = ""
    var manualTarget: V?
    var demo = false
    var hidden = false
    var paused = false
    var screenIndex = 0
    var previousBounds = CGRect.zero
    var demoStart: Double = 0
    var lastDemoKey = 0.0
    var demoLetterIndex = 0
    var ticks = 0
    var inputCount = 0
    var clickCount = 0
    var diagnosticURL: URL?
    var showLetters = UserDefaults.standard.object(forKey:"showLetters") == nil ? true : UserDefaults.standard.bool(forKey:"showLetters")
    var lettersItem: NSMenuItem!
    var lettersCarried = 0
    var letterDistanceItems: [NSMenuItem] = []
    var skins: [PetSkin] = []
    var skinItems: [NSMenuItem] = []
    var nameRow: NSMenuItem!
    var boundaryItem: NSMenuItem!
    var catsSwayItem: NSMenuItem!
    var catsTailItem: NSMenuItem!
    var boundaryActionItems: [NSMenuItem] = []
    var hostDisplayID: UInt32?
    var hostBackingScale = 1.0
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let i = CommandLine.arguments.firstIndex(of:"--health-file"),CommandLine.arguments.count > i+1 {
            diagnosticURL = URL(fileURLWithPath:CommandLine.arguments[i+1])
        }
        renderer = PetRenderer(assetURL:Bundle.main.resourceURL!.appendingPathComponent("mantle.png"))
        skins = PetSkin.catalog(in:Bundle.main.resourceURL!)
        var selectedSkin = UserDefaults.standard.string(forKey:"petSkin") ?? "original"
        if let i = CommandLine.arguments.firstIndex(of:"--skin"),CommandLine.arguments.count > i+1 {
            selectedSkin = CommandLine.arguments[i+1]
        }
        if let skin = skins.first(where:{$0.id == selectedSkin}) {
            renderer.setSkin(skin,resources:Bundle.main.resourceURL!)
            motion.configure(skin.form)
        }
        motion.scale = UserDefaults.standard.double(forKey:"petScale")
        if motion.scale < 0.5 { motion.scale = 1 }
        motion.boundary.enabled = UserDefaults.standard.object(forKey:"boundaryPlay") == nil ? true : UserDefaults.standard.bool(forKey:"boundaryPlay")
        motion.fiveCats.swayEnabled = UserDefaults.standard.object(forKey:"fiveCatsSway") == nil ? true : UserDefaults.standard.bool(forKey:"fiveCatsSway")
        motion.fiveCats.tailPlayEnabled = UserDefaults.standard.object(forKey:"fiveCatsTailPlay") == nil ? true : UserDefaults.standard.bool(forKey:"fiveCatsTailPlay")
        motion.fiveCats.reset()
        let gap = UserDefaults.standard.double(forKey:"letterOffset")
        motion.letterOffset = gap >= 30 && gap <= 160 ? gap : 70
        screenIndex = UserDefaults.standard.integer(forKey:"petScreen")
        swarm.select(SwarmStyle(rawValue:UserDefaults.standard.string(forKey:"swarmStyle") ?? ""))
        if let i = CommandLine.arguments.firstIndex(of:"--swarm"),CommandLine.arguments.count>i+1 { swarm.select(SwarmStyle(rawValue:CommandLine.arguments[i+1])) }
        swarm.reducedMotion = UserDefaults.standard.bool(forKey:"swarmReducedMotion")
        swarm.intensity = UserDefaults.standard.bool(forKey:"swarmLowGlow") ? 0.25 : 0.65
        let verifySwarm = CommandLine.arguments.contains("--verify-swarm")
        let verifySwarmStartup = CommandLine.arguments.contains("--verify-swarm-startup")
        let verifySkins = CommandLine.arguments.contains("--verify-skins")
        let verifyBoundary = CommandLine.arguments.contains("--verify-boundary")
        let verifyCatGroup = CommandLine.arguments.contains("--verify-cat-group")
        let verifyDisabledStartup = CommandLine.arguments.contains("--verify-disabled-startup")
        let verifyCatsStartup = CommandLine.arguments.contains("--verify-cats-disabled-startup")
        let verifyTailStartup = CommandLine.arguments.contains("--verify-tails-disabled-startup")
        if verifySwarm || verifySwarmStartup || verifySkins || verifyBoundary || verifyCatGroup || verifyDisabledStartup || verifyCatsStartup || verifyTailStartup { hidden = true }
        setupMenu();setupWindows();refreshSwarmMenu()
        if verifySwarmStartup,let i = CommandLine.arguments.firstIndex(of:"--verify-swarm-startup") {
            precondition(swarm.style?.rawValue == CommandLine.arguments[i+1])
            precondition(swarm.reducedMotion == (CommandLine.arguments[i+2]=="1"))
            precondition((swarm.intensity<0.5) == (CommandLine.arguments[i+3]=="1"))
            print("PASS: swarm preferences restored in new process");NSApp.terminate(nil);return
        }
        if verifySwarm { verifySwarmControls();NSApp.terminate(nil);return }
        if verifyTailStartup {
            precondition(motion.kind == .fivecats && !motion.fiveCats.tailPlayEnabled && catsTailItem.state == .off && !catsTailItem.isHidden)
            print("PASS: a new app process restored disabled tail flourishes")
            NSApp.terminate(nil);return
        }
        if verifyCatsStartup {
            precondition(motion.kind == .fivecats && !motion.fiveCats.swayEnabled && motion.fiveCats.strength == 0)
            precondition(catsSwayItem.state == .off && !catsSwayItem.isHidden && boundaryItem.isEnabled)
            precondition(motion.boundary.phase == .resting)
            print("PASS: a new app process restored disabled five-cat sway")
            NSApp.terminate(nil);return
        }
        if verifyDisabledStartup {
            precondition(!motion.boundary.enabled && motion.boundary.phase == .resting && motion.boundary.position == motion.boundary.home)
            precondition(boundaryItem.state == .off && boundaryActionItems.allSatisfy {!$0.isEnabled})
            if motion.kind == .fivecats { precondition(!motion.fiveCats.formation.enabled && motion.fiveCats.formation.phase == .seated) }
            print("PASS: a new app process restored disabled locomotion without an entrance animation")
            NSApp.terminate(nil);return
        }
        if verifySkins {
            verifySkinSwitching();NSApp.terminate(nil);return
        }
        if verifyBoundary { verifyBoundaryControls();NSApp.terminate(nil);return }
        if verifyCatGroup { verifyCatGroupControls();NSApp.terminate(nil);return }
        tracker.onSample = { [weak self] sample in self?.receive(sample) }
        keyboard.onKey = { [weak self] event in
            guard let self = self,!self.paused,!self.hidden,!self.demo else { return }
            if self.swarm.style != nil { self.handleSwarmKey(event);return }
            self.inputCount += 1
            let index = self.motion.nextArm
            let generation = self.motion.generation
            let oldSerial = self.motion.arms[index].strikeCount
            self.motion.input(at:ProcessInfo.processInfo.systemUptime-self.start)
            let serial = self.motion.arms[index].strikeCount
            guard serial != oldSerial,self.showLetters,let copy = event.copy() else { return }
            let expectedApp = self.lastApp,queuedAt = ProcessInfo.processInfo.systemUptime
            self.tracker.queue.async { [weak self] in
                guard let self = self,ProcessInfo.processInfo.systemUptime-queuedAt < 0.18 else { return }
                // Recheck the focused field before extracting the letter. Never persist labels.
                let sample = self.tracker.reader.read()
                guard sample.rect != nil,sample.app == expectedApp,!IsSecureEventInputEnabled() else { return }
                var buffer = [UniChar](repeating:0,count:16),length = 0
                copy.keyboardGetUnicodeString(maxStringLength:16,actualStringLength:&length,unicodeString:&buffer)
                var label = String(utf16CodeUnits:buffer,count:min(length,16))
                let key = copy.getIntegerValueField(.keyboardEventKeycode)
                if key == 49 { label = "␣" }
                if key == 36 || key == 76 { label = "↵" }
                guard let first = label.first,!String(first).unicodeScalars.contains(where:{CharacterSet.controlCharacters.contains($0)}) else { return }
                let glyph = String(first)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,self.showLetters,!self.paused,!self.hidden,
                          self.motion.generation == generation,index < self.motion.arms.count,
                          self.lastApp == expectedApp,self.lastStatus != "secure-input",
                          ProcessInfo.processInfo.systemUptime-queuedAt < 0.22,
                          self.motion.target != nil,!IsSecureEventInputEnabled() else { return }
                    if self.motion.arms[index].acceptGlyph(glyph,forStrike:serial,at:ProcessInfo.processInfo.systemUptime-self.start) {
                        self.lettersCarried += 1
                    }
                }
            }
        }
        keyboard.onClick = { [weak self] point in
            guard let self = self,!self.paused,!self.hidden,!self.demo,let primary = NSScreen.screens.first else { return }
            self.clickCount += 1
            if self.swarm.style != nil { self.swarm.emit(at:V(point.x,primary.frame.maxY-point.y),click:true);return }
            self.motion.click(at:V(point.x,primary.frame.maxY-point.y),time:ProcessInfo.processInfo.systemUptime-self.start)
        }
        tracker.start();keyboard.start()
        NotificationCenter.default.addObserver(self,selector:#selector(screensChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(woke),name:NSWorkspace.didWakeNotification,object:nil)
        timer = Timer(timeInterval:1.0/60,target:self,selector:#selector(tick),userInfo:nil,repeats:true)
        RunLoop.main.add(timer!,forMode:.common)
        if CommandLine.arguments.contains("--demo") { demo = true;demoStart = 0 }
        if !AXIsProcessTrusted() {
            statusRow.title = "需要辅助功能权限 · 点菜单授权"
        }
    }
    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        statusItem.button?.title = "🐙"
        let menu = NSMenu()
        nameRow = NSMenuItem(title:renderer.skin.name,action:nil,keyEquivalent:"")
        menu.addItem(nameRow)
        menu.addItem(statusRow);menu.addItem(.separator())
        let skinRoot = NSMenuItem(title:"更换角色 / 皮肤",action:nil,keyEquivalent:"")
        let skinMenu = NSMenu()
        for skin in skins {
            if skin.id == "slime" { skinMenu.addItem(.separator()) }
            let it = NSMenuItem(title:skin.name,action:#selector(setSkin(_:)),keyEquivalent:"")
            it.representedObject = skin.id;it.target = self
            it.state = renderer.skin.id == skin.id ? .on : .off
            skinMenu.addItem(it);skinItems.append(it)
        }
        skinRoot.submenu = skinMenu;menu.addItem(skinRoot)
        setupSwarmMenu(menu)
        func item(_ title: String,_ selector: Selector,_ key: String = "") {
            let it = NSMenuItem(title:title,action:selector,keyEquivalent:key);it.target = self;menu.addItem(it)
        }
        item("暂停 / 继续",#selector(togglePause))
        item("隐藏 / 显示",#selector(toggleHidden))
        catsSwayItem = NSMenuItem(title:"五只小猫一起摇摆",action:#selector(toggleCatsSway),keyEquivalent:"")
        catsSwayItem.target = self;catsSwayItem.state = motion.fiveCats.swayEnabled ? .on : .off
        catsSwayItem.isHidden = motion.kind != .fivecats;menu.addItem(catsSwayItem)
        catsTailItem = NSMenuItem(title:"尾巴小动作：轻扫、卷尾与甩尾",action:#selector(toggleCatsTail),keyEquivalent:"")
        catsTailItem.target = self;catsTailItem.state = motion.fiveCats.tailPlayEnabled ? .on : .off
        catsTailItem.toolTip = "关闭待机尾巴小动作；打字与点击时仍能伸尾递字。"
        catsTailItem.isHidden = motion.kind != .fivecats;menu.addItem(catsTailItem)
        item("演示当前角色动画",#selector(toggleDemo))
        lettersItem = NSMenuItem(title:"显示递送的字母",action:#selector(toggleLetters),keyEquivalent:"")
        lettersItem.target = self;lettersItem.state = showLetters ? .on : .off;menu.addItem(lettersItem)
        let distanceRoot = NSMenuItem(title:"字牌与输入区的距离",action:nil,keyEquivalent:"")
        let distanceMenu = NSMenu()
        for (name,value) in [("近 · 45 像素",45),("适中 · 70 像素",70),("远 · 100 像素",100)] {
            let it = NSMenuItem(title:name,action:#selector(setLetterDistance(_:)),keyEquivalent:"")
            it.tag = value;it.target = self;it.state = Int(motion.letterOffset)==value ? .on : .off
            distanceMenu.addItem(it);letterDistanceItems.append(it)
        }
        distanceRoot.submenu = distanceMenu;menu.addItem(distanceRoot)
        item("3 秒后将鼠标位置设为备用目标",#selector(pinTarget))
        item("恢复自动追踪文字光标",#selector(autoTarget))
        menu.addItem(.separator())
        item("放大",#selector(grow));item("缩小",#selector(shrink))
        item("本体移到下一个屏幕",#selector(nextScreen))
        menu.addItem(.separator())
        let boundaryRoot = NSMenuItem(title:"屏幕边框互动",action:nil,keyEquivalent:"")
        let boundaryMenu = NSMenu();boundaryMenu.autoenablesItems = false
        boundaryItem = NSMenuItem(title:"行走与攀爬动画",action:#selector(toggleBoundary),keyEquivalent:"")
        boundaryItem.toolTip = "关闭后固定在右下角；打字、点击和送字母仍然有效。"
        boundaryItem.target = self;boundaryItem.state = motion.boundary.enabled ? .on : .off;boundaryMenu.addItem(boundaryItem)
        boundaryItem.isEnabled = true
        if motion.kind == .fivecats { boundaryItem.title = "五猫屏幕互动：跟随、攀爬与探头" }
        for (title,action) in [("现在展示边框动作",#selector(showBoundary)),("扒着右边框探头送字",#selector(peekBoundary)),("固定在右下角",#selector(homeBoundary))] {
            let entry = NSMenuItem(title:title,action:action,keyEquivalent:"");entry.target = self;boundaryMenu.addItem(entry)
            if action != #selector(homeBoundary) { entry.isEnabled = motion.boundary.enabled;boundaryActionItems.append(entry) }
        }
        boundaryRoot.submenu = boundaryMenu;menu.addItem(boundaryRoot)
        menu.addItem(.separator())
        item("授予辅助功能权限…",#selector(requestAccessibility))
        item("打开输入监控设置…",#selector(requestInput))
        item("重新连接输入监听",#selector(reconnect))
        item("退出桌宠",#selector(quit),"q")
        statusItem.menu = menu
    }
    func setupWindows(enter: Bool = false) {
        for win in windows { win.orderOut(nil) }
        windows.removeAll();views.removeAll()
        let screens = NSScreen.screens
        swarm.layout(screens.map {$0.frame})
        guard !screens.isEmpty else { return }
        if let id = hostDisplayID,let index = screens.firstIndex(where:{displayID($0)==id}) { screenIndex = index }
        screenIndex = min(max(screenIndex,0),screens.count-1)
        let host = screens[screenIndex]
        hostDisplayID = displayID(host);hostBackingScale = host.backingScaleFactor
        motion.place(frame:host.frame,visible:host.visibleFrame,enter:enter || !motion.boundary.configured)
        for screen in screens {
            let window = PetWindow(contentRect:screen.frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            window.setFrame(screen.frame,display:true)
            window.isOpaque = false;window.backgroundColor = .clear;window.hasShadow = false
            window.level = .floating;window.ignoresMouseEvents = true
            window.hidesOnDeactivate = false;window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.stationary,.ignoresCycle]
            let view = OverlayView(frame:CGRect(origin:.zero,size:screen.frame.size),motion:motion,renderer:renderer)
            view.swarm = swarm
            view.screenOrigin = V(screen.frame.origin)
            window.contentView = view
            if !hidden { window.orderFrontRegardless() }
            windows.append(window);views.append(view)
        }
        previousBounds = .zero
    }
    func receive(_ sample: CaretSample) {
        guard !demo else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if sample.app != lastApp { swarm.clear();motion.invalidateTarget();lastExact = -100;lastApp = sample.app }
        if let r = sample.rect,let primary = NSScreen.screens.first {
            let rect = appKitRect(fromAX:r,primaryHeight:primary.frame.maxY)
            let point = CGPoint(x:rect.midX,y:rect.minY-3)
            if NSScreen.screens.contains(where:{$0.frame.insetBy(dx:-2,dy:-2).contains(point)}) {
                motion.target = manualTarget ?? V(point);lastExact = now
            } else { motion.invalidateTarget() }
        } else if sample.status == "secure-input" || sample.status == "selection-active" || now-lastExact > 0.18 {
            motion.target = sample.status == "secure-input" ? nil : manualTarget
            if sample.status == "secure-input" { swarm.clear();motion.lastInput = -100;motion.energy = 0;motion.invalidateTarget(all:true) }
        }
        if lastStatus != sample.status {
            lastStatus = sample.status
            let descriptions = ["exact":"已连接文字光标","exact-marker":"已连接富文本光标",
                                "character-edge":"已连接 · 根据字符边界定位",
                                "permission-required":"需要辅助功能权限","secure-input":"安全输入 · 已收手",
                                "selection-active":"文字选择中","range-unavailable":"此输入区暂不提供光标位置",
                                "caret-bounds-unavailable":"暂未获得光标坐标","no-focused-element":"等待文字输入",
                                "no-focused-app":"等待前台应用"]
            statusRow.title = descriptions[sample.status] ?? sample.status
        }
    }
    @objc func tick() {
        let absolute = ProcessInfo.processInfo.systemUptime
        let now = absolute-start,dt = absolute-lastFrame;lastFrame = absolute;ticks += 1
        if ticks % 120 == 0,let host = NSScreen.screens.first(where:{displayID($0)==hostDisplayID}),
           (host.frame != motion.boundary.frame || host.visibleFrame != motion.boundary.area || host.backingScaleFactor != hostBackingScale) {
            setupWindows()
        }
        if ticks % 180 == 0 && keyboard.tap == nil && AXIsProcessTrusted() { keyboard.start() }
        if ticks % 60 == 0,let url = diagnosticURL {
            var health:[String:Any] = ["trusted":AXIsProcessTrusted(),"inputConnected":keyboard.tap != nil,
                                      "inputCount":inputCount,"screens":windows.count,"status":lastStatus,"app":lastApp,
                                      "reaching":motion.reaching,"demo":demo,"uptime":now]
            health["armStrikes"] = motion.arms.map {$0.strikeCount}
            health["clickCount"] = clickCount
            health["lettersCarried"] = lettersCarried
            health["letterOffset"] = motion.letterOffset
            health["skin"] = renderer.skin.id
            health["characterKind"] = motion.kind.rawValue
            health["version"] = Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown"
            health["motionMode"] = swarm.style == nil ? "concurrent" : "swarm"
            health["swarmStyle"] = swarm.style?.rawValue ?? "none"
            health["swarmParticles"] = swarm.count
            health["swarmWaves"] = swarm.totalWaves
            health["swarmLetters"] = swarm.totalLetters
            health["swarmReducedMotion"] = swarm.reducedMotion
            health["swarmStyles"] = SwarmStyle.allCases.map {$0.rawValue}
            health["gaitCycle"] = motion.locomotion.cycle
            health["fiveCatsSway"] = motion.fiveCats.swayEnabled
            if motion.kind == .fivecats {
                health["fiveCatsGroupPhase"] = motion.fiveCats.formation.phase.rawValue
                health["fiveCatsRig"] = "spine-spline/head/ears/4x-two-bone-IK/tail-spline"
                health["fiveCatsTailPlay"] = motion.fiveCats.tailPlayEnabled
                health["fiveCatsTails"] = motion.arms.map {["phase":$0.catTail?.phase.rawValue ?? "none","mood":$0.catTail?.mood.rawValue ?? "none"]}
            }
            health["boundary"] = ["phase":motion.boundary.phase.rawValue,"enabled":motion.boundary.enabled,
                                   "displayID":hostDisplayID ?? 0,"backingScale":hostBackingScale,
                                   "frame":rectValues(motion.boundary.frame),"usable":rectValues(motion.boundary.area),
                                   "position":[motion.boundary.position.x,motion.boundary.position.y],"impacts":motion.boundary.impactCount]
            health["availableSkins"] = skins.map {$0.id}
            health["bodyOffset"] = ["x":motion.body.x-motion.anchor.x,"y":motion.body.y-motion.anchor.y]
            if let p = motion.target { health["target"] = ["x":p.x,"y":p.y] }
            if let data = try? JSONSerialization.data(withJSONObject:health,options:[.sortedKeys,.prettyPrinted]) {
                try? data.write(to:url,options:.atomic)
            }
        }
        if demo {
            let t = now-demoStart
            let base = NSScreen.screens[safe:screenIndex]?.visibleFrame ?? CGRect(x:0,y:0,width:1200,height:800)
            let phase = t.truncatingRemainder(dividingBy:14)
            if phase > 1 && phase < 10.5 {
                let x = phase < 5 ? base.minX+base.width*0.24+(phase-1)*24 : base.minX+base.width*0.53+(phase-5)*17
                let y = phase < 5 ? base.minY+base.height*0.72 : base.minY+base.height*0.45
                motion.target = V(x,y)
                if now-lastDemoKey > 0.12 {
                    if swarm.style != nil,let target = motion.target,let token = swarm.emit(at:target) {
                        if showLetters { _ = swarm.accept(String(Array("firefly")[demoLetterIndex%7]),for:token);demoLetterIndex += 1 }
                    }
                    let index = motion.nextArm;motion.input(at:now)
                    if showLetters {
                        let arm = motion.arms[index]
                        _ = arm.acceptGlyph(String(Array("octopus")[demoLetterIndex%7]),forStrike:arm.strikeCount,at:now)
                        demoLetterIndex += 1
                    }
                    lastDemoKey = now
                }
            } else { motion.target = nil }
            statusRow.title = "演示模式 · 菜单中可关闭"
        } else if absolute-lastExact > 0.35 && manualTarget == nil { motion.invalidateTarget() }
        if hidden { return }
        swarm.paused = paused;swarm.scale = motion.scale;swarm.gap = motion.letterOffset
        if swarm.style != nil {
            swarm.step(dt)
            let bounds = swarm.drawingBounds
            let dirty = bounds.union(previousBounds);previousBounds = bounds
            if !dirty.isNull { for view in views { view.setNeedsDisplay(dirty.offsetBy(dx:-view.screenOrigin.x,dy:-view.screenOrigin.y)) } }
            return
        }
        // Idle is 30 fps; reaching and active typing are 60 fps.
        let animating = motion.reaching || motion.boundary.busy
        if !animating && motion.energy < 0.05 && ticks % 2 == 0 { return }
        motion.paused = paused;motion.step(to:now,dt:animating ? dt : dt*2)
        var bounds = CGRect(x:motion.body.x-110*motion.scale,y:motion.body.y-95*motion.scale,width:220*motion.scale,height:190*motion.scale)
        for arm in motion.arms {
            for p in arm.nodes { bounds = bounds.union(CGRect(x:p.x-18*motion.scale,y:p.y-18*motion.scale,width:36*motion.scale,height:36*motion.scale)) }
            if arm.glyph != nil {
                let p = arm.deliveredAt > 0 ? arm.deliveredPoint : arm.letterAnchor(distance:motion.letterOffset*motion.scale)
                bounds = bounds.union(CGRect(x:p.x-40*motion.scale,y:p.y-20*motion.scale,width:80*motion.scale,height:90*motion.scale))
            }
        }
        if motion.boundary.configured { bounds = bounds.union(motion.boundary.drawingBounds) }
        if motion.kind == .fivecats {
            let r = motion.fiveCats.bounds
            bounds = bounds.union(CGRect(x:motion.body.x+r.minX*motion.scale,y:motion.body.y+r.minY*motion.scale,width:r.width*motion.scale,height:r.height*motion.scale))
        }
        let dirty = bounds.union(previousBounds);previousBounds = bounds
        for view in views {
            view.setNeedsDisplay(dirty.offsetBy(dx:-view.screenOrigin.x,dy:-view.screenOrigin.y))
        }
    }
    @objc func screensChanged() { manualTarget = nil;motion.invalidateTarget(all:true);setupWindows() }
    @objc func woke() { motion.invalidateTarget(all:true);keyboard.stop();keyboard.start();setupWindows() }
    @objc func togglePause() { paused.toggle();motion.paused = paused;motion.invalidateTarget();statusRow.title = paused ? "已暂停" : "已继续" }
    @objc func toggleHidden() { hidden.toggle();swarm.clear();motion.clearLetters();for win in windows { hidden ? win.orderOut(nil) : win.orderFrontRegardless() } }
    @objc func toggleDemo() { demo.toggle();swarm.clear();demoStart = ProcessInfo.processInfo.systemUptime-start;motion.invalidateTarget();lastStatus = "" }
    @objc func pinTarget() {
        statusRow.title = "请将鼠标移到目标位置…"
        DispatchQueue.main.asyncAfter(deadline:.now()+3) { [weak self] in
            self?.manualTarget = V(NSEvent.mouseLocation);self?.motion.target = self?.manualTarget
            self?.statusRow.title = "已使用手动目标 · 菜单可恢复自动"
        }
    }
    @objc func autoTarget() { manualTarget = nil;motion.invalidateTarget();lastStatus = "" }
    @objc func toggleLetters() {
        showLetters.toggle();UserDefaults.standard.set(showLetters,forKey:"showLetters")
        lettersItem.state = showLetters ? .on : .off
        if !showLetters { swarm.clearLetters();motion.clearLetters() }
    }
    @objc func setSkin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let skin = skins.first(where:{$0.id == id}),
              renderer.setSkin(skin,resources:Bundle.main.resourceURL!) else { return }
        swarm.select(nil);UserDefaults.standard.removeObject(forKey:"swarmStyle")
        UserDefaults.standard.set(id,forKey:"petSkin")
        nameRow.title = skin.name
        let changedForm = motion.kind != skin.form
        motion.configure(skin.form)
        if changedForm { setupWindows(enter:true) }
        saveBoundary();catsSwayItem.isHidden = motion.kind != .fivecats;catsTailItem.isHidden = motion.kind != .fivecats
        for item in skinItems { item.state = item.representedObject as? String == id ? .on : .off }
        refreshSwarmMenu()
    }
    func verifySkinSwitching() {
        // Exercises the real menu action without installing event taps or showing overlays.
        let previousSwarm = UserDefaults.standard.object(forKey:"swarmStyle")
        let previous = UserDefaults.standard.object(forKey:"petSkin")
        let previousSway = UserDefaults.standard.object(forKey:"fiveCatsSway")
        let previousTail = UserDefaults.standard.object(forKey:"fiveCatsTailPlay")
        defer {
            if let previousSwarm = previousSwarm { UserDefaults.standard.set(previousSwarm,forKey:"swarmStyle") } else { UserDefaults.standard.removeObject(forKey:"swarmStyle") }
            if let previous = previous { UserDefaults.standard.set(previous,forKey:"petSkin") }
            else { UserDefaults.standard.removeObject(forKey:"petSkin") }
            if let previousSway = previousSway { UserDefaults.standard.set(previousSway,forKey:"fiveCatsSway") }
            else { UserDefaults.standard.removeObject(forKey:"fiveCatsSway") }
            if let previousTail = previousTail { UserDefaults.standard.set(previousTail,forKey:"fiveCatsTailPlay") }
            else { UserDefaults.standard.removeObject(forKey:"fiveCatsTailPlay") }
            UserDefaults.standard.synchronize()
        }
        precondition(skins.count == 22 && skinItems.count == 22,"Original, 20 existing looks and the five-kitten scene required")
        var checked: [[String:Any]] = []
        for item in skinItems {
            setSkin(item)
            let id = item.representedObject as! String
            precondition(renderer.skin.id == id && motion.kind == renderer.skin.form)
            precondition(motion.arms.count == motion.kind.armCount)
            precondition(skinItems.filter {$0.state == .on}.count == 1 && item.state == .on)
            precondition(UserDefaults.standard.string(forKey:"petSkin") == id)
            precondition(renderer.mantle != nil)
            if motion.kind == .fivecats {
                precondition(renderer.fiveCatsArtwork?.meshes.count == 5 && motion.arms.count == 5)
                precondition(motion.boundary.phase == .resting && boundaryItem.isEnabled && !catsSwayItem.isHidden)
                if motion.fiveCats.swayEnabled { toggleCatsSway() }
                precondition(catsSwayItem.state == .off && !UserDefaults.standard.bool(forKey:"fiveCatsSway"))
                UserDefaults.standard.synchronize()
                let relaunched = Process();relaunched.executableURL = Bundle.main.executableURL
                relaunched.arguments = ["--verify-cats-disabled-startup","--skin","five-kittens"]
                try! relaunched.run();relaunched.waitUntilExit();precondition(relaunched.terminationStatus == 0)
                toggleCatsSway();precondition(catsSwayItem.state == .on && UserDefaults.standard.bool(forKey:"fiveCatsSway"))
                if motion.fiveCats.tailPlayEnabled { toggleCatsTail() }
                precondition(catsTailItem.state == .off && !UserDefaults.standard.bool(forKey:"fiveCatsTailPlay"))
                UserDefaults.standard.synchronize()
                let tails = Process();tails.executableURL = Bundle.main.executableURL
                tails.arguments = ["--verify-tails-disabled-startup","--skin","five-kittens"]
                try! tails.run();tails.waitUntilExit();precondition(tails.terminationStatus == 0)
                toggleCatsTail();precondition(catsTailItem.state == .on && UserDefaults.standard.bool(forKey:"fiveCatsTailPlay"))
            }
            checked.append(["id":id,"kind":motion.kind.rawValue,"limbs":motion.arms.count])
        }
        let result: [String:Any] = ["passed":true,"menuActionsChecked":checked,"fiveCatsSwayToggleAndRestart":true,"fiveCatsTailToggleAndRestart":true,"inputMonitoringStarted":keyboard.tap != nil]
        let data = try! JSONSerialization.data(withJSONObject:result,options:[.sortedKeys,.prettyPrinted])
        if let url = diagnosticURL { try! data.write(to:url,options:.atomic) }
        print(String(data:data,encoding:.utf8)!)
    }
    func verifyBoundaryControls() {
        let saved = UserDefaults.standard.object(forKey:"boundaryPlay")
        defer {
            if let saved = saved { UserDefaults.standard.set(saved,forKey:"boundaryPlay") }
            else { UserDefaults.standard.removeObject(forKey:"boundaryPlay") }
            UserDefaults.standard.synchronize()
        }
        if !motion.kind.canRoam { motion.configure(.octopus);setupWindows(enter:false);saveBoundary() }
        precondition(motion.boundary.configured && windows.count == NSScreen.screens.count)
        homeBoundary();precondition(!motion.boundary.enabled && boundaryItem.state == .off)
        precondition(boundaryActionItems.allSatisfy {!$0.isEnabled})
        showBoundary();peekBoundary()
        precondition(!motion.boundary.enabled && motion.boundary.phase == .resting)
        let time = motion.now
        for frame in 1...1800 { motion.step(to:time+Double(frame)/60,dt:1.0/60) }
        precondition(motion.boundary.position == motion.boundary.home && motion.locomotion.weight == 0)
        precondition(!UserDefaults.standard.bool(forKey:"boundaryPlay"))
        UserDefaults.standard.synchronize()
        let relaunched = Process();relaunched.executableURL = Bundle.main.executableURL
        relaunched.arguments = ["--verify-disabled-startup"]
        try! relaunched.run();relaunched.waitUntilExit();precondition(relaunched.terminationStatus == 0)
        setupWindows(enter:true)
        precondition(!motion.boundary.enabled && motion.boundary.phase == .resting)
        toggleBoundary();precondition(motion.boundary.enabled && boundaryItem.state == .on)
        precondition(boundaryActionItems.allSatisfy {$0.isEnabled})
        showBoundary();precondition(motion.boundary.phase == .walking)
        peekBoundary();precondition(motion.boundary.phase == .peeking)
        let data = try! JSONSerialization.data(withJSONObject:["passed":true,"screens":windows.count,
            "displayID":hostDisplayID ?? 0,"frame":rectValues(motion.boundary.frame),"usable":rectValues(motion.boundary.area),
            "menuActions":["home","toggle","showcase","peek"],"disabledChecks":["30 seconds fixed","showcase cannot reenable","peek cannot reenable","display setup cannot reenable","preference restored in a new app process"],"inputMonitoringStarted":keyboard.tap != nil],options:[.prettyPrinted,.sortedKeys])
        if let url = diagnosticURL { try! data.write(to:url,options:.atomic) };print(String(data:data,encoding:.utf8)!)
    }
    func verifyCatGroupControls() {
        precondition(motion.kind == .fivecats)
        let saved = UserDefaults.standard.object(forKey:"boundaryPlay")
        defer {
            if let saved = saved { UserDefaults.standard.set(saved,forKey:"boundaryPlay") }
            else { UserDefaults.standard.removeObject(forKey:"boundaryPlay") }
            UserDefaults.standard.synchronize()
        }
        if !motion.boundary.enabled { toggleBoundary() }
        precondition(boundaryItem.isEnabled && boundaryActionItems.allSatisfy {$0.isEnabled})
        showBoundary();precondition(motion.fiveCats.formation.phase == .walking)
        for f in 1...930 { motion.step(to:Double(f)/60,dt:1.0/60) }
        precondition(motion.fiveCats.formation.phase == .edge && motion.fiveCats.rigs[4].placement.surface == .wall)
        homeBoundary();precondition(!motion.boundary.enabled && boundaryItem.state == .off)
        showBoundary();peekBoundary()
        for f in 931...1230 { motion.step(to:Double(f)/60,dt:1.0/60) }
        precondition(motion.fiveCats.formation.phase == .seated)
        precondition(boundaryActionItems.allSatisfy {!$0.isEnabled})
        UserDefaults.standard.synchronize()
        let relaunched = Process();relaunched.executableURL = Bundle.main.executableURL
        relaunched.arguments = ["--verify-disabled-startup","--skin","five-kittens"]
        try! relaunched.run();relaunched.waitUntilExit();precondition(relaunched.terminationStatus == 0)
        toggleBoundary();peekBoundary();precondition(motion.fiveCats.formation.phase == .edge)
        let data = try! JSONSerialization.data(withJSONObject:["passed":true,"actions":["showcase","climb","home","disabled actions","new-process off restore","peek"],"inputMonitoringStarted":keyboard.tap != nil],options:[.prettyPrinted,.sortedKeys])
        if let url = diagnosticURL { try! data.write(to:url,options:.atomic) };print(String(data:data,encoding:.utf8)!)
    }
    @objc func setLetterDistance(_ sender: NSMenuItem) {
        motion.letterOffset = Double(sender.tag)
        UserDefaults.standard.set(motion.letterOffset,forKey:"letterOffset")
        for item in letterDistanceItems { item.state = item.tag == sender.tag ? .on : .off }
    }
    @objc func grow() { motion.scale = min(1.6,motion.scale+0.1);saveSize() }
    @objc func shrink() { motion.scale = max(0.65,motion.scale-0.1);saveSize() }
    func saveSize() { UserDefaults.standard.set(motion.scale,forKey:"petScale");setupWindows() }
    @objc func nextScreen() { screenIndex = (screenIndex+1)%max(1,NSScreen.screens.count);hostDisplayID = nil;UserDefaults.standard.set(screenIndex,forKey:"petScreen");setupWindows(enter:true) }
    func displayID(_ screen: NSScreen) -> UInt32 { (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0 }
    func rectValues(_ r: CGRect) -> [Double] { [r.minX,r.minY,r.width,r.height] }
    func saveBoundary() {
        UserDefaults.standard.set(motion.boundary.enabled,forKey:"boundaryPlay")
        boundaryItem.state = motion.boundary.enabled ? .on : .off
        boundaryItem.isEnabled = true
        boundaryItem.title = motion.kind == .fivecats ? "五猫屏幕互动：跟随、攀爬与探头" : "行走与攀爬动画"
        for item in boundaryActionItems { item.isEnabled = motion.boundary.enabled }
    }
    @objc func toggleCatsSway() {
        motion.fiveCats.swayEnabled.toggle()
        catsSwayItem.state = motion.fiveCats.swayEnabled ? .on : .off
        UserDefaults.standard.set(motion.fiveCats.swayEnabled,forKey:"fiveCatsSway")
    }
    @objc func toggleCatsTail() {
        motion.fiveCats.tailPlayEnabled.toggle()
        catsTailItem.state = motion.fiveCats.tailPlayEnabled ? .on : .off
        UserDefaults.standard.set(motion.fiveCats.tailPlayEnabled,forKey:"fiveCatsTailPlay")
    }
    @objc func toggleBoundary() { motion.setLocomotionEnabled(!motion.boundary.enabled);saveBoundary() }
    @objc func showBoundary() {
        guard motion.boundary.enabled else { return };demo = false;motion.invalidateTarget(all:true);motion.lastInput = -100
        if motion.kind == .fivecats { motion.fiveCats.formation.showcase() } else { motion.boundary.showcase() }
    }
    @objc func peekBoundary() {
        guard motion.boundary.enabled else { return };demo = false;motion.invalidateTarget(all:true);motion.lastInput = -100
        if motion.kind == .fivecats { motion.fiveCats.formation.peek() } else { motion.boundary.peek() }
    }
    @objc func homeBoundary() { motion.setLocomotionEnabled(false);saveBoundary() }
    @objc func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func requestInput() {
        _ = CGRequestListenEventAccess()
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }
    @objc func reconnect() { keyboard.stop();keyboard.start();lastStatus = "";statusRow.title = keyboard.tap == nil ? "监听未连接 · 请检查权限" : "输入监听已连接" }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { tracker.stop();keyboard.stop();timer?.invalidate() }
}
extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

@main struct OctopusApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
