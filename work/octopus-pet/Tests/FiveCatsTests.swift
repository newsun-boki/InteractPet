import Foundation
import CoreGraphics

@main struct FiveCatsTests {
    static func main() {
        let frame = CGRect(x:1440,y:-540,width:2560,height:1440)
        let baseline = PetMotion(),active = PetMotion()
        for m in [baseline,active] { m.configure(.fivecats);m.setLocomotionEnabled(false);m.place(frame:frame,visible:frame,enter:true) }
        precondition(active.arms.count == 5 && active.boundary.phase == .resting)
        active.target = V(180,640)
        var letters = 0
        for f in 1...1800 {
            let t = Double(f)/60
            if f%6 == 1 {
                let i = active.nextArm
                active.input(at:t)
                precondition(active.arms[i].acceptGlyph("a",forStrike:active.arms[i].strikeCount,at:t));letters += 1
            }
            if f%120 == 0 { active.click(at:V(250,350),time:t) }
            baseline.step(to:t,dt:1.0/60);active.step(to:t,dt:1.0/60)
            precondition(baseline.fiveCats.time == active.fiveCats.time)
            precondition(active.boundary.position == active.boundary.home && active.boundary.phase == .resting)
            for i in 0..<5 {
                precondition(active.fiveCats.angle(i) == active.fiveCats.angle(0))
                precondition((active.arms[i].nodes[0]-(active.body+active.attachmentOffset(i)*active.scale)).length < 0.001)
                precondition(active.fiveCats.pivot(i) == CatFormation.home(i))
            }
        }
        precondition(letters == 300 && active.arms.allSatisfy {$0.strikeCount >= 60})
        active.boundary.showcase();active.boundary.peek()
        precondition(active.boundary.phase == .resting)
        active.fiveCats.swayEnabled = false
        for f in 1801...1980 { active.step(to:Double(f)/60,dt:1.0/60) }
        precondition(abs(active.fiveCats.angle(0)) < 0.0001)
        let time = active.fiveCats.time;active.paused = true
        for f in 1981...2040 { active.step(to:Double(f)/60,dt:1.0/60) }
        precondition(active.fiveCats.time == time)
        active.paused = false;active.fiveCats.swayEnabled = true;active.setLocomotionEnabled(false)
        for f in 2041...2220 { active.step(to:Double(f)/60,dt:1.0/60) }
        precondition(active.fiveCats.strength > 0.999 && active.boundary.position == active.boundary.home)
        for width in [480.0,1280,2560] {
            active.scale = 1.6
            let r = CGRect(x:-1920,y:100,width:width,height:800)
            active.place(frame:r,visible:r,enter:true)
            precondition(active.boundary.home.x-active.kind.sceneHalfWidth*active.scale > r.minX)
            precondition(active.boundary.home.x+active.kind.sceneHalfWidth*active.scale < r.maxX)
        }
        print("PASS five cats: synchronized seated sway, 300 letters, round-robin paws, moving attachments, fixed foot pivots, independent sway/off/pause controls, 3 display widths")
    }
}
