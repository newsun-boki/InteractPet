import Foundation
import CoreGraphics

@main struct CatGroupTests {
    static func main() {
        let frame = CGRect(x:1440,y:-540,width:2560,height:1440)
        let baseline = PetMotion(),active = PetMotion()
        for m in [baseline,active] { m.configure(.fivecats);m.place(frame:frame,visible:frame,enter:true);m.fiveCats.formation.showcase() }
        active.target = V(210,620)
        var maxTipError = 0.0,maxSlip = 0.0,maxMove = 0.0,maxMeshError = 0.0,letters = 0,wallFrames = 0,walkingFrames = 0
        var oldTips = [Int:V](),oldPlanted = Set<Int>()
        var oldNodes = active.arms.map {$0.nodes}
        for f in 1...1920 {
            let t = Double(f)/60
            if f%6 == 1 {
                let i = active.nextArm;active.input(at:t)
                precondition(active.arms[i].acceptGlyph("a",forStrike:active.arms[i].strikeCount,at:t));letters += 1
            }
            if f%100 == 0 { active.click(at:V(440,650),time:t) }
            for m in [baseline,active] { m.step(to:t,dt:1.0/60) }
            precondition(active.fiveCats.formation.phase == baseline.fiveCats.formation.phase)
            precondition(active.fiveCats.time == baseline.fiveCats.time)
            var planted = Set<Int>(),tips = [Int:V]()
            for i in 0..<5 {
                let rig = active.fiveCats.rigs[i],reference = baseline.fiveCats.rigs[i]
                precondition(rig.placement.pivot == reference.placement.pivot && rig.cycle == reference.cycle)
                if rig.placement.surface == .wall { wallFrames += 1 }
                if rig.speed > 5 && rig.placement.surface == .ground { walkingFrames += 1 }
                precondition((active.arms[i].nodes[0]-(active.body+active.attachmentOffset(i)*active.scale)).length < 0.001)
                precondition(rig.legs.count == 4 && rig.spine.count == 4 && rig.tail.count == 4)
                for j in 0..<4 {
                    let leg = rig.legs[j],p = rig.localToGroup(leg.tip),key = i*4+j
                    precondition(p.x.isFinite && p.y.isFinite)
                    if leg.planted && rig.gaitWeight > 0.9 {
                        maxTipError = max(maxTipError,(p-rig.localToGroup(leg.target)).length)
                        maxMeshError = max(maxMeshError,(p-rig.localToGroup(rig.deform(CatSkeleton.feet[j]))).length)
                        if oldPlanted.contains(key),let old = oldTips[key] { maxSlip = max(maxSlip,(p-old).length) }
                        planted.insert(key);tips[key] = p
                    }
                }
                for (n,p) in active.arms[i].nodes.enumerated() where f > 1 { maxMove = max(maxMove,(p-oldNodes[i][n]).length) }
            }
            oldTips = tips;oldPlanted = planted;oldNodes = active.arms.map {$0.nodes}
            if active.fiveCats.formation.phase == .walking {
                for i in 1..<5 { precondition(active.fiveCats.pivot(i).x-active.fiveCats.pivot(i-1).x >= 73.9,"Walking cats crossed") }
            }
        }
        print("METRICS planted IK error",maxTipError,"slip/frame",maxSlip,"mesh-foot error",maxMeshError,"arm travel/frame",maxMove,"letters",letters,"wallFrames",wallFrames,"walkFrames",walkingFrames);fflush(stdout)
        precondition(letters == 320 && wallFrames > 400 && walkingFrames > 1000)
        precondition(maxTipError < 0.001 && maxSlip < 0.001,"Planted paws slid on their support surface")
        precondition(maxMeshError < 0.75,"Textured paw separated from the IK foot")
        precondition(maxMove < 80)
        // Stop during a wall action; return without a root teleport, then stay off.
        active.fiveCats.formation.peek()
        for f in 1921...2280 { active.step(to:Double(f)/60,dt:1.0/60) }
        active.setLocomotionEnabled(false)
        active.fiveCats.formation.peek();active.fiveCats.formation.showcase()
        for f in 2281...3000 { active.click(at:V(200,200),time:Double(f)/60);active.step(to:Double(f)/60,dt:1.0/60) }
        precondition(active.fiveCats.formation.phase == .seated && !active.fiveCats.formation.enabled)
        precondition((0..<5).allSatisfy {active.fiveCats.pivot($0) == CatFormation.home($0)})
        active.setLocomotionEnabled(true);active.fiveCats.formation.showcase();active.fiveCats.swayEnabled = false
        for f in 3001...3180 { active.step(to:Double(f)/60,dt:1.0/60) }
        precondition(active.fiveCats.formation.phase == .walking && active.fiveCats.strength < 0.0001)
        let points = (0..<5).map {active.fiveCats.pivot($0)},time = active.fiveCats.time
        active.paused = true
        for f in 3181...3240 { active.step(to:Double(f)/60,dt:1.0/60) }
        precondition(time == active.fiveCats.time && points == (0..<5).map {active.fiveCats.pivot($0)})
        active.paused = false;active.setLocomotionEnabled(false)
        for r in [CGRect(x:-1920,y:100,width:480,height:400),CGRect(x:0,y:0,width:1440,height:875),CGRect(x:1440,y:-540,width:2560,height:1440)] {
            active.scale = 1.6;active.place(frame:r,visible:r,enter:true)
            precondition(!active.fiveCats.formation.enabled && active.fiveCats.formation.phase == .seated)
            active.setLocomotionEnabled(true);active.fiveCats.formation.showcase()
            for f in 1...1560 {
                active.step(to:54+Double(f)/60,dt:1.0/60)
                if f%6 == 0 {
                    for i in 0..<5 {
                        for x in stride(from:-88.0,through:88.0,by:22) {
                            for y in stride(from:-76.0,through:100.0,by:22) {
                                let p = active.body+active.fiveCats.point(V(x,y),index:i)*active.scale
                                precondition(p.x >= r.minX-0.5 && p.x <= r.maxX+0.5 && p.y >= r.minY-0.5 && p.y <= r.maxY+0.5,"Group mesh left its display")
                            }
                        }
                    }
                }
            }
            active.setLocomotionEnabled(false)
        }
        print("PASS group choreography: delayed followers, independent 4-leg rigs, spline spine/tail, 320 letters during walk/climb, attached moving roots, off/return, pause, sway independence and display changes")
    }
}
