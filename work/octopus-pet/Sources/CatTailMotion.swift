import Foundation
import CoreGraphics

struct CatTailContext {
    var clock: Double
    var angle: Double
    var gait: Double
    var expressive: Bool
    var paused: Bool
    var area: CGRect?
}
enum CatTailPhase: String { case idle,anticipating,extending,tapping,recoiling }
enum CatTailMood: String { case swaying,question,curl,flick,quiet }

/// Eight spring-driven control knots, interpolated by a bounded cubic Hermite
/// spline. The same chain is visible at rest, during delivery, and on return.
final class CatTailMotion {
    private(set) var controls = [V](repeating:V(),count:8)
    private var joints = [Spring](repeating:Spring(),count:8)
    private var extensionSpring = Spring()
    private var serial = 0
    private var preloadUntil = -100.0
    private var impulseAt = -100.0
    private var returnAt = -100.0
    private var wasReaching = false
    private var settling = false
    private(set) var phase = CatTailPhase.idle
    private(set) var mood = CatTailMood.swaying
    private(set) var extensionAmount = 0.0
    private(set) var contactTarget = V()
    private(set) var visited = Set<String>()
    static func sample(_ points: [V],_ u: Double) -> V {
        guard points.count >= 2 else { return points.first ?? V() }
        let position = clamp(u)*Double(points.count-1),i = min(points.count-2,Int(position)),t = position-Double(i)
        let a = points[i],b = points[i+1]
        func tangent(_ j: Int) -> V {
            if j == 0 { return points[1]-points[0] }
            if j == points.count-1 { return points[j]-points[j-1] }
            let delta = (points[j+1]-points[j-1])*0.5
            let limit = min((points[j]-points[j-1]).length,(points[j+1]-points[j]).length)*1.4
            return delta.unit*min(delta.length,limit)
        }
        let t2 = t*t,t3 = t2*t
        return a*(2*t3-3*t2+1)+tangent(i)*(t3-2*t2+t)+b*(-2*t3+3*t2)+tangent(i+1)*(t3-t2)
    }
    private func restKnots(clock: Double,index: Int,gait: Double,expressive: Bool) -> [V] {
        let rest = [V(),V(-11,1),V(-23,5),V(-33,15),V(-37,29),V(-32,40),V(-23,40),V(-20,32)]
        guard expressive else { mood = .quiet;return rest }
        let local = (clock-Double(index)*0.36+36).truncatingRemainder(dividingBy:18)
        var shape = rest
        if local >= 5 && local < 9 {
            mood = .question
            let weight = smooth((local-5)/0.9)*(1-smooth((local-8)/1))
            let tall = [V(),V(-10,8),V(-22,28),V(-27,55),V(-23,83),V(-10,97),V(3,91),V(2,78)]
            shape = zip(rest,tall).map {mix($0,$1,weight)}
        } else if local >= 9 && local < 12.5 {
            mood = .curl
            let weight = smooth((local-9)/0.7)*(1-smooth((local-11.7)/0.8))
            let curl = [V(),V(-14,-1),V(-31,5),V(-40,20),V(-32,35),V(-16,32),V(-12,18),V(-24,15)]
            shape = zip(rest,curl).map {mix($0,$1,weight)}
        } else { mood = local >= 12.5 && local < 14.5 ? .flick : .swaying }
        let personality = [1.0,0.94,1.04,0.98,1.07][index%5]
        for j in 1..<8 {
            let u = Double(j)/7
            let swish = sin(clock*(1.6+Double(index)*0.07)-u*2.7+Double(index)*0.35)
            let flick = mood == .flick ? sin((local-12.5)*8-u*2)*sin(clamp((local-12.5)/2)*Double.pi)*0.23 : 0
            shape[j] = rotated(shape[j]*personality,(swish*0.07+flick)*u)
            shape[j].y += sin(clock*4.2-u*2.4)*gait*5*u
        }
        return shape
    }
    func update(_ arm: Arm,root: V,now: Double,dt: Double,scale: Double,context: CatTailContext) {
        if context.paused,arm.initialized { return }
        let wantsReach = now < arm.reachUntil
        if !arm.initialized {
            extensionSpring = Spring();extensionAmount = 0;serial = arm.strikeCount-1
            wasReaching = false;settling = false;returnAt = -100
        }
        if arm.strikeCount != serial {
            serial = arm.strikeCount;impulseAt = context.clock
            preloadUntil = wantsReach && extensionAmount < 0.2 ? now+0.11 : now
        }
        if wasReaching && !wantsReach { returnAt = context.clock;settling = true }
        if wantsReach { settling = false }
        wasReaching = wantsReach
        let preload = wantsReach && now < preloadUntil
        let goal = wantsReach && !preload ? 1.0 : 0.0
        extensionSpring.step(V(goal,0),dt,wantsReach ? 3.4 : 1.75,wantsReach ? 0.82 : 0.72)
        extensionAmount = clamp(extensionSpring.value.x)
        var rest = restKnots(clock:context.clock,index:arm.index,gait:context.gait,expressive:context.expressive)
        let recoilAge = max(0,context.clock-returnAt)
        let recoil = recoilAge < 1.8 ? sin(recoilAge*11)*exp(-recoilAge*3.6)*0.14 : 0
        for j in 1..<8 {
            let u = Double(j)/7
            rest[j] = rotated(rest[j],(preload ? -0.20 : recoil)*u)
        }
        let idle = rest.map { p -> V in
            let v = root+rotated(p,context.angle)*scale
            guard let area = context.area else { return v }
            return V(clamp(v.x,area.minX+8*scale,area.maxX-8*scale),clamp(v.y,area.minY+8*scale,area.maxY-8*scale))
        }
        if !arm.initialized { arm.aimSpring.value = idle.last! }
        let before = arm.aimSpring.value
        arm.aimSpring.step(arm.heldTarget ?? idle.last!,dt,3.6,0.94)
        let movement = arm.aimSpring.value-before,aimLimit = 3000*scale*dt
        if movement.length > aimLimit {
            arm.aimSpring.value = before+movement.unit*aimLimit;arm.aimSpring.velocity = movement.unit*3000*scale
        }
        let contactAge = max(0,now-arm.tapAt)
        let tap = contactAge < 0.24 ? sin(contactAge/0.24*Double.pi)*3*exp(-contactAge*7) : 0
        contactTarget = arm.aimSpring.value+V(arm.side*3,-4+tap)*scale
        let delta = contactTarget-root,normal = delta.unit.normal,length = delta.length
        let pulseAge = max(0,context.clock-impulseAt)
        let pulse = exp(-pulseAge*2.8)
        let exit = rotated(V(-20,11),context.angle)*scale
        for j in 0..<8 {
            let u = Double(j)/7
            var extended = root+delta*u
            if j == 1 { extended = root+exit+delta*0.035 }
            if j > 1 && j < 7 {
                let bow = sin(u*Double.pi)*sin(u*4.3+Double(arm.index)*0.45)*min(36*scale,length*0.08)
                let wave = sin(u*Double.pi)*sin(u*8-pulseAge*10)*pulse*min(15*scale,length*0.035)
                extended = extended+normal*(bow+wave)
            }
            var guide = mix(idle[j],extended,smooth(extensionAmount))
            if j == 0 { guide = root }
            if !arm.initialized { joints[j] = Spring(value:idle[j]) }
            let previous = joints[j].value
            joints[j].step(guide,dt,9.5-Double(j)*0.65,0.82)
            let distance = joints[j].value-previous,limit = 4200*scale*dt
            if distance.length > limit { joints[j].value = previous+distance.unit*limit;joints[j].velocity = distance.unit*4200*scale }
            controls[j] = joints[j].value
        }
        controls[0] = root;joints[0] = Spring(value:root)
        let restError = zip(controls,idle).map {($0-$1).length}.max() ?? 0
        if extensionAmount < 0.001 && restError < 6*scale { settling = false }
        phase = preload ? .anticipating : wantsReach ? arm.contacted ? .tapping : .extending : extensionAmount > 0.015 || settling ? .recoiling : .idle
        visited.insert(phase.rawValue)
        for n in arm.nodes.indices {
            var p = Self.sample(controls,Double(n)/Double(arm.nodes.count-1))
            if let area = context.area,phase == .idle {
                p.x = clamp(p.x,area.minX+5*scale,area.maxX-5*scale)
                p.y = clamp(p.y,area.minY+5*scale,area.maxY-5*scale)
            }
            if arm.initialized,n > 0 {
                let delta = p-arm.nodes[n],limit = 4200*scale*dt
                if delta.length > limit { p = arm.nodes[n]+delta.unit*limit }
            }
            arm.nodes[n] = p;arm.springs[n].value = p
        }
        arm.nodes[0] = root;arm.initialized = true
    }
}
