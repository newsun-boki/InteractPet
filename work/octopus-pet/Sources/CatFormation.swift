import Foundation
import CoreGraphics

enum CatGroupPhase: String { case seated,walking,edge,homing }
enum CatSurface { case ground,air,wall }
struct CatPlacement {
    var pivot: V
    var rotation = 0.0
    var surface = CatSurface.ground
    var crouch = 0.0
    var attention = 0.0
    var wave = 0.0
    var idle = 1.0
}

/// The group owns choreography; each member owns its pose and planted feet.
/// No input/delivery state enters this scheduler.
final class CatFormation {
    private(set) var phase = CatGroupPhase.seated
    private(set) var elapsed = 0.0
    private(set) var configured = false
    private(set) var enabled = true
    private(set) var visited = Set<String>()
    private(set) var placements = (0..<5).map { CatPlacement(pivot:home($0)) }
    private var returnStart: [CatPlacement] = []
    private var nextPhase = CatGroupPhase.seated
    private var returnDuration = 1.4
    private(set) var travel = 150.0
    private(set) var wall = 208.0
    private(set) var lowPerch = 110.0
    private(set) var highPerch = 192.0
    static func home(_ i: Int) -> V { V(Double(i-2)*74,-48) }
    static func curve(_ a: V,_ b: V,_ c: V,_ d: V,_ t: Double) -> V {
        let u = clamp(t),v = 1-u
        return a*(v*v*v)+b*(3*v*v*u)+c*(3*v*u*u)+d*(u*u*u)
    }
    func configure(area: CGRect,anchor: V,scale: Double,enabled: Bool) {
        self.enabled = enabled;configured = true
        travel = max(0,min(180,(anchor.x-area.minX)/scale-198))
        wall = (area.maxX-anchor.x)/scale-1.2
        highPerch = min(205,(area.maxY-anchor.y)/scale-55)
        lowPerch = min(115,highPerch-55)
        reset()
    }
    func reset() {
        placements = (0..<5).map { CatPlacement(pivot:Self.home($0)) }
        returnStart = [];begin(.seated)
    }
    private func begin(_ phase: CatGroupPhase) {
        self.phase = phase;elapsed = 0;visited.insert(phase.rawValue)
    }
    func setEnabled(_ value: Bool) {
        guard value != enabled else { return }
        enabled = value
        if !value { home() }
    }
    func showcase() { request(.walking) }
    func peek() { request(.edge) }
    private func request(_ phase: CatGroupPhase) {
        guard configured,enabled else { return }
        if self.phase == .seated { begin(phase) }
        else { home(next:phase) }
    }
    func home(next: CatGroupPhase = .seated) {
        guard phase != .seated else { return }
        if phase == .homing { nextPhase = enabled ? next : .seated;return }
        returnStart = placements;nextPhase = enabled ? next : .seated
        returnDuration = max(1.4,placements.map {($0.pivot-Self.home(4)).length/110}.max() ?? 1.4)
        returnDuration = min(3.4,returnDuration);begin(.homing)
    }
    func step(dt: Double,paused: Bool) {
        guard configured,!paused else { return }
        elapsed += dt
        switch phase {
        case .seated:
            placements = (0..<5).map { CatPlacement(pivot:Self.home($0)) }
            if enabled && elapsed > 12 { begin(travel > 20 ? .walking : .edge) }
        case .walking:
            for i in 0..<5 {
                let delay = Double(i)*0.22,backDelay = Double(4-i)*0.22
                let out = smooth((elapsed-0.4-delay)/4)
                let back = smooth((elapsed-6.1-backDelay)/4)
                var p = CatPlacement(pivot:Self.home(i)+V(-travel*(out-back),0))
                p.idle = 0;p.attention = elapsed < 5.5 ? 0.45 : -0.45
                p.crouch = sin(clamp((elapsed-Double(i)*0.12)/0.5)*Double.pi)*0.45
                placements[i] = p
            }
            if elapsed >= 11.4 { begin(.edge) }
        case .edge:
            for i in 0..<5 {
                var p = CatPlacement(pivot:Self.home(i));p.idle = 0.25
                p.attention = smooth(elapsed/0.8)*(1-smooth((elapsed-11)/1.2))
                let salute = elapsed-3.3-Double(i)*0.28
                if salute > 0 && salute < 0.8 { p.wave = sin(salute/0.8*Double.pi)*0.75 }
                let landing = elapsed-11.05-Double(4-i)*0.12
                if landing > 0 && landing < 0.8 { p.crouch = sin(landing/0.8*Double.pi)*0.6 }
                placements[i] = p
            }
            var leader = placements[4];leader.idle = 0;leader.attention = 0
            let h = Self.home(4),low = V(wall,lowPerch),high = V(wall,highPerch)
            if elapsed < 0.55 {
                leader.crouch = sin(elapsed/0.55*Double.pi)*0.9
            } else if elapsed < 1.75 {
                let u = clamp((elapsed-0.55)/1.2)
                leader.pivot = Self.curve(h,h+V(0,100),low+V(-12,45),low,smooth(u))
                leader.rotation = .pi/2*smooth((u-0.12)/0.88)
                leader.surface = .air
            } else if elapsed < 4.75 {
                leader.pivot = mix(low,high,smooth((elapsed-1.75)/3))
                leader.rotation = .pi/2;leader.surface = .wall
            } else if elapsed < 7 {
                leader.pivot = high;leader.rotation = .pi/2;leader.surface = .wall
                leader.attention = sin((elapsed-4.75)*2)*0.7
                leader.wave = pow(sin(clamp((elapsed-4.85)/1.8)*Double.pi),2)
            } else if elapsed < 9.8 {
                leader.pivot = mix(high,low,smooth((elapsed-7)/2.8))
                leader.rotation = .pi/2;leader.surface = .wall
            } else if elapsed < 11 {
                let u = clamp((elapsed-9.8)/1.2)
                leader.pivot = Self.curve(low,low+V(-8,28),h+V(0,65),h,smooth(u))
                leader.rotation = .pi/2*(1-smooth(u/0.8));leader.surface = .air
            }
            placements[4] = leader
            if elapsed >= 12.4 { begin(.seated) }
        case .homing:
            let u = smooth(elapsed/returnDuration)
            for i in 0..<5 {
                let start = returnStart[i],end = Self.home(i)
                var p = CatPlacement(pivot:mix(start.pivot,end,u));p.idle = u
                if start.pivot.y > -20 || start.surface != .ground {
                    p.pivot = Self.curve(start.pivot,start.pivot+V(0,28),end+V(0,70),end,u)
                    p.surface = .air;p.rotation = start.rotation*(1-smooth(u/0.75))
                }
                placements[i] = p
            }
            if elapsed >= returnDuration { begin(enabled ? nextPhase : .seated) }
        }
    }
}
