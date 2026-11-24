import Foundation
import CoreGraphics

@main struct CharacterMotionTests {
    static func main() {
        for kind in PetKind.allCases {
            let m = PetMotion();m.anchor = V(1100,180);m.configure(kind)
            precondition(m.arms.count == kind.armCount)
            m.target = V(220,590);m.step(to:0,dt:1.0/60)
            m.input(at:0);m.arms[0].glyph = "A"
            var nearest = Double.infinity,sawDelivery = false,maxMove = 0.0
            var old = m.arms[0].nodes.last!
            for frame in 1...420 {
                m.step(to:Double(frame)/60,dt:1.0/60)
                let tip = m.arms[0].nodes.last!
                nearest = min(nearest,(tip-V(220,590)).length)
                maxMove = max(maxMove,(tip-old).length);old = tip
                sawDelivery = sawDelivery || m.arms[0].deliveredAt > 0
                for arm in m.arms {
                    precondition(arm.nodes.allSatisfy {$0.x.isFinite && $0.y.isFinite})
                    precondition((arm.nodes[0]-(m.body+m.attachmentOffset(arm.index)*m.scale)).length < 0.001)
                }
            }
            precondition(nearest < 26,"\(kind): delivery path missed target")
            precondition(sawDelivery,"\(kind): letter never delivered")
            precondition(m.arms.allSatisfy {$0.reachAmount < 0.001 && $0.glyph == nil})
            precondition(maxMove < 71,"\(kind): visible arm teleport")
            for n in 0..<kind.armCount*3 { m.input(at:8+Double(n)/10) }
            precondition(m.arms[0].strikeCount == 4)
            precondition(m.arms.dropFirst().allSatisfy {$0.strikeCount == 3})
            precondition(m.nextArm == 1%kind.armCount)
            let clickedArm = m.nextArm
            m.click(at:V(-600,800),time:12);m.invalidateTarget()
            precondition(m.arms[clickedArm].pointerStrike && m.arms[clickedArm].reachUntil > 12)
            m.invalidateTarget(all:true)
            precondition(m.arms.allSatisfy {$0.glyph == nil && $0.reachUntil <= m.now})
            print("PASS \(kind.rawValue): \(kind.armCount) delivery limbs, contact, return, root attachment, mouse target, label expiry")
        }
        let switcher = PetMotion();switcher.target = V(100,600)
        switcher.step(to:0,dt:1.0/60)
        for _ in 0..<7 { switcher.input(at:0) }
        let oldGeneration = switcher.generation
        switcher.configure(.chameleon)
        precondition(switcher.generation != oldGeneration && switcher.nextArm == 0 && switcher.arms.count == 1)
        for frame in 1...120 {
            let kind = PetKind.allCases[frame%PetKind.allCases.count]
            switcher.configure(kind);switcher.input(at:Double(frame)/60);switcher.step(to:Double(frame)/60,dt:1.0/60)
            precondition(switcher.nextArm < switcher.arms.count)
        }
        print("PASS: changing characters during typing invalidates old limb generation and keeps indices valid")
    }
}
