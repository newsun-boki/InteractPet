import Foundation
import CoreGraphics

enum SwarmStyle: String, CaseIterable {
    case fireflies,prism,bees,butterflies,stars,meteors,bubbles,jellies,petals,snow,ghosts,fish,hearts,planes,runes,plasma
    var name: String { ["萤火虫 · 夏夜来信","彩虹粒子 · 棱镜星尘","小蜜蜂 · 蜜糖邮局","糖果蝴蝶 · 翩翩送达","星星精灵 · 晚安信使","流星 · 银河速递","泡泡 · 轻轻捎来","迷你水母 · 深海荧光","樱花 · 花间来信","雪晶 · 冬日微光","小幽灵 · 软萌夜游","发光小鱼 · 游进屏幕","爱心 · 怦然送达","纸飞机 · 天空邮递","魔法符文 · 星环召唤","霓虹电浆 · 能量汇聚"][index] }
    var index: Int { Self.allCases.firstIndex(of:self)! }
    var colors: [String] {
        [["#CBF578","#F6DC74"],["#EE89FF","#72DFEE","#FFCC8B"],["#FFD46C","#F4A95D"],["#F7A4DD","#B5A1FF"],["#FFE09B","#FFAECA"],["#88DAFF","#B4A2FF"],["#ACEEFF","#F7BDEB"],["#9FEAFF","#C5AEFF"],["#FFB6CD","#FFE1EA"],["#D1F7FF","#8DCDFF"],["#C6B9FA","#EDE2FF"],["#74ECE0","#92BCFF"],["#FF93BF","#FFB4A7"],["#B8D7FF","#E5F3FF"],["#D9B1FF","#FFE39B"],["#59E9F5","#F485E8"]][index]
    }
    var cute: Bool { ![.prism,.meteors,.runes,.plasma].contains(self) }
}
struct SwarmWave {
    let id: Int
    let style: SwarmStyle
    let birth: Double
    let target: V
    let frame: CGRect
    let landing: V
    let click: Bool
    let starts: [V]
    var glyph: String?
}
struct SwarmParticle {
    let position: V
    let angle: Double
    let alpha: Double
    let scale: Double
    let progress: Double
}
final class SwarmMotion {
    var style: SwarmStyle?
    var screens: [CGRect] = []
    private(set) var waves: [SwarmWave] = []
    private(set) var now = 0.0
    private(set) var serial = 0
    private(set) var totalWaves = 0
    private(set) var totalLetters = 0
    var paused = false
    var reducedMotion = false
    var intensity = 0.65
    var gap = 70.0
    var scale = 1.0
    let capacity = 8
    var count: Int { waves.reduce(0) {$0+$1.starts.count} }
    func clear() { waves.removeAll() }
    func clearLetters() { for i in waves.indices { waves[i].glyph = nil } }
    func select(_ next: SwarmStyle?) { style = next;clear() }
    func layout(_ frames: [CGRect]) { screens = frames.filter {$0.width>0 && $0.height>0};clear() }
    @discardableResult func emit(at target: V,click: Bool = false) -> Int? {
        guard let style = style,!paused,target.x.isFinite,target.y.isFinite,
              let frame = screens.first(where:{$0.contains(target.point)}) else { return nil }
        serial += 1
        let distance = clamp(gap,45,120)
        let below = target.y-frame.minY >= distance+40
        let landing = V(clamp(target.x+22,frame.minX+48,frame.maxX-48),clamp(target.y+(below ? -distance : distance),frame.minY+48,frame.maxY-48))
        // Coalesce fast typing into the newest carrier without restarting its flight.
        // Otherwise a bounded pool can evict every insect before any reaches the target.
        if let last = waves.last,now-last.birth<0.32,last.frame==frame,(last.target-target).length<80 {
            waves[waves.count-1] = SwarmWave(id:serial,style:style,birth:last.birth,target:target,frame:frame,landing:landing,click:click,starts:last.starts,glyph:nil)
            return serial
        }
        totalWaves += 1
        var starts:[V] = []
        for i in 0..<(click ? 8 : 6) {
            let fraction = 0.12+0.76*Double((serial*37+i*29)%101)/100
            let edge = (serial+i)%4
            let p: V
            switch edge {
            case 0:p = V(frame.minX-36,frame.minY+frame.height*fraction)
            case 1:p = V(frame.maxX+36,frame.minY+frame.height*fraction)
            case 2:p = V(frame.minX+frame.width*fraction,frame.minY-36)
            default:p = V(frame.minX+frame.width*fraction,frame.maxY+36)
            }
            starts.append(p)
        }
        if waves.count == capacity { waves.removeFirst() }
        waves.append(SwarmWave(id:serial,style:style,birth:now,target:target,frame:frame,landing:landing,click:click,starts:starts,glyph:nil))
        return serial
    }
    @discardableResult func accept(_ glyph: String,for id: Int) -> Bool {
        guard !paused,let first = glyph.first,!String(first).unicodeScalars.contains(where:{CharacterSet.controlCharacters.contains($0)}),
              let i = waves.firstIndex(where:{$0.id==id}),now-waves[i].birth<1.5 else { return false }
        waves[i].glyph = String(first);totalLetters += 1;return true
    }
    func step(_ dt: Double) {
        guard !paused else { return }
        now += clamp(dt,0,0.05)
        waves.removeAll { now-$0.birth > 2.65 }
    }
    func particle(_ wave: SwarmWave,_ index: Int,age override: Double? = nil) -> SwarmParticle {
        let age = override ?? (now-wave.birth)
        let delay = Double(index)*0.045
        let travel = reducedMotion ? 0.28 : 0.88+Double(index%3)*0.13
        let u = max(0,(age-delay)/travel)
        let theta = Double(index)*2 * .pi/Double(wave.starts.count)+Double(wave.id%17)*2.39996
        let radius = index==0 ? 0.0 : 23+Double(index%3)*8+Double(wave.id%3)*5
        let end = wave.landing+V(cos(theta)*radius,sin(theta)*radius*0.62)
        let start = reducedMotion ? end+V(cos(theta)*22,sin(theta)*22) : wave.starts[index]
        let delta = end-start
        let bend = sin(Double(wave.id+index)*1.7)*min(150,delta.length*0.22)
        let p: V;var angle = atan2(delta.y,delta.x)
        if u < 1 {
            let t = smooth(u)
            let base = bezier(start,start+delta*0.26+delta.unit.normal*bend,end-delta*0.17+delta.unit.normal*bend,end,t)
            let amplitude: Double
            switch wave.style {
            case .bees:amplitude = 13
            case .butterflies,.fish,.petals:amplitude = 25
            case .plasma,.prism:amplitude = 9
            case .meteors,.planes:amplitude = 2
            default:amplitude = 11
            }
            let wiggle = reducedMotion ? 0 : sin(u*Double(3+index%3) * .pi+theta)*sin(u * .pi)*amplitude
            p = base+delta.unit.normal*wiggle
        } else {
            let t = age-delay-travel
            let orbit = reducedMotion ? 0 : t*(wave.style == .runes ? 2.2 : 0.9)
            let scatter = reducedMotion ? 0 : smooth((t-0.65)/0.9)*48
            p = wave.landing+V(cos(theta+orbit)*(radius+scatter),sin(theta+orbit)*(radius*0.62+scatter))+V(0,sin(t*3+theta)*2)
            angle = theta+orbit + .pi/2
        }
        let fadeIn = reducedMotion ? smooth(age/0.18) : smooth(age/0.12)
        let fadeOut = 1-smooth((age-1.55)/1.05)
        return SwarmParticle(position:p,angle:angle,alpha:fadeIn*fadeOut,scale:scale*(0.8+Double(index%3)*0.14),progress:u)
    }
    var drawingBounds: CGRect {
        var bounds = CGRect.null
        for wave in waves { for i in wave.starts.indices {
            let p = particle(wave,i).position
            bounds = bounds.union(CGRect(x:p.x-65*scale,y:p.y-65*scale,width:130*scale,height:130*scale))
        }}
        return bounds
    }
}
