import Foundation
import CoreGraphics

struct LimbRig {
    var root: V;var knee: V;var tip: V
    var radius: Double;var phase: Double
    var arm = false
    var hidden = false
    var upper: Double { (knee-root).length }
    var lower: Double { (tip-knee).length }
}
struct LimbPose {
    var root = V();var knee = V();var tip = V()
    var planted = true
    var swing = 0.0
    var contact = V();var from = V();var destination = V()
    var wasSwing = false
}
func dot(_ a: V,_ b: V) -> Double { a.x*b.x+a.y*b.y }

/// Two-bone IK with a stable bend direction and soft stretch for cartoon limbs.
func solveKnee(root: V,tip: V,upper: Double,lower: Double,bend: Double) -> V {
    let delta = tip-root,d = max(0.001,delta.length)
    let stretch = max(1,d/(upper+lower)*1.015)
    let a = upper*stretch,b = lower*stretch
    let along = (a*a-b*b+d*d)/(2*d)
    let height = sqrt(max(0,a*a-along*along))
    return root+delta.unit*along+delta.unit.normal*(height*bend)
}

final class LocomotionRig {
    private(set) var kind = PetKind.octopus
    private(set) var limbs: [LimbRig] = []
    private(set) var poses: [LimbPose] = []
    private(set) var weight = 0.0
    private(set) var cycle = 0.0
    private(set) var speed = 0.0
    private(set) var onWall = false
    private(set) var bodyOffset = V()
    private(set) var lean = 0.0
    private(set) var stretch = V(1,1)
    private(set) var facing = 1.0
    private var supported = true
    private var lastSupported = true
    private var lastPosition: V?
    private var lastWall = false
    private var initialized = false
    private var direction = 1.0
    private var body = V()
    private var angle = 0.0
    private var bodyScale = V(1,1)
    private var scale = 1.0
    private var normal = V(0,1)
    private var tangent = V(1,0)
    private var surface = V()
    private var skinField = SkinField()
    var floats: Bool { [.ghost,.cloud,.jellyfish].contains(kind) }
    var usesProceduralFeet: Bool { kind == .octopus || (kind == .plant && onWall) }
    var stride: Double {
        switch kind {
        case .robot: return 18
        case .yarncat: return 16
        case .star: return 22
        case .octopus: return 44
        case .plant: return onWall ? 42 : 20
        default: return 24
        }
    }
    func reset() { initialized = false;lastPosition = nil;weight = 0;cycle = 0;poses.removeAll();limbs.removeAll();bodyOffset = V();lean = 0;stretch = V(1,1);facing = 1;skinField.clear() }
    static func definitions(_ kind: PetKind,wall: Bool) -> [LimbRig] {
        func leg(_ root: V,_ knee: V,_ tip: V,_ radius: Double,_ phase: Double,_ arm: Bool = false,_ hidden: Bool = false) -> LimbRig {
            LimbRig(root:root,knee:knee,tip:tip,radius:radius,phase:phase,arm:arm,hidden:hidden)
        }
        switch kind {
        case .octopus:
            return (0..<8).map { i in
                let root = kind.root(i),tip = V((Double(i)-3.5)*22,-82+Double(i%2)*2)
                return leg(root,mix(root,tip,0.52)+V(i%2 == 0 ? -12 : 12,15),tip,12,Double(i)*0.125)
            }
        case .chameleon:
            return [leg(V(-48,-20),V(-57,-36),V(-53,-49),17,0),
                    leg(V(-13,-20),V(-20,-37),V(-16,-53),18,0.5),
                    leg(V(27,-20),V(20,-38),V(25,-52),17,0.15),
                    leg(V(7,-20),V(1,-36),V(4,-49),10,0.65,false,true)]
        case .robot:
            return [leg(V(-21,-44),V(-25,-56),V(-25,-69),19,0),
                    leg(V(21,-44),V(26,-56),V(25,-69),19,0.5),
                    leg(V(-34,-10),V(-46,-25),V(-52,-38),16,0.5,true),
                    leg(V(34,-10),V(45,-26),V(51,-38),16,0,true)]
        case .spider:
            return [leg(V(-56,9),V(-69,-5),V(-74,-24),12,0),
                    leg(V(-47,4),V(-61,-14),V(-67,-33),14,0.5),
                    leg(V(-39,-6),V(-47,-24),V(-52,-44),16,0.1),
                    leg(V(-1,-8),V(-7,-29),V(-11,-47),16,0.6),
                    leg(V(17,-5),V(22,-28),V(25,-45),16,0.15),
                    leg(V(30,-1),V(43,-20),V(49,-38),15,0.65),
                    leg(V(43,5),V(58,-11),V(63,-27),13,0.25),
                    leg(V(-23,-8),V(-28,-30),V(-30,-45),10,0.75,false,true)]
        case .yarncat:
            return [leg(V(-29,-32),V(-33,-43),V(-30,-55),15,0),leg(V(-6,-32),V(-7,-44),V(-5,-57),15,0.5)]
        case .plant:
            if wall { return (0..<3).map { i in let r = kind.root(i);return leg(r,r+V(20,12),V(75,Double(i-1)*38),7,Double(i)/3) } }
            return [leg(V(-29,-38),V(-32,-50),V(-30,-64),13,0),leg(V(19,-38),V(23,-50),V(24,-64),13,0.5)]
        case .star:
            return [leg(V(-21,-24),V(-28,-40),V(-30,-57),21,0),leg(V(21,-24),V(28,-40),V(30,-57),21,0.5)]
        case .slime:
            return [leg(V(-28,-24),V(-35,-36),V(-36,-48),21,0),leg(V(24,-24),V(29,-38),V(29,-49),21,0.5)]
        default: return []
        }
    }
    func prepare(kind: PetKind,boundary b: BoundaryMotion,dt: Double,paused: Bool) {
        if !b.enabled { reset();self.kind = kind;return }
        let previous = lastPosition ?? b.position
        let moving = (b.position-previous)/max(dt,0.001)
        lastPosition = b.position
        let wall = b.rotation > 1.4 && b.position.y >= b.ground-1 && b.area.maxX-b.position.x < kind.contactHeight*b.scale+24*b.scale
            || kind == .plant && (b.phase == .climbing && b.elapsed > 2.4 || b.phase == .performing)
        supported = wall || abs(b.position.y-b.ground) < 8*b.scale && abs(b.rotation) < 0.12
        let locomoting = [.entering,.walking,.climbing,.returning].contains(b.phase)
        let wants = b.configured && b.enabled && !paused && (locomoting || wall)
        if self.kind != kind || limbs.isEmpty || (kind == .plant && onWall != wall) {
            self.kind = kind;limbs = Self.definitions(kind,wall:wall);poses = limbs.map {_ in LimbPose()};initialized = false;skinField.clear()
        }
        onWall = wall
        weight += ((wants ? 1.0 : 0.0)-weight)*(1-exp(-dt*12))
        if !b.enabled { weight = 0;initialized = false }
        normal = wall ? V(-1,0) : V(0,1)
        tangent = wall ? V(0,1) : V(1,0)
        surface = wall ? V(b.area.maxX,0) : V(0,b.area.minY)
        let signedSpeed = dot(moving,tangent)/b.scale
        speed = wants ? abs(signedSpeed) : 0
        if abs(signedSpeed) > 2 { direction = signedSpeed > 0 ? 1 : -1 }
        let nextFacing: Double = wants && [.chameleon,.yarncat,.spider].contains(kind) && (wall || direction > 0) ? -1 : 1
        if facing != nextFacing { initialized = false;facing = nextFacing }
        if wants && !paused {
            cycle += (floats ? 0.9 : speed/stride)*dt
        }
        let phase = cycle*2*Double.pi
        bodyOffset = floats ? V(0,sin(phase)*4) : V(sin(phase)*1.2,-abs(sin(phase))*2.5)
        if kind == .slime { bodyOffset = V(sin(phase)*3,-3*(1+cos(phase))) }
        lean = sin(phase)*(kind == .robot ? 0.045 : 0.03)*weight
        let squash = kind == .slime ? 0.1 : floats ? 0.04 : 0.018
        stretch = V(1+cos(phase)*squash*weight,1-cos(phase)*squash*weight)
        bodyOffset = bodyOffset*weight
        if wall { bodyOffset = rotated(bodyOffset,.pi/2) }
    }
    func toWorld(_ p: V) -> V { body+rotated(V(p.x*bodyScale.x,p.y*bodyScale.y),angle)*scale }
    func toLocal(_ p: V) -> V { let v = rotated((p-body)/scale,-angle);return V(v.x/bodyScale.x,v.y/bodyScale.y) }
    private func projected(_ p: V,depth: Double) -> V { p+normal*(depth-dot(p-surface,normal)) }
    func solve(body: V,angle: Double,stretch: V,scale: Double,dt: Double) {
        self.body = body;self.angle = angle;bodyScale = stretch;self.scale = scale
        guard weight > 0.001,!limbs.isEmpty else { initialized = false;return }
        let changedSurface = onWall != lastWall || supported != lastSupported
        lastWall = onWall;lastSupported = supported
        for i in limbs.indices {
            let def = limbs[i]
            let root = toWorld(def.root)
            if !supported {
                // Airborne limbs fold with their body. They must never chase a
                // floor hundreds of pixels below during a return or a jump.
                let tuck = sin((cycle+def.phase)*2*Double.pi)*0.08
                poses[i].root = root
                poses[i].knee = toWorld(def.root+rotated(def.knee-def.root,tuck))
                poses[i].tip = toWorld(def.root+rotated(def.tip-def.root,tuck))
                poses[i].planted = false;poses[i].wasSwing = false
                continue
            }
            let depth = onWall ? 0 : max(0,def.tip.y+kind.contactHeight)*scale
            let rest = projected(toWorld(def.tip),depth:depth)
            if !initialized {
                poses[i].contact = rest;poses[i].tip = rest;poses[i].from = rest;poses[i].destination = rest
            }
            // Arms counter-swing during walking; they become load-bearing on walls.
            if def.arm && !onWall {
                let swing = sin((cycle+def.phase)*2*Double.pi)*0.4*weight
                poses[i].root = root
                poses[i].knee = toWorld(def.root+rotated(def.knee-def.root,swing))
                poses[i].tip = toWorld(def.root+rotated(def.tip-def.root,swing))
                poses[i].planted = false
                continue
            }
            let phase = (cycle+def.phase).truncatingRemainder(dividingBy:1)
            let duty = kind == .octopus || kind == .spider ? 0.72 : 0.62
            let swing = (speed > 0.5 || poses[i].wasSwing) && phase >= duty
            let u = swing ? (phase-duty)/(1-duty) : 0
            if changedSurface {
                poses[i].from = poses[i].tip;poses[i].destination = rest
                poses[i].contact = rest;poses[i].wasSwing = false
            }
            if swing {
                if !poses[i].wasSwing {
                    poses[i].from = poses[i].tip
                    poses[i].destination = rest+tangent*(direction*stride*0.33*scale)
                }
                let lift = kind == .octopus ? 14.0 : kind == .robot ? 8 : 7
                poses[i].tip = mix(poses[i].from,poses[i].destination,smooth(u))+normal*(sin(Double.pi*u)*lift*scale)
                poses[i].contact = poses[i].destination
            } else {
                // Fixed world-space contacts: moving the body bends the joints,
                // it never drags a planted sole along the surface.
                poses[i].tip = poses[i].contact
            }
            poses[i].root = root;poses[i].planted = !swing;poses[i].swing = u;poses[i].wasSwing = swing
            let a = toWorld(def.knee)-root,b = toWorld(def.tip)-root
            let restBend = a.x*b.y-a.y*b.x
            poses[i].knee = solveKnee(root:root,tip:poses[i].tip,upper:def.upper*scale,lower:def.lower*scale,bend:restBend >= 0 ? -1 : 1)
        }
        initialized = true
        if !usesProceduralFeet {
            var points: [V] = [],deltas: [V] = []
            for i in limbs.indices where !limbs[i].hidden {
                let d = limbs[i],p = poses[i]
                for (source,target) in [(d.root,toLocal(p.root)),(d.knee,toLocal(p.knee)),(d.tip,toLocal(p.tip))] {
                    points.append(source);deltas.append(target-source)
                }
                if [.chameleon,.spider,.yarncat,.robot].contains(kind) {
                    let from = (d.tip-d.knee).unit,to = (toLocal(p.tip)-toLocal(p.knee)).unit
                    let width = min(6,d.radius*0.4)
                    for offset in [from.normal*width,from.normal*(-width),from*(-7)] {
                        let source = d.tip+offset
                        let target = toLocal(p.tip)+to*dot(offset,from)+to.normal*dot(offset,from.normal)
                        points.append(source);deltas.append(target-source)
                    }
                }
            }
            for x in [-70.0,-35,0,35,70] { points.append(V(x,2));deltas.append(V()) }
            skinField.update(points:points,deltas:deltas)
        }
    }
    func deform(_ p: V) -> V {
        guard weight > 0.001 else { return p }
        var result = p+(usesProceduralFeet ? V() : skinField.displacement(p))*weight
        let wave = cycle*2*Double.pi
        switch kind {
        case .ghost:
            let hem = 1-smooth((p.y+35)/45)
            result = result+V(sin(wave-p.x*0.07)*5,cos(wave-p.x*0.07)*8)*hem*weight
        case .cloud:
            let puff = 1-smooth((p.y+22)/42)
            result = result+V(sin(wave+p.x*0.065)*5,cos(wave+p.x*0.065)*7)*puff*weight
        case .jellyfish:
            let bell = smooth((p.y+65)/100)
            result.x += p.x*sin(wave)*0.10*bell*weight
            result.y += sin(wave+0.7)*7*bell*weight
        case .slime:
            let belly = smooth((p.y+25)/22)*(1-smooth((p.y-5)/30))
            result.x += sin(wave-p.x*0.055)*3*belly*weight
        case .plant:
            let leaves = smooth((p.y-10)/50)
            result = result+V(sin(wave*0.7+p.x*0.03)*6,cos(wave*0.7+p.x*0.03)*2)*leaves*weight
        case .chameleon:
            let tail = smooth((p.x-34)/25)*(1-smooth((p.y-12)/25))
            result = result+V(0,sin(wave*0.6)*6)*tail*weight
        case .robot:
            let antenna = smooth((p.y-62)/25)
            result.x += sin(wave+0.8)*5*antenna*weight
        default: break
        }
        return result
    }
}

/// A compact radial-basis skin field interpolates the actual joint displacements.
/// Unlike choosing a single strongest bone per vertex, adjacent feet have a
/// continuous shared boundary; roots and upper-body pins stay exactly registered.
final class SkinField {
    private var points: [V] = []
    private var inverse: [[Double]] = []
    private var coefficients: [V] = []
    func clear() { points = [];inverse = [];coefficients = [] }
    private func kernel(_ distance: Double) -> Double {
        let r = min(1,distance/60),a = 1-r
        return a*a*a*a*(4*r+1)
    }
    func update(points: [V],deltas: [V]) {
        if self.points != points {
            self.points = points
            let n = points.count
            var matrix = (0..<n).map { i in (0..<n).map { j in kernel((points[i]-points[j]).length)+(i == j ? 1e-8 : 0) } }
            inverse = (0..<n).map { i in (0..<n).map { j in i == j ? 1.0 : 0.0 } }
            for col in 0..<n {
                let pivot = (col..<n).max { abs(matrix[$0][col]) < abs(matrix[$1][col]) }!
                matrix.swapAt(col,pivot);inverse.swapAt(col,pivot)
                let divisor = matrix[col][col]
                precondition(abs(divisor) > 1e-10)
                for j in 0..<n { matrix[col][j] /= divisor;inverse[col][j] /= divisor }
                for row in 0..<n where row != col {
                    let factor = matrix[row][col]
                    for j in 0..<n { matrix[row][j] -= factor*matrix[col][j];inverse[row][j] -= factor*inverse[col][j] }
                }
            }
        }
        coefficients = inverse.map { row in zip(row,deltas).reduce(V()) { $0+$1.1*$1.0 } }
    }
    func displacement(_ point: V) -> V {
        zip(points,coefficients).reduce(V()) { $0+$1.1*kernel((point-$1.0).length) }
    }
}
