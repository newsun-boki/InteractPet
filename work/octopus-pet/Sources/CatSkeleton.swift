import Foundation

struct CatBone {
    var bindA: V,bindB: V,a: V,b: V
    func map(_ p: V) -> V {
        let rest = bindB-bindA,posed = b-a
        let angle = atan2(posed.y,posed.x)-atan2(rest.y,rest.x)
        return a+rotated(p-bindA,angle)*(posed.length/max(0.001,rest.length))
    }
}
struct CatLeg {
    var root: V,knee: V,tip: V
    var target: V
    var planted: Bool
}
private struct CatFoot {
    var point = V(),start = V(),end = V()
    var initialized = false,stance = false
}

/// Two-bone IK for four legs, a cubic spine, rigid head and ear bones,
/// and a three-bone spline tail. All deformation is in measured atlas space.
final class CatSkeleton {
    static let feet = [V(-24,-72),V(24,-72),V(-56,-69),V(56,-69)]
    static let roots = [V(-22,-31),V(22,-31),V(-45,-38),V(45,-38)]
    static let knees = [V(-27,-51),V(27,-51),V(-62,-53),V(62,-53)]
    let index: Int
    private(set) var placement: CatPlacement
    private(set) var angle = 0.0
    private(set) var cycle = 0.0
    private(set) var speed = 0.0
    private(set) var gaitWeight = 0.0
    private(set) var legs: [CatLeg] = []
    private(set) var legBones: [[CatBone]] = []
    private(set) var spine: [V] = []
    private(set) var tail: [V] = []
    private(set) var head = CatBone(bindA:V(0,0),bindB:V(0,68),a:V(0,0),b:V(0,68))
    private var feet = [CatFoot](repeating:CatFoot(),count:4)
    private var oldSurface = CatSurface.ground
    private var oldPivot = V()
    private var initialized = false
    private var blinkValue = 0.0,earAngle = 0.0
    private var bodyLean = 0.0,bodyDrop = 0.0,breath = 0.0
    init(index: Int) { self.index = index;placement = CatPlacement(pivot:CatFormation.home(index)) }
    func reset() { initialized = false;feet = [CatFoot](repeating:CatFoot(),count:4);cycle = 0;gaitWeight = 0 }
    func localToGroup(_ p: V) -> V {
        placement.pivot+rotated(V(p.x*72/176,(p.y+76)*96/176),angle)
    }
    func groupToLocal(_ p: V) -> V {
        let v = rotated(p-placement.pivot,-angle)
        return V(v.x*176/72,v.y*176/96-76)
    }
    private func bodyPoint(_ p: V) -> V {
        let u = clamp((p.y+65)/68)
        let curve = CatFormation.curve(V(0,-65),V(bodyLean*0.18,-44-bodyDrop*0.5),V(bodyLean,-19-bodyDrop),V(bodyLean*0.65,3-bodyDrop),u)
        return V(p.x*(1+breath)+curve.x,p.y+curve.y-(-65+68*u))
    }
    func prepare(_ pose: CatPlacement,time: Double,beat: Double,strength: Double,dt: Double,reach: Double) {
        let old = initialized ? oldPivot : pose.pivot
        speed = (pose.pivot-old).length/max(dt,0.0001)
        let velocity = (pose.pivot-old)/max(dt,0.0001)
        oldPivot = pose.pivot;placement = pose
        let grounded = pose.surface != .air
        let targetWeight = grounded ? clamp(speed/12) : 0
        gaitWeight += (targetWeight-gaitWeight)*(1-exp(-dt*14))
        cycle += grounded ? speed*dt/16 : 0
        angle = pose.rotation+sin(beat)*0.105*strength*pose.idle*(1-gaitWeight)
        breath = sin(time*2.1+Double(index)*0.2)*0.008
        bodyLean = -pose.attention*3 + sin(beat-0.25)*2.5*strength*pose.idle + min(1,reach)*2
        bodyDrop = pose.crouch*9+(10+sin(cycle*4*Double.pi)*2.3)*gaitWeight
        let chest = bodyPoint(V(0,0))
        let headAngle = sin(beat-0.45)*0.035*strength*pose.idle-pose.attention*0.085+sin(cycle*2*Double.pi)*0.025*gaitWeight
        head = CatBone(bindA:V(0,0),bindB:V(0,68),a:chest,b:chest+rotated(V(0,68),headAngle))
        earAngle = sin(time*3.1+Double(index)*0.3)*0.045+pose.attention*0.04
        let blinkPhase = (time+Double(index)*0.31).truncatingRemainder(dividingBy:3.8+Double(index)*0.11)
        blinkValue = blinkPhase > 2.6 && blinkPhase < 2.82 ? pow(sin((blinkPhase-2.6)/0.22*Double.pi),2) : 0
        spine = [V(0,-65),V(bodyLean*0.18,-44-bodyDrop*0.5),V(bodyLean,-19-bodyDrop),chest]
        let tailBase = bodyPoint(V(-48,-49))
        tail = (0...3).map { j in
            let u = Double(j)/3
            return tailBase+V(-22*u,15*sin(u*Double.pi*0.9)+sin(time*2.8-u*1.5)*8*u*(0.3+gaitWeight))
        }
        let surfaceChanged = pose.surface != oldSurface
        oldSurface = pose.surface
        legs = [];legBones = []
        let tangent = rotated(V(1,0),pose.rotation)
        let direction = velocity.x*tangent.x+velocity.y*tangent.y >= 0 ? 1.0 : -1.0
        for j in 0..<4 {
            let bindTip = Self.feet[j],bindRoot = Self.roots[j],bindKnee = Self.knees[j]
            let root = bodyPoint(bindRoot)
            // Ground/wall support coordinates do not rotate with idle body sway.
            let neutral = pose.pivot+rotated(V(bindTip.x*72/176,(bindTip.y+76)*96/176),pose.rotation)
            let phase = (cycle+([0.0,0.5,0.5,0.0][j])).truncatingRemainder(dividingBy:1)
            let wantsStance = phase < 0.62 || gaitWeight < 0.08
            if !feet[j].initialized || surfaceChanged {
                feet[j].point = neutral;feet[j].start = neutral;feet[j].end = neutral
                feet[j].stance = wantsStance;feet[j].initialized = true
            }
            if grounded {
                if gaitWeight < 0.08 {
                    feet[j].point = mix(feet[j].point,neutral,1-exp(-dt*12));feet[j].stance = true
                } else if wantsStance {
                    if !feet[j].stance { feet[j].point = feet[j].end;feet[j].stance = true }
                } else {
                    if feet[j].stance {
                        feet[j].start = feet[j].point;feet[j].end = neutral+tangent*(direction*4.5)
                        feet[j].stance = false
                    }
                    let u = (phase-0.62)/0.38
                    feet[j].point = mix(feet[j].start,feet[j].end,smooth(u))+rotated(V(0,sin(u*Double.pi)*6.5),pose.rotation)
                }
            } else {
                feet[j].point = localToGroup(bindTip+V(j%2 == 0 ? -3 : 3,17));feet[j].stance = false
            }
            var target = groupToLocal(feet[j].point)
            if j == 1 { target = target+V(-pose.wave*4,pose.wave*20) }
            let delta = target-root
            let restA = (bindKnee-bindRoot).length,restB = (bindTip-bindKnee).length
            // A small bounded soft stretch preserves planted contacts during
            // torso reactions; it never changes the scheduler or foot target.
            let stretch = clamp(delta.length/(restA+restB-0.01),1,1.18)
            let a = restA*stretch,b = restB*stretch
            let d = clamp(delta.length,abs(a-b)+0.01,a+b-0.01)
            let tip = root+delta.unit*d
            let along = (a*a-b*b+d*d)/(2*d)
            let bend = sqrt(max(0,a*a-along*along))*(j%2 == 0 ? -1.0 : 1.0)
            let knee = root+delta.unit*along+delta.unit.normal*bend
            legs.append(CatLeg(root:root,knee:knee,tip:tip,target:target,planted:grounded && feet[j].stance && (j != 1 || pose.wave < 0.01)))
            legBones.append([CatBone(bindA:bindRoot,bindB:bindKnee,a:root,b:knee),CatBone(bindA:bindKnee,bindB:bindTip,a:knee,b:tip)])
        }
        initialized = true
    }
    func deform(_ p: V) -> V {
        guard legs.count == 4 else { return p }
        var face = p
        let eye = max(exp(-pow((p.x+29)/19,2)-pow((p.y-31)/17,2)),exp(-pow((p.x-34)/19,2)-pow((p.y-31)/17,2)))
        face.y -= (p.y-31)*eye*blinkValue*0.99
        var upper = head.map(face)
        let side = p.x < 0 ? -1.0 : 1.0
        let earPivot = V(side*52,64)
        let ear = head.map(earPivot+rotated(face-earPivot,earAngle*side))
        upper = mix(upper,ear,smooth((p.y-62)/26)*smooth((abs(p.x)-30)/28))
        var result = mix(bodyPoint(p),upper,smooth((p.y+10)/28))
        if p.y < -23 {
            var total = 0.0,weighted = V()
            for j in 0..<4 {
                let w = exp(-pow((p.x-Self.feet[j].x)/(j < 2 ? 12 : 15),2))
                let boneMix = smooth((-p.y-43)/20)
                weighted = weighted+mix(legBones[j][0].map(p),legBones[j][1].map(p),boneMix)*w;total += w
            }
            let legMask = smooth((-p.y-25)/39)*smooth((abs(p.x)-6)/15)
            if total > 0.00001 { result = mix(result,weighted/total,legMask) }
            let tailMask = smooth((-p.x-59)/17)*(1-smooth((p.y+30)/19))*smooth((p.y+75)/14)
            let u = clamp((-p.x-48)/22),rest = V(-48-22*u,-49+15*sin(u*Double.pi*0.9))
            let tip = CatFormation.curve(tail[0],tail[1],tail[2],tail[3],u)
            result = result+(tip-rest)*tailMask*0.55
        }
        if placement.surface != .air {
            var support = rotated(localToGroup(result)-placement.pivot,-placement.rotation)
            if support.y < 0 {
                support.y = 0
                result = groupToLocal(placement.pivot+rotated(support,placement.rotation))
            }
        }
        return result
    }
}
