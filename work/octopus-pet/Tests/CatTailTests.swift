import Foundation
import CoreGraphics

@main struct CatTailTests {
    static func main() {
        let m = PetMotion();m.configure(.fivecats);m.setLocomotionEnabled(false)
        let area = CGRect(x:-1280,y:100,width:1280,height:800)
        m.place(frame:area,visible:area,enter:false)
        var moods = Set<String>(),phases = Set<String>(),maxStep = 0.0
        var previous = m.arms.map {$0.nodes}
        var clock = 0.0
        func step(_ n: Int) {
            for _ in 0..<n {
                clock += 1.0/60;m.step(to:clock,dt:1.0/60)
                for i in 0..<5 {
                    let arm = m.arms[i],tail = arm.catTail!
                    moods.insert(tail.mood.rawValue);phases.formUnion(tail.visited)
                    precondition((arm.nodes[0]-(m.body+m.fiveCats.tailRoot(i)*m.scale)).length < 0.001)
                    precondition(tail.controls.count == 8 && arm.nodes.allSatisfy {$0.x.isFinite && $0.y.isFinite})
                    if clock > 1.0/60 {
                        for j in arm.nodes.indices { maxStep = max(maxStep,(arm.nodes[j]-previous[i][j]).length) }
                    }
                    if tail.phase == .idle {
                        precondition(arm.nodes.allSatisfy {$0.x >= area.minX && $0.x <= area.maxX && $0.y >= area.minY && $0.y <= area.maxY})
                    }
                    if Int(clock*60)%30 == 0 {
                        for j in 1..<7 {
                            let u = Double(j)/7,e = 0.000001,p = CatTailMotion.sample(tail.controls,u)
                            let left = (p-CatTailMotion.sample(tail.controls,u-e))/e
                            let right = (CatTailMotion.sample(tail.controls,u+e)-p)/e
                            precondition((left-right).length < 0.25,"Spline tangent broke at a control knot")
                        }
                    }
                }
                previous = m.arms.map {$0.nodes}
            }
        }
        step(1200)
        precondition(["swaying","question","curl","flick"].allSatisfy {moods.contains($0)})
        for i in 0..<5 {
            m.target = V(-1000,680);let a = m.nextArm;m.input(at:clock)
            precondition(a == i && m.arms[a].acceptGlyph("a",forStrike:m.arms[a].strikeCount,at:clock))
            step(180)
        }
        step(180)
        precondition(["idle","anticipating","extending","tapping","recoiling"].allSatisfy {phases.contains($0)})
        precondition(m.arms.allSatisfy {$0.reachAmount < 0.001 && $0.glyph == nil && $0.catTail!.extensionAmount < 0.001})
        m.fiveCats.tailPlayEnabled = false;step(180)
        precondition(m.arms.allSatisfy {$0.catTail!.mood == .quiet})
        let pausedNodes = m.arms.map {$0.nodes};m.paused = true;step(60)
        precondition(m.arms.map {$0.nodes} == pausedNodes,"Pause moved a tail")
        m.paused = false
        m.target = V(-1100,730);let next = m.nextArm;m.input(at:clock)
        precondition(m.arms[next].acceptGlyph("b",forStrike:m.arms[next].strikeCount,at:clock))
        step(90);precondition(m.arms[next].catTail!.visited.contains("tapping"))
        // Cancellation clears text immediately; the same visible spline returns.
        m.invalidateTarget(all:true);precondition(m.arms.allSatisfy {$0.glyph == nil})
        step(300)
        precondition(m.arms.allSatisfy {$0.catTail!.extensionAmount < 0.001})
        for point in [m.body+m.attachmentOffset(m.nextArm)*m.scale,V(2400,-800),V(-2800,1450)] {
            m.click(at:point,time:clock);step(180)
        }
        precondition(maxStep < 71,"Tail teleported")
        print("PASS tails: four idle moods; prewind/extend/tap/recoil; five tail roots; C1 spline knots; persistent geometry; paused tails; flourishes-off keeps delivery; secure cancellation; near/far clicks; maximum step",maxStep)
    }
}
