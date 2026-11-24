import Foundation
import CoreGraphics

@main struct ConcurrentMotionTests {
    static func main() {
        let display = CGRect(x:1440,y:-540,width:2560,height:1440)
        let target = V(180,650),clickTarget = V(950,280)
        for kind in PetKind.allCases where kind.canRoam {
            for clicks in [false,true] {
                let baseline = PetMotion(),active = PetMotion()
                for m in [baseline,active] {
                    m.configure(kind);m.place(frame:display,visible:display,enter:true)
                }
                active.target = target
                var pending: (index:Int,serial:Int,glyph:String,frame:Int)?
                var accepted = 0,contacts = 0,walkingDelivery = 0,climbingDelivery = 0
                var maxStep = 0.0,maxStretch = 0.0
                var oldNodes = active.arms.map {$0.nodes}
                for frame in 1...3300 {
                    let t = Double(frame)/60
                    if frame%6 == 1 {
                        let i = active.nextArm
                        if clicks { active.click(at:clickTarget,time:t) }
                        else {
                            active.input(at:t)
                            pending = (i,active.arms[i].strikeCount,String(UnicodeScalar(97+((frame/6)%26))!),frame+2)
                        }
                    }
                    baseline.step(to:t,dt:1.0/60);active.step(to:t,dt:1.0/60)
                    if let letter = pending,letter.frame == frame {
                        precondition(active.arms[letter.index].acceptGlyph(letter.glyph,forStrike:letter.serial,at:t))
                        precondition(active.arms[letter.index].glyph == letter.glyph)
                        accepted += 1;pending = nil
                    }
                    precondition(active.boundary.phase == baseline.boundary.phase && active.boundary.position == baseline.boundary.position && active.boundary.rotation == baseline.boundary.rotation,"\(kind): delivery changed the route")
                    precondition(active.locomotion.cycle == baseline.locomotion.cycle && active.locomotion.weight == baseline.locomotion.weight && active.locomotion.facing == baseline.locomotion.facing,"\(kind): input paused the gait or changed its facing")
                    for arm in active.arms {
                        precondition((arm.nodes[0]-(active.body+active.attachmentOffset(arm.index)*active.scale)).length < 0.001)
                        for (n,p) in arm.nodes.enumerated() {
                            precondition(p.x.isFinite && p.y.isFinite)
                            if frame > 1 { maxStep = max(maxStep,(p-oldNodes[arm.index][n]).length) }
                        }
                        if arm.contacted { contacts += 1 }
                    }
                    for (i,p) in active.locomotion.poses.enumerated() where active.locomotion.weight > 0.95 {
                        let d = active.locomotion.limbs[i]
                        maxStretch = max(maxStretch,(p.tip-p.root).length/(d.upper+d.lower))
                    }
                    oldNodes = active.arms.map {$0.nodes}
                    if active.reaching && active.boundary.phase == .walking { walkingDelivery += 1 }
                    if active.reaching && active.boundary.phase == .climbing { climbingDelivery += 1 }
                    if !clicks && kind.armCount == 1 && frame > 120 { precondition(active.arms[0].glyph != nil,"\(kind): moving carrier lost its letter") }
                }
                precondition(walkingDelivery > 600 && climbingDelivery > 400 && contacts > 100)
                if !clicks { precondition(accepted == 550) }
                precondition(maxStep < 150,"\(kind): moving root or gait handoff snapped")
                precondition(maxStretch < 2.3,"\(kind): delivery pulled the body out of its gait")
                precondition(["entering","walking","climbing","performing","returning"].allSatisfy {active.boundary.visited.contains($0)})
                active.setLocomotionEnabled(false)
                for frame in 3301...3540 {
                    let t = Double(frame)/60
                    if frame%6 == 1 { active.click(at:clickTarget,time:t) }
                    active.step(to:t,dt:1.0/60)
                    precondition(active.boundary.position == active.boundary.home && active.locomotion.weight == 0)
                }
                active.setLocomotionEnabled(true);active.boundary.showcase()
                active.paused = true;let frozen = active.boundary.position
                for frame in 3541...3600 { active.step(to:Double(frame)/60,dt:1.0/60) }
                precondition(active.boundary.position == frozen && active.boundary.elapsed == 0)
                print("PASS \(kind.rawValue) \(clicks ? "clicks" : "typing"): route and gait match no-input baseline, \(accepted) letters, attached roots, walk/reach \(walkingDelivery), climb/reach \(climbingDelivery), max step \(Int(maxStep)) px; off and pause retained")
                fflush(stdout)
            }
        }
        for kind in [PetKind.octopus,.plant] {
            let m = PetMotion();m.configure(kind)
            m.place(frame:display,visible:display,enter:false);m.boundary.showcase()
            var t = 0.0
            func step() { t += 1.0/60;m.step(to:t,dt:1.0/60) }
            while m.boundary.phase != .climbing || m.boundary.elapsed < 3 { step() }
            m.target = target;m.input(at:t)
            let arm = m.arms[0],others = m.arms.dropFirst().map {$0.strikeCount}
            var previous = arm.nodes,maxStep = 0.0
            for _ in 0..<360 {
                step()
                for (p,old) in zip(arm.nodes,previous) { maxStep = max(maxStep,(p-old).length) }
                previous = arm.nodes
            }
            precondition(m.arms.dropFirst().map {$0.strikeCount} == others)
            precondition(m.locomotion.weight > 0.99 && arm.reachAmount < 0.001)
            precondition((arm.nodes.last!-m.locomotion.poses[0].tip).length < 0.5)
            precondition(maxStep < 80)
            print("PASS \(kind): a single delivery retracts into the ongoing climbing pose, no extra limb triggered; max step \(Int(maxStep)) px")
        }
    }
}
