import Foundation
import CoreGraphics

@main struct LocomotionTests {
    static func main() {
        for kind in PetKind.allCases where kind.canRoam {
            let m = PetMotion();m.configure(kind)
            m.place(frame:CGRect(x:0,y:0,width:1440,height:900),visible:CGRect(x:0,y:0,width:1440,height:875),enter:false)
            m.boundary.showcase()
            var t = 0.0,maxStretch = 0.0,maxTipError = 0.0,stanceFrames = 0,swingFrames = 0
            var previous: [LimbPose] = [],lastWall = false,lastFacing = 1.0,lastPhase = BoundaryPhase.resting
            var maxInfo = ""
            for _ in 0..<4200 {
                t += 1.0/60;m.step(to:t,dt:1.0/60)
                let rig = m.locomotion
                for (i,p) in rig.poses.enumerated() where rig.weight > 0.95 {
                    let d = rig.limbs[i],ratio = (p.tip-p.root).length/((d.upper+d.lower)*m.scale)
                    precondition(p.tip.x.isFinite && p.tip.y.isFinite && p.knee.x.isFinite && p.knee.y.isFinite)
                    if ratio > maxStretch { maxStretch = ratio;maxInfo = "\(m.boundary.phase) limb \(i) t=\(m.boundary.elapsed)" }
                    if !rig.usesProceduralFeet && !d.hidden && !d.arm {
                        maxTipError = max(maxTipError,(rig.toWorld(rig.deform(d.tip))-p.tip).length)
                    }
                    if p.planted && previous.count == rig.poses.count && previous[i].planted && lastWall == rig.onWall && lastFacing == rig.facing && lastPhase == m.boundary.phase {
                        precondition((p.tip-previous[i].tip).length < 0.001,"\(kind) planted foot slides")
                        stanceFrames += 1
                    }
                    if !p.planted && !d.arm && m.boundary.phase == .walking { swingFrames += 1 }
                }
                previous = rig.poses;lastWall = rig.onWall;lastFacing = rig.facing;lastPhase = m.boundary.phase
            }
            if ![PetKind.ghost,.cloud,.jellyfish].contains(kind) { precondition(stanceFrames > 500 && swingFrames > 100) }
            precondition(maxStretch < 2.05,"\(kind) excessive limb stretch: \(maxInfo)")
            precondition(maxTipError < 1.5,"\(kind) artwork is detached from its foot target")
            print("\(kind.rawValue): fixed stance \(stanceFrames), swing \(swingFrames), maximum extension \(String(format:"%.2f",maxStretch)) at \(maxInfo), mesh-tip error \(String(format:"%.2f",maxTipError))")
            m.target = V(200,650);m.input(at:t)
            let arm = m.arms[(m.nextArm+m.arms.count-1)%m.arms.count]
            _ = arm.acceptGlyph("a",forStrike:arm.strikeCount,at:t)
            m.setLocomotionEnabled(false)
            precondition(arm.glyph == "a" && m.target != nil,"closing roaming canceled letter delivery")
            for f in 1...3600 {
                t += 1.0/60
                if f%12 == 0 { m.input(at:t) }
                if f%90 == 0 { m.click(at:V(400,300),time:t) }
                if f%600 == 0 { m.boundary.showcase();m.boundary.peek() }
                m.step(to:t,dt:1.0/60)
                precondition(!m.boundary.enabled && m.boundary.phase == .resting && m.boundary.position == m.boundary.home)
                precondition(m.locomotion.weight == 0 && m.locomotion.poses.isEmpty)
            }
            precondition(m.arms.reduce(0,{$0+$1.strikeCount}) > 300)
            for next in PetKind.allCases {
                m.configure(next);m.place(frame:CGRect(x:1440,y:-540,width:2560,height:1440),visible:CGRect(x:1440,y:-540,width:2560,height:1415),enter:true)
                precondition(!m.boundary.enabled && m.boundary.phase == .resting && m.boundary.position == m.boundary.home)
            }
            print("PASS \(kind.rawValue): disabled for 60s with typing/clicks; all role/display switches remain disabled")
        }
    }
}
