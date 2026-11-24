import Foundation

@main struct SwarmTests {
    static func main() {
        let m = SwarmMotion(),r = CGRect(x:-1440,y:100,width:1440,height:900)
        m.layout([r,CGRect(x:0,y:0,width:1920,height:1080)])
        for style in SwarmStyle.allCases {
            m.select(style)
            let id = m.emit(at:V(-700,540))!;precondition(m.accept("萤",for:id))
            let w = m.waves[0]
            precondition(w.starts.allSatisfy {!r.contains($0.point)})
            precondition(w.starts.contains {$0.x<r.minX} && w.starts.contains {$0.x>r.maxX} && w.starts.contains {$0.y<r.minY} && w.starts.contains {$0.y>r.maxY})
            for _ in 0..<190 {
                for wave in m.waves { for i in wave.starts.indices {
                    let p = m.particle(wave,i)
                    precondition(p.position.x.isFinite && p.position.y.isFinite && p.alpha>=0 && p.alpha<=1)
                }}
                m.step(1.0/60)
            }
            precondition(m.waves.isEmpty)
        }
        m.select(.fireflies)
        var arrivals = 0
        for frame in 0..<900 {
            let id = m.emit(at:V(-700+Double(frame%30),540),click:frame%3==0)!
            precondition(m.accept(String(frame%10),for:id))
            m.step(1.0/120)
            arrivals += m.waves.filter { m.particle($0,0).progress>=1 }.count
            precondition(m.count<=64 && m.waves.count<=m.capacity)
        }
        precondition(arrivals>100,"Fast typing starved all arrivals")
        let token = m.waves.last!.id
        m.clearLetters();precondition(m.waves.allSatisfy {$0.glyph==nil})
        m.paused = true;let before = m.now
        m.step(1);precondition(m.now==before && m.emit(at:V(-500,500))==nil && !m.accept("x",for:token))
        m.paused = false;m.select(.bees);precondition(!m.accept("x",for:token))
        for p in [V(-1439,101),V(-1,999),V(-1439,999),V(-1,101)] {
            m.clear();let id = m.emit(at:p)!;precondition(m.accept("a",for:id))
            let w = m.waves[0];precondition(r.insetBy(dx:40,dy:40).contains(w.landing.point))
            precondition(abs(w.landing.y-p.y)>=45)
        }
        m.layout([CGRect(x:0,y:0,width:1000,height:700)]);precondition(m.waves.isEmpty)
        precondition(m.emit(at:V(-100,500))==nil && m.emit(at:V(.nan,0))==nil)
        m.reducedMotion = true;_ = m.emit(at:V(500,400));let w = m.waves[0]
        precondition((m.particle(w,0,age:0).position-w.landing).length<24)
        m.select(nil);precondition(m.waves.isEmpty && m.emit(at:V(500,400))==nil)
        print("PASS: all 16 styles; four-edge entry; negative/dual-screen geometry; 900 rapid events; bounded particles; letters; stale callbacks; pause; corners; display change; reduced motion")
    }
}
