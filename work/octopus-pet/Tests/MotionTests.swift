import Foundation
import CoreGraphics

@main struct MotionTests {
    static func main() {
        var spring = Spring()
        for _ in 0..<120 { spring.step(V(100,50),1.0/60) }
        precondition((spring.value-V(100,50)).length < 0.01)
        let m = PetMotion();m.anchor = V(1180,100)
        var maxTravel = 0.0
        var oldTip: V?
        var maxFrame = 0
        for frame in 0..<1800 {
            let t = Double(frame)/60
            if frame < 600 { m.target = V(150+sin(t)*30,620);if frame%6==0 {m.input(at:t)} }
            else if frame < 1200 { m.target = V(-1900,1400);if frame%6==0 {m.input(at:t)} }
            else { m.target = nil }
            m.step(to:t,dt:1.0/60)
            for arm in m.arms {
                precondition(arm.nodes.count == 48)
                precondition(arm.nodes.allSatisfy {$0.x.isFinite && $0.y.isFinite})
                let expected = m.body+V(arm.side*(29-arm.rank*4),-31-arm.rank)*m.scale
                precondition((arm.nodes[0]-expected).length < 0.001)
            }
            if let old = oldTip { let d = (m.arms[6].nodes.last!-old).length;if d > maxTravel {maxTravel = d;maxFrame = frame} }
            oldTip = m.arms[6].nodes.last!
        }
        precondition(m.arms.allSatisfy {$0.reachAmount < 0.001})
        print("Max travel before check:",maxTravel,"frame:",maxFrame);fflush(stdout)
        precondition(maxTravel < 180,"An arm teleported instead of retracting smoothly")
        precondition((m.arms[6].nodes.last!-m.anchor).length < 120)
        precondition(m.arms.allSatisfy {$0.strikeCount == 25})
        let solo = PetMotion();solo.anchor = V(1180,100);solo.target = V(250,620)
        solo.step(to:0,dt:1.0/60);solo.input(at:0)
        var nearest = Double.infinity
        for frame in 1...240 {
            solo.step(to:Double(frame)/60,dt:1.0/60)
            nearest = min(nearest,(solo.arms[0].nodes.last!-solo.target!).length)
        }
        precondition(nearest < 25)
        precondition(solo.arms[0].strikeCount == 1 && solo.arms.dropFirst().allSatisfy {$0.strikeCount==0})
        precondition(solo.arms[0].reachAmount < 0.001)
        let mouse = PetMotion();mouse.anchor = V(1180,100)
        mouse.step(to:0,dt:1.0/60);mouse.click(at:V(300,600),time:0)
        var mouseDistance = Double.infinity,bodyTravel = 0.0
        for frame in 1...240 {
            mouse.invalidateTarget()
            mouse.step(to:Double(frame)/60,dt:1.0/60)
            mouseDistance = min(mouseDistance,(mouse.arms[0].nodes.last!-V(300,600)).length)
            bodyTravel = max(bodyTravel,(mouse.body-mouse.anchor).length)
        }
        precondition(mouseDistance < 25,"Click arms must survive losing text focus")
        precondition(bodyTravel > 10 && bodyTravel < 40,"Body must react without leaving its corner")
        precondition(mouse.arms[0].reachAmount < 0.001)
        mouse.click(at:V(50,500),time:5);mouse.invalidateTarget(all:true)
        mouse.step(to:5.1,dt:1.0/60)
        precondition(mouse.arms.allSatisfy {$0.reachUntil <= mouse.now})
        let letters = PetMotion();letters.anchor = V(1180,100);letters.target = V(250,620)
        letters.step(to:0,dt:1.0/60);letters.input(at:0);letters.arms[0].glyph = "a"
        var sawDelivery = false
        for frame in 1...240 {
            letters.step(to:Double(frame)/60,dt:1.0/60)
            if letters.arms[0].deliveredAt > 0 { sawDelivery = true }
        }
        precondition(sawDelivery && letters.arms[0].glyph == nil)
        let straight = Arm(0)
        straight.nodes = (0..<48).map {V(Double($0)*10,100)}
        precondition((straight.letterAnchor(distance:70)-V(400,100)).length < 0.001)
        precondition(straight.letterAnchor(distance:9999)==straight.nodes[0])
        precondition(straight.letterAnchor(distance:0)==straight.nodes.last!)
        print("PASS: letter sits 70 points behind the tip; short arms clamp at the root.")
        letters.input(at:5);letters.arms[1].glyph = "b";letters.invalidateTarget(all:true)
        precondition(letters.arms.allSatisfy {$0.glyph == nil})
        print("PASS: carried letter reaches delivery; transient label expires; secure cancellation clears labels.")
        print("PASS: click target independent of caret; body pull/rebound; complete return; secure cancellation.")
        print("PASS: stable spring; 30s motion; 8 attached arms; finite geometry; round-robin; isolated reach/contact/return.")
        print("Maximum tip travel per 60Hz step:",maxTravel)
    }
}
