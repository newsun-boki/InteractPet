import Foundation
import CoreGraphics

enum BoundaryPhase: String { case entering,resting,walking,climbing,performing,falling,returning,peeking }
struct BorderParticle {
    var point: V;var velocity: V;var age: Double = 0
    var life: Double;var size: Double;var angle: Double
}
struct BorderImpact { var point: V;var normal: V;var age: Double = 0 }

/// Logical desktop points throughout; the renderer alone handles backing pixels.
final class BoundaryMotion {
    var enabled = true
    private(set) var configured = false
    private(set) var frame = CGRect.zero
    private(set) var area = CGRect.zero
    private(set) var position = V()
    private(set) var velocity = V()
    private(set) var rotation = 0.0
    private(set) var compression = 0.0
    private(set) var phase = BoundaryPhase.resting
    private(set) var elapsed = 0.0
    private(set) var kind = PetKind.octopus
    private(set) var scale = 1.0
    private(set) var impacts: [BorderImpact] = []
    private(set) var particles: [BorderParticle] = []
    private(set) var impactCount = 0
    private(set) var visited = Set<String>()
    private var origin = V()
    private var beats = 0
    private var bounces = 0
    private var returnFromWall = false
    var home: V { V(area.maxX-kind.homeInset*scale,ground) }
    var ground: Double { area.minY+kind.contactHeight*scale }
    var busy: Bool { configured && enabled && phase != .resting && phase != .peeking }
    var floating: Bool { [.ghost,.cloud,.jellyfish].contains(kind) }
    var gripping: Bool { configured && enabled && (phase == .climbing || phase == .performing || phase == .peeking) }
    var threadAnchor: V? {
        kind == .spider && phase == .performing ? V(area.maxX-175*scale,area.maxY) : nil
    }
    var drawingBounds: CGRect {
        let halfWidth = max(150,kind.sceneHalfWidth+12)
        var r = CGRect(x:position.x-halfWidth*scale,y:position.y-150*scale,width:halfWidth*2*scale,height:300*scale)
        for p in particles { r = r.union(CGRect(x:p.point.x-24,y:p.point.y-24,width:48,height:48)) }
        for p in impacts { r = r.union(CGRect(x:p.point.x-100,y:p.point.y-100,width:200,height:200)) }
        if let top = threadAnchor { r = r.union(CGRect(x:top.x-2,y:top.y-2,width:4,height:4)) }
        return r
    }
    func configure(frame: CGRect,visible: CGRect,kind: PetKind,scale: Double,enter: Bool = true) {
        guard frame.width > 200,frame.height > 200,scale.isFinite,scale > 0 else { return }
        self.frame = frame
        let visible = frame.intersection(visible)
        self.area = visible.isNull || visible.width < 200 || visible.height < 200 ? frame : visible
        self.kind = kind;self.scale = min(scale,area.width/max(260,kind.sceneHalfWidth*2+44),area.height/300)
        configured = true;particles.removeAll();impacts.removeAll();velocity = V();compression = 0
        rotation = 0;impactCount = 0;visited.removeAll()
        position = enabled && enter && kind.canRoam ? V(frame.maxX+125*self.scale,ground) : home
        begin(enabled && enter && kind.canRoam ? .entering : .resting)
    }
    private func begin(_ next: BoundaryPhase) {
        phase = next;elapsed = 0;origin = position;beats = 0
        visited.insert(next.rawValue)
        if next == .falling { velocity = V(-85*scale,60*scale);bounces = 0 }
        if next == .returning { returnFromWall = rotation > 1.4 && position.y > ground+20*scale }
    }
    func showcase() { guard configured,enabled,kind.canRoam else { return };position = home;rotation = 0;begin(.walking) }
    func peek() {
        guard configured,enabled,kind.canRoam else { return };begin(.peeking)
    }
    func goHome() { guard configured else { return };begin(.returning) }
    func setEnabled(_ value: Bool) {
        enabled = value
        if !value {
            position = home;rotation = 0;compression = 0;velocity = V()
            particles.removeAll();impacts.removeAll();begin(.resting)
        }
    }
    private func impact(_ point: V,normal: V) {
        impactCount += 1;impacts.append(BorderImpact(point:point,normal:normal))
        if impacts.count > 10 { impacts.removeFirst(impacts.count-10) }
        for n in 0..<10 {
            let f = Double(n),spread = sin(f*2.399+Double(impactCount))*80
            let velocity = normal*(55+f*8)*scale+normal.normal*spread*scale
            particles.append(BorderParticle(point:point,velocity:velocity,life:0.8+f*0.06,size:(2+f.truncatingRemainder(dividingBy:4))*scale,angle:f))
        }
        if particles.count > 80 { particles.removeFirst(particles.count-80) }
    }
    func step(dt: Double,paused: Bool) {
        guard configured,!paused else { return }
        guard kind.canRoam else { position = home;rotation = 0;return }
        let dt = min(1.0/30,max(0,dt))
        particles = particles.compactMap { p in
            var p = p;p.age += dt;guard p.age < p.life else { return nil }
            p.point = p.point+p.velocity*dt
            p.velocity.y += (floating ? 15 : -160)*scale*dt;p.angle += dt*2
            return p
        }
        impacts = impacts.compactMap { p in var p = p;p.age += dt;return p.age < 0.8 ? p : nil }
        compression *= exp(-dt*8)
        // Input delivery is independent: only the explicit pause/off controls
        // can stop this timeline, including its entrance and wall transitions.
        elapsed += dt
        if !enabled && phase != .returning { position = home;rotation = 0;return }
        switch phase {
        case .entering:
            let u = smooth(elapsed/1.6);position = mix(origin,home,u)
            rotation = sin(elapsed*12)*(1-u)*0.08
            if elapsed >= 1.6 { position = home;begin(.resting) }
        case .resting:
            rotation *= exp(-dt*6)
            if enabled && elapsed > 10 { begin(.walking) }
        case .walking:
            let u = clamp(elapsed/12)
            let left = V(max(area.minX+110*scale,home.x-min(330*scale,area.width*0.42)),ground)
            let base = u < 0.5 ? mix(origin,left,smooth(u*2)) : mix(left,home,smooth((u-0.5)*2))
            position = base+V(0,floating ? 12+sin(elapsed*2)*8 : 0)*scale
            rotation *= exp(-dt*8)
            if elapsed > 12 { begin(.climbing) }
        case .climbing:
            let inset = floating ? 94 : kind == .robot ? 52 : kind == .plant ? 65 : kind.contactHeight*0.87
            let corner = V(area.maxX-inset*scale,ground)
            let top = V(corner.x,min(area.maxY-125*scale,ground+min(220*scale,area.height*0.32)))
            if elapsed < 1 { position = mix(origin,corner,smooth(elapsed)) }
            else if elapsed < 2.4 { position = corner }
            else { position = mix(corner,top,smooth((elapsed-2.4)/5.4)) }
            let climbingAngle: Double = floating || kind == .plant ? 0 : .pi/2
            rotation = climbingAngle*smooth((elapsed-1)/1.4)
            if elapsed > 7.8 { begin(.performing) }
        case .performing:
            perform()
            if elapsed > 3.8 { begin(floating || kind == .chameleon || kind == .spider ? .returning : .falling) }
        case .falling:
            velocity.y -= 1100*scale*dt
            position = position+velocity*dt;rotation *= exp(-dt*6)
            let lowX = area.minX+95*scale,highX = area.maxX-95*scale
            if position.x < lowX || position.x > highX {
                let right = position.x > highX
                position.x = min(highX,max(lowX,position.x));velocity.x *= -0.55
                impact(V(right ? area.maxX : area.minX,position.y),normal:V(right ? -1 : 1,0))
            }
            if position.y <= ground && velocity.y < 0 {
                position.y = ground
                let speed = abs(velocity.y)
                let bounce = kind == .slime ? 0.62 : kind == .robot ? 0.5 : 0.32
                velocity.y = speed*bounce;velocity.x *= 0.75
                compression = min(0.24,speed/(4000*scale));bounces += 1
                impact(V(position.x,area.minY+2),normal:V(0,1))
                if speed < 100*scale || bounces >= 3 { velocity = V();begin(.returning) }
            }
        case .returning:
            if returnFromWall {
                let corner = V(origin.x,ground)
                if elapsed < 4 { position = mix(origin,corner,smooth(elapsed/4));rotation = .pi/2 }
                else if elapsed < 5.4 { position = corner;rotation = .pi/2*(1-smooth((elapsed-4)/1.4)) }
                else { position = mix(corner,home,smooth((elapsed-5.4)/1.8));rotation = 0 }
                if elapsed > 7.2 { position = home;begin(.resting) }
            } else {
                let duration = max(2.4,(origin-home).length/(65*scale)*1.5)
                position = mix(origin,home,smooth(elapsed/duration));rotation *= exp(-dt*6)
                if elapsed > duration { position = home;begin(.resting) }
            }
        case .peeking:
            let p = V(frame.maxX+16*scale,min(area.maxY-125*scale,max(ground+90*scale,area.midY)))
            position = mix(origin,p,smooth(elapsed/1.5));rotation *= exp(-dt*6)
        }
    }
    private func perform() {
        let u = smooth(elapsed/0.8)
        switch kind {
        case .ghost:
            rotation = 0
            position = mix(origin,V(frame.maxX+16*scale,origin.y),u)+V(0,sin(elapsed*2)*5*scale)
        case .chameleon:
            rotation = .pi/2
            position = origin+V(-sin(elapsed*2)*2,sin(elapsed*2)*3)*scale
        case .spider:
            let p = V(area.maxX-175*scale,area.maxY-225*scale)
            position = mix(origin,p,u)+V(sin(elapsed*2.2)*24*scale,sin(elapsed*4.4)*4*scale)
            rotation = sin(elapsed*2.2)*0.12
        case .cloud,.jellyfish:
            rotation = 0
            position = origin+V(sin(elapsed*1.8)*14,sin(elapsed*2.8)*16)*scale
        default:
            rotation = kind == .plant ? 0 : .pi/2
            position = origin+V(-abs(sin(elapsed*5))*5,sin(elapsed*5)*3)*scale
            compression = kind == .slime || kind == .robot ? max(0,sin(elapsed*5))*0.12 : 0
        }
        let beat = Int(elapsed/0.8)
        if beat > beats && beat <= 3 {
            beats = beat
            impact(V(area.maxX-2,min(area.maxY-20,max(area.minY+20,position.y))),normal:V(-1,0))
        }
    }
}
