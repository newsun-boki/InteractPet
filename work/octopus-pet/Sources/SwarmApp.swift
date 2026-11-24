import AppKit
import Carbon

extension AppDelegate {
    func setupSwarmMenu(_ menu: NSMenu) {
        let root = NSMenuItem(title:"飞来送字 · 16 款",action:nil,keyEquivalent:"")
        let list = NSMenu();list.autoenablesItems = false
        for style in SwarmStyle.allCases {
            let item = NSMenuItem(title:style.name,action:#selector(selectSwarm(_:)),keyEquivalent:"")
            item.representedObject = style.rawValue;item.target = self;list.addItem(item);swarmItems.append(item)
        }
        list.addItem(.separator())
        let back = NSMenuItem(title:"返回原来的桌宠",action:#selector(leaveSwarm),keyEquivalent:"");back.target = self;list.addItem(back)
        let calm = NSMenuItem(title:"轻柔模式 · 缩短飞行并减少动态",action:#selector(toggleSwarmCalm(_:)),keyEquivalent:"");calm.target = self;calm.state = swarm.reducedMotion ? .on : .off;list.addItem(calm)
        let glow = NSMenuItem(title:"低亮度荧光",action:#selector(toggleSwarmGlow(_:)),keyEquivalent:"");glow.target = self;glow.state = swarm.intensity<0.5 ? .on : .off;list.addItem(glow)
        root.submenu = list;menu.addItem(root)
    }
    func refreshSwarmMenu() {
        for item in swarmItems { item.state = item.representedObject as? String == swarm.style?.rawValue ? .on : .off }
        for item in skinItems { item.state = swarm.style == nil && item.representedObject as? String == renderer.skin.id ? .on : .off }
        nameRow.title = swarm.style?.name ?? renderer.skin.name
        statusItem.button?.title = swarm.style == nil ? "🐙" : "✨"
        catsSwayItem.isHidden = swarm.style != nil || motion.kind != .fivecats
        catsTailItem.isHidden = catsSwayItem.isHidden
        for view in views { view.needsDisplay = true }
        previousBounds = .zero
    }
    @objc func selectSwarm(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,let style = SwarmStyle(rawValue:id) else { return }
        swarm.select(style);motion.invalidateTarget(all:true)
        UserDefaults.standard.set(id,forKey:"swarmStyle");refreshSwarmMenu()
    }
    @objc func leaveSwarm() { swarm.select(nil);UserDefaults.standard.removeObject(forKey:"swarmStyle");refreshSwarmMenu() }
    @objc func toggleSwarmCalm(_ sender: NSMenuItem) {
        swarm.reducedMotion.toggle();swarm.clear();sender.state = swarm.reducedMotion ? .on : .off
        UserDefaults.standard.set(swarm.reducedMotion,forKey:"swarmReducedMotion")
    }
    @objc func toggleSwarmGlow(_ sender: NSMenuItem) {
        swarm.intensity = swarm.intensity<0.5 ? 0.65 : 0.25;sender.state = swarm.intensity<0.5 ? .on : .off
        UserDefaults.standard.set(swarm.intensity<0.5,forKey:"swarmLowGlow")
    }
    func handleSwarmKey(_ event: CGEvent) {
        inputCount += 1
        guard let target = motion.target,let token = swarm.emit(at:target) else { return }
        guard showLetters,let copy = event.copy() else { return }
        let expectedApp = lastApp,queued = ProcessInfo.processInfo.systemUptime
        tracker.queue.async { [weak self] in
            guard let self = self,ProcessInfo.processInfo.systemUptime-queued<0.18 else { return }
            let sample = self.tracker.reader.read()
            guard sample.rect != nil,sample.app == expectedApp,!IsSecureEventInputEnabled() else { return }
            var buffer = [UniChar](repeating:0,count:16),length = 0
            copy.keyboardGetUnicodeString(maxStringLength:16,actualStringLength:&length,unicodeString:&buffer)
            var glyph = String(utf16CodeUnits:buffer,count:min(length,16))
            let key = copy.getIntegerValueField(.keyboardEventKeycode)
            if key == 49 { glyph = "␣" };if key == 36 || key == 76 { glyph = "↵" }
            DispatchQueue.main.async { [weak self] in
                guard let self = self,!self.paused,!self.hidden,self.showLetters,self.lastApp == expectedApp,
                      self.lastStatus != "secure-input",self.motion.target != nil,
                      ProcessInfo.processInfo.systemUptime-queued<0.25,!IsSecureEventInputEnabled() else { return }
                if self.swarm.accept(glyph,for:token) { self.lettersCarried += 1 }
            }
        }
    }
    func verifySwarmControls() {
        let keys = ["swarmStyle","swarmReducedMotion","swarmLowGlow","petSkin"]
        let saved = keys.map { UserDefaults.standard.object(forKey:$0) }
        defer { for (key,value) in zip(keys,saved) { if let value = value { UserDefaults.standard.set(value,forKey:key) } else { UserDefaults.standard.removeObject(forKey:key) } };UserDefaults.standard.synchronize() }
        precondition(swarmItems.count==16 && windows.allSatisfy {$0.ignoresMouseEvents && !$0.canBecomeKey})
        for item in swarmItems {
            selectSwarm(item);precondition(swarmItems.filter {$0.state == .on}.count==1 && skinItems.allSatisfy {$0.state == .off})
            precondition(swarm.style?.rawValue == UserDefaults.standard.string(forKey:"swarmStyle"))
            let r = swarm.screens[0],token = swarm.emit(at:V(r.midX,r.midY))!
            precondition(swarm.accept("a",for:token));swarm.step(0.016);precondition(swarm.count==6)
        }
        let item = NSMenuItem();toggleSwarmCalm(item);toggleSwarmGlow(item)
        let expectedCalm = swarm.reducedMotion,expectedGlow = swarm.intensity<0.5
        UserDefaults.standard.synchronize()
        let child = Process();child.executableURL = Bundle.main.executableURL
        child.arguments = ["--verify-swarm-startup",SwarmStyle.plasma.rawValue,expectedCalm ? "1":"0",expectedGlow ? "1":"0"]
        try! child.run();child.waitUntilExit();precondition(child.terminationStatus==0)
        leaveSwarm();precondition(swarm.style==nil && swarm.waves.isEmpty && skinItems.filter {$0.state == .on}.count==1)
        let data = try! JSONSerialization.data(withJSONObject:["passed":true,"styles":SwarmStyle.allCases.map {$0.rawValue},"menuSwitches":16,"restartPreferences":true,"mousePassthrough":true,"inputMonitoringStarted":keyboard.tap != nil],options:[.prettyPrinted,.sortedKeys])
        if let url = diagnosticURL { try! data.write(to:url) };print(String(data:data,encoding:.utf8)!)
    }
}
