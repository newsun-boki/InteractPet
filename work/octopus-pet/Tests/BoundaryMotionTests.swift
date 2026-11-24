import Foundation
import CoreGraphics

@main struct BoundaryMotionTests {
    static func main() {
        let frames = [CGRect(x:0,y:0,width:1440,height:900),CGRect(x:1440,y:-540,width:2560,height:1440),
                      CGRect(x:-1920,y:100,width:1920,height:1080),CGRect(x:0,y:900,width:1280,height:800)]
        for kind in PetKind.allCases where kind.canRoam {
            for frame in frames {
                let usable = CGRect(x:frame.minX+45,y:frame.minY+60,width:frame.width-45,height:frame.height-85)
                let b = BoundaryMotion();b.configure(frame:frame,visible:usable,kind:kind,scale:1.3)
                precondition(b.position.x > frame.maxX)
                for _ in 0..<3600 {
                    b.step(dt:1.0/60,paused:false)
                    precondition(b.position.x.isFinite && b.position.y.isFinite)
                    precondition(b.position.x >= usable.minX && b.position.x <= frame.maxX+170)
                    precondition(b.position.y >= b.ground-0.01 && b.position.y < frame.maxY)
                    precondition(b.particles.count <= 80 && b.impacts.count <= 10)
                }
                precondition(["entering","walking","climbing","performing","returning"].allSatisfy {b.visited.contains($0)},"\(kind): incomplete edge routine")
                precondition(b.impactCount >= 3,"\(kind): no edge response")
                if !b.floating && kind != .chameleon && kind != .spider {
                    precondition(b.visited.contains("falling"),"\(kind): gravity never used")
                }
                let frozen = b.position,phase = b.phase,time = b.elapsed
                for _ in 0..<60 { b.step(dt:1.0/60,paused:true) }
                precondition(b.position == frozen && b.phase == phase && b.elapsed == time)
                b.peek()
                for _ in 0..<120 { b.step(dt:1.0/60,paused:false) }
                precondition(b.position.x > frame.maxX && b.position.x < frame.maxX+40)
                b.setEnabled(false)
                for _ in 0..<200 { b.step(dt:1.0/60,paused:false) }
                precondition((b.position-b.home).length < 0.01 && !b.enabled)
                b.configure(frame:frames[0],visible:frames[0],kind:kind,scale:0.7,enter:false)
                precondition(b.position == b.home && b.particles.isEmpty)
            }
            print("PASS \(kind): 4 display layouts, enter/crawl/edge routine, collisions, explicit pause, peek and return")
        }
        let m = PetMotion();m.configure(.chameleon)
        m.place(frame:frames[0],visible:frames[0],enter:false);m.boundary.peek()
        for frame in 1...150 { m.step(to:Double(frame)/60,dt:1.0/60) }
        let position = m.boundary.position
        m.target = V(100,700)
        for frame in 151...390 {
            let t = Double(frame)/60
            if frame%6 == 0 {m.input(at:t);_ = m.arms[0].acceptGlyph("a",forStrike:m.arms[0].strikeCount,at:t)}
            m.step(to:t,dt:1.0/60)
            precondition(m.boundary.position == position)
            precondition((m.arms[0].nodes[0]-(m.body+m.attachmentOffset(0)*m.scale)).length < 0.001)
        }
        precondition(m.arms[0].glyph == "a" && (m.arms[0].nodes.last!-m.target!).length < 30)
        print("PASS: half-hidden chameleon remains attached and updates letters while reaching across screen")
    }
}
