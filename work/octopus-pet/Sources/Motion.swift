import Foundation
import CoreGraphics

struct V: Equatable {
    var x: Double; var y: Double
    init(_ x: Double = 0, _ y: Double = 0) { self.x = x; self.y = y }
    init(_ p: CGPoint) { x = p.x; y = p.y }
    var point: CGPoint { CGPoint(x: x, y: y) }
    var length: Double { hypot(x, y) }
    var unit: V { self / max(0.001, length) }
    var normal: V { V(-y, x) }
    static func + (a: V, b: V) -> V { V(a.x+b.x, a.y+b.y) }
    static func - (a: V, b: V) -> V { V(a.x-b.x, a.y-b.y) }
    static func * (a: V, b: Double) -> V { V(a.x*b, a.y*b) }
    static func / (a: V, b: Double) -> V { V(a.x/b, a.y/b) }
}
enum PetKind: String, Codable, CaseIterable {
    case octopus,slime,ghost,chameleon,plant,cloud,jellyfish,yarncat,spider,star,robot,fivecats
    var canRoam: Bool { self != .fivecats }
    var homeInset: Double { self == .fivecats ? 212 : 108 }
    var sceneHalfWidth: Double { self == .fivecats ? 202 : 110 }
    var armCount: Int {
        switch self {
        case .octopus: return 8
        case .fivecats: return 5
        case .plant: return 3
        case .jellyfish: return 4
        case .chameleon,.cloud,.yarncat: return 1
        default: return 2
        }
    }
    var idleArms: Bool { self == .octopus || self == .jellyfish }
    var floorInset: Double { self == .jellyfish ? 130 : self == .octopus ? 86 : 92 }
    // Ground contacts measured from the rig-ready artwork's visible alpha bounds.
    var contactHeight: Double {
        switch self {
        case .octopus: return 82
        case .slime: return 50
        case .chameleon: return 55
        case .plant: return 65
        case .yarncat: return 57
        case .spider: return 48
        case .star: return 59
        case .robot: return 70
        case .jellyfish: return 130
        case .ghost: return 80
        case .cloud: return 76
        case .fivecats: return 50
        }
    }
    var reachName: String {
        switch self {
        case .octopus: return "八条触手轮流递字"
        case .slime: return "弹性软糖手 · 送完回弹"
        case .ghost: return "幽灵长袖 · 托字漂浮"
        case .chameleon: return "伸缩卷舌 · 双眼追踪"
        case .plant: return "三条藤蔓 · 叶片夹字"
        case .cloud: return "三色彩虹 · 字母滑行"
        case .jellyfish: return "四条腕带 · 伞盖呼吸"
        case .yarncat: return "编织长尾 · 猫爪递字"
        case .spider: return "双蛛丝 · 吊篮送字"
        case .star: return "双星光飘带 · 闪光送达"
        case .robot: return "双弹簧手臂 · 后仰伸手"
        case .fivecats: return "五猫一起摇 · 卷尾轮流递字"
        }
    }
    func root(_ index: Int) -> V {
        let side = index%2 == 0 ? -1.0 : 1.0,rank = Double(index/2)
        switch self {
        case .octopus: return V(side*(29-rank*4),-31-rank)
        case .slime: return V(side*36,-10)
        case .ghost: return V(side*37,0)
        case .chameleon: return V(-39,17)
        case .plant: return V(Double(index-1)*19,35)
        case .cloud: return V(-37,19)
        case .jellyfish: return V(side*(29-rank*17),-36)
        case .yarncat: return V(43,-9)
        case .spider: return V(side*39,-20)
        case .star: return V(side*42,5)
        case .robot: return V(side*47,-28)
        case .fivecats: return V(Double(index-2)*74+8,-41)
        }
    }
    func rest(_ index: Int) -> V {
        let side = index%2 == 0 ? -1.0 : 1.0,rank = Double(index/2)
        if self == .octopus { return V(side*(91-rank*20),-42-rank*10) }
        if self == .jellyfish { return V(side*(41-rank*19),-99-rank*11) }
        return root(index)+V(side*7,-8)
    }
}
func mix(_ a: V, _ b: V, _ t: Double) -> V { a + (b-a)*t }
func rotated(_ p: V,_ angle: Double) -> V { V(p.x*cos(angle)-p.y*sin(angle),p.x*sin(angle)+p.y*cos(angle)) }
func clamp(_ x: Double, _ a: Double = 0, _ b: Double = 1) -> Double { min(b,max(a,x)) }
func smooth(_ t: Double) -> Double { let v = clamp(t); return v*v*(3-2*v) }
func bezier(_ a: V, _ b: V, _ c: V, _ d: V, _ t: Double) -> V {
    let u = 1-t; return a*(u*u*u) + b*(3*u*u*t) + c*(3*u*t*t) + d*(t*t*t)
}
struct Spring {
    var value = V(); var velocity = V()
    mutating func step(_ target: V, _ dt: Double, _ frequency: Double = 8, _ damping: Double = 0.85) {
        // Implicit damped spring: stable under uneven display timing.
        let w = frequency * 2 * Double.pi
        let f = 1 + 2*dt*damping*w, oo = w*w, hoo = dt*oo, hhoo = dt*hoo
        let inv = 1/(f+hhoo)
        let next = (value*f + velocity*dt + target*hhoo)*inv
        velocity = (velocity + (target-value)*hoo)*inv
        value = next
    }
}
final class Arm {
    let index: Int
    let kind: PetKind
    let catTail: CatTailMotion?
    var nodes = [V](repeating: V(), count: 48)
    var springs = [Spring](repeating: Spring(), count: 48)
    var reachAmount: Double = 0
    var tapAt: Double = -100
    var initialized = false
    var heldTarget: V?
    var aimSpring = Spring()
    var reachUntil: Double = -100
    var contacted = false
    var strikeCount = 0
    var pointerStrike = false
    var glyph: String?
    var deliveredAt: Double = -100
    var deliveredPoint = V()
    var strikeStarted: Double = -100
    var courierStarted: Double = -100
    var courierProgress: Double = 1
    var locomotionWeight: Double = 0
    var acceptsGlyph = false
    var retainedGlyphUntil: Double = -100
    var side: Double { index % 2 == 0 ? -1 : 1 }
    var rank: Double { Double(index/2) }
    init(_ index: Int,kind: PetKind = .octopus) { self.index = index;self.kind = kind;catTail = kind == .fivecats ? CatTailMotion() : nil }
    func strike(at time: Double,target: V,pointer: Bool = false) {
        let continuing = kind.armCount == 1 && !pointer && !pointerStrike &&
            time-strikeStarted < 0.3 && reachAmount > 0.5
        if !continuing { courierStarted = time;courierProgress = 0 }
        if continuing,glyph != nil {
            // Keep the previous card during AX validation, but never retain a
            // stale letter indefinitely when a key has no displayable character.
            if retainedGlyphUntil < 0 { retainedGlyphUntil = time+0.22 }
        } else { glyph = nil;retainedGlyphUntil = -100 }
        strikeStarted = time
        heldTarget = target
        pointerStrike = pointer
        acceptsGlyph = !pointer;deliveredAt = -100
        reachUntil = time+1.8
        contacted = false
        strikeCount += 1
    }
    func clearLetter() { glyph = nil;acceptsGlyph = false;retainedGlyphUntil = -100 }
    func cancel(at time: Double) { reachUntil = min(reachUntil,time);clearLetter() }
    @discardableResult func acceptGlyph(_ text: String,forStrike serial: Int,at time: Double) -> Bool {
        guard acceptsGlyph,!pointerStrike,strikeCount == serial,
              time >= strikeStarted,time-strikeStarted < 0.25 else { return false }
        glyph = text;retainedGlyphUntil = -100;deliveredAt = -100
        return true
    }
    func letterAnchor(distance: Double) -> V {
        guard let tip = nodes.last else { return V() }
        var remaining = max(0,distance)
        if kind == .cloud || kind == .spider || kind == .star {
            let total = zip(nodes.dropFirst(),nodes).reduce(0) { $0+($1.0-$1.1).length }
            remaining = max(remaining,total*(1-courierProgress))
        }
        if remaining == 0 { return tip }
        for i in stride(from:nodes.count-1,through:1,by:-1) {
            let length = (nodes[i]-nodes[i-1]).length
            if length >= remaining && length > 0.001 { return mix(nodes[i],nodes[i-1],remaining/length) }
            remaining -= length
        }
        return nodes[0]
    }
    func update(body: V, home: V, target: V?, now: Double, dt: Double, scale: Double, energy: Double, letterOffset: Double,rootOffset: V? = nil,restRotation: Double = 0,restScale: V = V(1,1),restPose: LimbPose? = nil,restWeight: Double = 0,tailContext: CatTailContext? = nil) {
        func orient(_ p: V) -> V { rotated(V(p.x*restScale.x,p.y*restScale.y),restRotation) }
        let root = body + (rootOffset ?? kind.root(index))*scale
        courierProgress = smooth((now-courierStarted)/0.58)
        if target == nil && !pointerStrike { cancel(at:now) }
        let wantsReach = now < reachUntil
        let rate = wantsReach ? 9.5 : 2.5
        reachAmount += ((wantsReach ? 1.0 : 0.0)-reachAmount)*(1-exp(-rate*dt))
        if let tail = catTail {
            let context = tailContext ?? CatTailContext(clock:now,angle:restRotation,gait:0,expressive:true,paused:false,area:nil)
            tail.update(self,root:root,now:now,dt:dt,scale:scale,context:context)
            resolveDelivery(destination:tail.contactTarget,wantsReach:wantsReach,now:now,scale:scale,letterOffset:letterOffset)
            return
        }
        let support = mix(body,home,0.72*(1-reachAmount))
        let idleEnd = kind == .fivecats ? root+orient(V(side*4,-3))*scale : support + orient(kind.rest(index)+V(0,sin(now*1.8+Double(index))*2.4))*scale
        let restEnd = mix(idleEnd,restPose?.tip ?? idleEnd,restWeight)
        locomotionWeight = restWeight*(1-smooth(reachAmount))
        if !initialized { aimSpring.value = restEnd }
        let before = aimSpring.value
        aimSpring.step(heldTarget ?? restEnd,dt,3.2,0.96)
        let aimTravel = aimSpring.value-before
        let maxAimStep = 3000*scale*dt
        if aimTravel.length > maxAimStep {
            aimSpring.value = before+aimTravel.unit*maxAimStep
            aimSpring.velocity = aimTravel.unit*3000*scale
        }
        let idleA = root + orient(V(side*15,-33))*scale
        let idleB = restEnd + orient(V(side*16,-19))*scale
        let contact = max(0,now-tapAt)
        let tap = contact < 0.25 ? sin(contact/0.25 * .pi)*7*exp(-contact*6) : 0
        let destination = aimSpring.value + V(side*7, -5+tap)*scale
        let reachTip = mix(restEnd, destination, smooth(reachAmount))
        let travel = reachTip-root
        let length = travel.length
        let bow = min((48+rank*19)*scale,length*0.14)
        let bend = travel.unit.normal * (side*bow)
        var reachA = root + orient(V(side*min(75*scale,length*0.15),40*scale)) + travel*0.16
        if kind == .chameleon { reachA = root+orient(V(-min(90*scale,length*0.22),-6*scale)) }
        if kind == .robot { reachA = root+orient(V(side*max(80*scale,min(120*scale,length*0.18)),45*scale)) }
        let reachB = reachTip - travel*0.22 + bend
        for n in 0..<nodes.count {
            let t = Double(n)/Double(nodes.count-1)
            let rest = bezier(root,idleA,idleB,restEnd,t)
            let gait = restPose.map { bezier(root,mix(root,$0.knee,0.75),$0.knee,$0.tip,t) } ?? rest
            let idle = mix(rest,gait,restWeight)
            let extended = bezier(root,reachA,reachB,reachTip,t)
            var guide = mix(idle,extended,smooth(reachAmount))
            let waving = sin(t * .pi) * sin(now*3.2-t*6+Double(index)*0.85)
            guide = guide + travel.unit.normal * (waving*min(6*scale,length*0.014)*reachAmount)
            // Small distal curl fades during reaching; no long-arm spring snapping.
            let curl = smooth((t-0.67)/0.33)*(1-smooth(reachAmount))
            guide = guide + orient(V(-side*sin((t-0.67)*9)*5,curl*10))*(scale*(1-restWeight))
            if !initialized { springs[n].value = guide }
            let old = springs[n].value
            springs[n].step(guide,dt,7.5-t*2,0.88)
            // Rejoin the live gait through the same spring as delivery. A foot
            // locks to its support only once the returning limb is close to it.
            if !wantsReach,reachAmount < 0.01,restWeight > 0,(springs[n].value-gait).length < 4*scale {
                springs[n].value = mix(springs[n].value,gait,restWeight)
                springs[n].velocity = springs[n].velocity*(1-restWeight)
            }
            let delta = springs[n].value-old
            let limit = 4200*scale*dt
            if delta.length > limit {
                springs[n].value = old+delta.unit*limit
                springs[n].velocity = delta.unit*4200*scale
            }
            nodes[n] = springs[n].value
        }
        initialized = true
        nodes[0] = root; springs[0].value = root
        // Smooth the centerline without imposing a suddenly shortened rest length.
        // Hard shrinking constraints would snap a cross-screen arm home in one frame.
        let previous = nodes
        for n in 1..<nodes.count-1 {
            nodes[n] = mix(previous[n],mix(previous[n-1],previous[n+1],0.5),0.16)
        }
        resolveDelivery(destination:destination,wantsReach:wantsReach,now:now,scale:scale,letterOffset:letterOffset)
    }
    private func resolveDelivery(destination: V,wantsReach: Bool,now: Double,scale: Double,letterOffset: Double) {
        if wantsReach,!contacted,reachAmount > 0.94,(nodes.last!-destination).length < 16*scale {
            contacted = true;tapAt = now
            reachUntil = max(now+0.14,kind.armCount == 1 && !pointerStrike ? strikeStarted+0.3 : now)
        }
        let holdingCurrentLetter = kind.armCount == 1 && !pointerStrike && now-strikeStarted < 0.3
        if contacted,glyph != nil,deliveredAt < 0,!holdingCurrentLetter {
            deliveredAt = now;deliveredPoint = letterAnchor(distance:letterOffset*scale)
        }
        if retainedGlyphUntil >= 0 && now > retainedGlyphUntil { glyph = nil;retainedGlyphUntil = -100 }
        if glyph != nil && ((deliveredAt > 0 && now-deliveredAt > 0.58) || (!contacted && now > reachUntil)) { glyph = nil }
    }
    func radius(_ t: Double, _ scale: Double) -> Double {
        switch kind {
        case .octopus: return (2.1+12.5*pow(1-t,0.68))*scale
        case .slime: return (3+10*pow(1-t,0.8))*scale
        case .ghost: return (3.5+6.5*pow(1-t,0.7))*scale
        case .chameleon: return (3.1+1.9*(1-t))*scale
        case .plant: return (1.4+2.1*(1-t))*scale
        case .jellyfish: return (1.6+5.4*pow(1-t,1.2))*scale
        case .cloud: return (6+2*(1-t))*scale
        case .yarncat: return 3.3*scale
        case .spider: return 0.75*scale
        case .star: return (2+3*(1-t))*scale
        case .robot: return 5.5*scale
        case .fivecats: return 4.5*scale
        }
    }
}

final class PetMotion {
    let boundary = BoundaryMotion()
    let locomotion = LocomotionRig()
    let fiveCats = FiveCatsMotion()
    var anchor = V(1100,110)
    var scale: Double = 1
    var letterOffset: Double = 70
    var target: V?
    var lastInput: Double = -100
    var now: Double = 0
    var energy: Double = 0
    var bodySpring = Spring()
    var gazeSpring = Spring()
    var leanSpring = Spring()
    var lastInteractionTarget: V?
    var arms = (0..<8).map { Arm($0) }
    private(set) var kind = PetKind.octopus
    private(set) var generation = 0
    var initialized = false
    var nextArm = 0
    var pendingInputAt: Double?
    var paused = false
    var blink: Double = 1
    var nextBlink: Double = 2.7
    var blinkAt: Double = -10
    var body: V { bodySpring.value }
    var characterTilt: Double {
        if kind == .fivecats { return 0 }
        return boundary.rotation+locomotion.lean-leanSpring.value.x*0.075*(kind == .robot ? -0.6 : 1)+sin(now*1.15)*0.01
    }
    var characterStretch: V {
        if kind == .fivecats { return V(1,1) }
        let softness = kind == .slime ? 0.055 : kind == .jellyfish ? 0.038 : 0.012
        let breath = sin(now*(kind == .jellyfish ? 2.8 : 2.1))*softness
        let stretch = min(0.05,leanSpring.value.length*0.05)
        let squash = boundary.compression
        if kind == .slime {
            return V((1+breath+abs(leanSpring.value.x)*0.06+squash)*locomotion.stretch.x,(1-breath-abs(leanSpring.value.x)*0.04+abs(leanSpring.value.y)*0.03-squash)*locomotion.stretch.y)
        }
        return V((1+breath-stretch*0.6+squash*0.6)*locomotion.stretch.x*locomotion.facing,(1-breath+stretch-squash)*locomotion.stretch.y)
    }
    func attachmentOffset(_ index: Int) -> V {
        if kind == .fivecats { return fiveCats.tailRoot(index) }
        let p = kind.root(index)
        guard kind != .octopus else { return rotated(p,boundary.rotation+locomotion.lean) }
        let s = characterStretch,a = characterTilt
        return V(p.x*s.x*cos(a)-p.y*s.y*sin(a),p.x*s.x*sin(a)+p.y*s.y*cos(a))
    }
    var reaching: Bool { arms.contains {$0.reachAmount > 0.015 || now < $0.reachUntil} }
    func place(frame: CGRect,visible: CGRect,enter: Bool) {
        invalidateTarget(all:true)
        boundary.configure(frame:frame,visible:visible,kind:kind,scale:scale,enter:enter)
        locomotion.reset()
        scale = boundary.scale;anchor = boundary.position
        if kind == .fivecats { fiveCats.configure(area:boundary.area,anchor:anchor,scale:scale,enabled:boundary.enabled) }
        bodySpring = Spring(value:anchor,velocity:V());initialized = true
        for arm in arms { arm.initialized = false;arm.reachAmount = 0 }
    }
    func configure(_ next: PetKind) {
        guard next != kind else { return }
        kind = next;generation += 1
        fiveCats.reset()
        locomotion.reset()
        arms = (0..<next.armCount).map { Arm($0,kind:next) }
        nextArm = 0;pendingInputAt = nil;lastInput = -100;energy = 0
        leanSpring = Spring();gazeSpring = Spring()
    }
    func input(at time: Double) {
        guard !paused else { return }
        lastInput = time; energy = min(1,energy+0.28)
        // One input, one arm, strictly round-robin. Reuse a busy arm continuously.
        // There is never an unbounded queue, even under OS key repeat.
        if let target = target {
            arms[nextArm].strike(at:time,target:target)
            lastInteractionTarget = target
            nextArm = (nextArm+1)%arms.count
        } else { pendingInputAt = time }
    }
    func click(at point: V,time: Double) {
        guard !paused else { return }
        lastInput = time;energy = min(1,energy+0.5);lastInteractionTarget = point
        arms[nextArm].strike(at:time,target:point,pointer:true)
        nextArm = (nextArm+1)%arms.count
    }
    func step(to time: Double, dt: Double) {
        now = time
        if let pending = pendingInputAt,let target = target,!paused,time-pending < 0.2 {
            arms[nextArm].strike(at:time,target:target);nextArm = (nextArm+1)%arms.count;pendingInputAt = nil
            lastInteractionTarget = target
        } else if let pending = pendingInputAt,time-pending >= 0.2 { pendingInputAt = nil }
        let step = min(1.0/30,max(1.0/240,dt))
        if kind == .fivecats { fiveCats.step(dt:step,paused:paused,enabled:boundary.enabled,reaches:arms.map {$0.reachAmount}) }
        boundary.step(dt:step,paused:paused)
        locomotion.prepare(kind:kind,boundary:boundary,dt:step,paused:paused)
        if boundary.configured { anchor = boundary.position }
        energy *= exp(-step*3.2)
        let direction = reaching ? ((lastInteractionTarget ?? target ?? anchor)-anchor).unit : V()
        var tension = V()
        var weight = 0.0
        for arm in arms {
            arm.locomotionWeight = 0
            let w = smooth(arm.reachAmount)
            if let tip = arm.nodes.last,arm.initialized {
                tension = tension+(tip-anchor).unit*w
                weight += w
            }
        }
        tension = tension/max(1,weight)
        leanSpring.step(tension,step,2.6,0.76)
        let floatHeight: Double = [.ghost,.cloud,.jellyfish,.star].contains(kind) ? 4.5 : 1.4
        let sway = V(sin(time*1.17)*1.5 + direction.x*3.5,
                     sin(time*2.1)*floatHeight + energy*sin(time*13)*1.5)
        if !initialized { bodySpring.value = anchor; initialized = true }
        let pullFactor = kind == .robot ? -0.65 : kind == .plant ? 0.45 : kind == .fivecats ? 0.25 : 1.0
        // Keep the delivery reaction small while feet are supporting a gait.
        let pull = V(leanSpring.value.x*18,leanSpring.value.y*11)*(pullFactor*(1-locomotion.weight*0.65))
        let bodyGoal = anchor+(sway+pull+locomotion.bodyOffset-V(0,kind.contactHeight*boundary.compression))*scale
        if kind == .fivecats {
            // Per-member skeletons provide reaction and breathing. Keep the
            // group origin stable so planted paws stay on the screen edge.
            bodySpring.value = anchor;bodySpring.velocity = V()
        } else if boundary.configured && boundary.phase == .falling {
            // Gravity is already integrated smoothly. A second spring would make
            // the visible body land after its collision particles have appeared.
            bodySpring.value = bodyGoal;bodySpring.velocity = V()
        } else { bodySpring.step(bodyGoal,step,2.8,0.74) }
        gazeSpring.step(direction*3.4,step,2.8,0.9)
        if time >= nextBlink {
            blinkAt = time; nextBlink = time+3.1+sin(time*1.31)*0.95
        }
        let blinkTime = time-blinkAt
        blink = blinkTime < 0.17 ? max(0.08,abs(blinkTime/0.085-1)) : 1
        locomotion.solve(body:body,angle:characterTilt,stretch:characterStretch,scale:scale,dt:step)
        for arm in arms {
            let aim = paused ? nil : target
            if paused { arm.cancel(at:time) }
            let angle = kind == .fivecats ? fiveCats.angle(arm.index) : kind == .octopus ? boundary.rotation+locomotion.lean : characterTilt
            let pose = locomotion.usesProceduralFeet && arm.index < locomotion.poses.count ? locomotion.poses[arm.index] : nil
            let tailContext = kind == .fivecats ? CatTailContext(clock:fiveCats.time,angle:angle,gait:fiveCats.rigs[arm.index].gaitWeight,expressive:fiveCats.tailPlayEnabled,paused:paused,area:boundary.configured ? boundary.area : nil) : nil
            arm.update(body: body,home:anchor,target: aim,now: time,dt: step,scale: scale,energy: energy,letterOffset:letterOffset,rootOffset:attachmentOffset(arm.index),restRotation:angle,restScale:kind == .octopus ? V(1,1) : characterStretch,restPose:pose,restWeight:pose == nil ? 0 : locomotion.weight,tailContext:tailContext)
        }
    }
    func invalidateTarget(all: Bool = false) {
        target = nil
        for arm in arms where all || !arm.pointerStrike { arm.cancel(at:now) }
        if all { pendingInputAt = nil }
    }
    func clearLetters() { for arm in arms {arm.clearLetter()} }
    func setLocomotionEnabled(_ enabled: Bool) {
        boundary.setEnabled(enabled)
        if kind == .fivecats { fiveCats.formation.setEnabled(enabled) }
        if !enabled {
            locomotion.reset()
            anchor = boundary.home;bodySpring = Spring(value:anchor)
            for arm in arms { arm.locomotionWeight = 0 }
        }
    }
}
