import Foundation
import CoreGraphics

/// Shared idle beat, independent member skeletons, and a separate group scheduler.
final class FiveCatsMotion {
    private(set) var time = 0.0
    private(set) var strength = 1.0
    var swayEnabled = true
    var tailPlayEnabled = true
    let formation = CatFormation()
    let rigs = (0..<5).map { CatSkeleton(index:$0) }
    static let count = 5
    static let width = 72.0,height = 96.0,spacing = 74.0
    static let paw = CatSkeleton.feet[1]
    func reset() {
        time = 0;strength = swayEnabled ? 1 : 0;formation.reset()
        for rig in rigs { rig.reset() }
        updateRigs(dt:1.0/60,reaches:[])
    }
    func configure(area: CGRect,anchor: V,scale: Double,enabled: Bool) {
        formation.configure(area:area,anchor:anchor,scale:scale,enabled:enabled)
        for rig in rigs { rig.reset() }
        updateRigs(dt:1.0/60,reaches:[])
    }
    func step(dt: Double,paused: Bool,enabled: Bool,reaches: [Double]) {
        guard !paused else { return }
        time += dt
        strength += ((swayEnabled ? 1.0 : 0.0)-strength)*(1-exp(-dt*8))
        formation.setEnabled(enabled);formation.step(dt:dt,paused:false)
        updateRigs(dt:dt,reaches:reaches)
    }
    private func updateRigs(dt: Double,reaches: [Double]) {
        for i in 0..<5 {
            rigs[i].prepare(formation.placements[i],time:time,beat:beat,strength:strength,dt:dt,reach:i < reaches.count ? reaches[i] : 0)
        }
    }
    var beat: Double { time*2*Double.pi/2.8 }
    func angle(_ index: Int) -> Double { rigs[index].angle }
    func pivot(_ index: Int) -> V { rigs[index].placement.pivot }
    func deform(_ p: V,index: Int) -> V { rigs[index].deform(p) }
    func point(_ p: V,index: Int) -> V { rigs[index].localToGroup(deform(p,index:index)) }
    func pawRoot(_ index: Int) -> V { point(Self.paw,index:index) }
    func tailRoot(_ index: Int) -> V { point(V(-65,-49),index:index) }
    var bounds: CGRect {
        var bounds = CGRect.null
        for i in 0..<5 {
            for p in [V(-104,-88),V(104,-88),V(-104,112),V(104,112)] {
                let v = rigs[i].localToGroup(p)
                bounds = bounds.union(CGRect(x:v.x-2,y:v.y-2,width:4,height:4))
            }
        }
        return bounds
    }
    static func coat(_ index: Int) -> (body:String,light:String,dark:String) {
        let colors = [("#E8AD68","#F5CE99","#C68E56"),("#F0E0C8","#FFF1DE","#CDBDA8"),
                      ("#B7B2AB","#E0DAD1","#8F8984"),("#E7C39B","#F7E8D2","#B39880"),("#665850","#99877A","#4B403B")]
        return colors[index%count]
    }
}
