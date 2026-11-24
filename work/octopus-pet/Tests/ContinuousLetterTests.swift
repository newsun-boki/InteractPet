import Foundation
import CoreGraphics

@main struct ContinuousLetterTests {
    static func main() {
        // Character extraction runs after AX validation. Once the carrier is already
        // extended, physical contact can occur before that asynchronous result.
        for kind in [PetKind.chameleon,.cloud,.yarncat] {
            let m = PetMotion();m.configure(kind);m.anchor = V(1100,180)
            m.target = V(220,590);m.step(to:0,dt:1.0/60)
            var request: (serial:Int,glyph:String,frame:Int)?
            var accepted = 0,contactBeforeCallback = 0,blankFrames = 0
            let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
            var latest: String?
            for frame in 1...360 {
                let t = Double(frame)/60
                if frame%6 == 1 {
                    m.input(at:t)
                    request = (m.arms[0].strikeCount,String(alphabet[((frame-1)/6)%alphabet.count]),frame+2)
                }
                m.step(to:t,dt:1.0/60)
                if let pending = request,frame == pending.frame {
                    if m.arms[0].contacted { contactBeforeCallback += 1 }
                    if m.arms[0].acceptGlyph(pending.glyph,forStrike:pending.serial,at:t) {
                        accepted += 1;latest = pending.glyph
                    }
                    request = nil
                }
                if frame > 90 {
                    if m.arms[0].glyph == nil { blankFrames += 1 }
                    if request == nil { precondition(m.arms[0].glyph == latest,"\(kind): latest letter missing") }
                    precondition(m.arms[0].deliveredAt < 0,"\(kind): current letter faded during continuous input")
                    if kind == .cloud { precondition(m.arms[0].courierProgress > 0.99,"Rainbow courier restarted at the body") }
                }
            }
            print("\(kind): accepted \(accepted)/60, contact-before-letter \(contactBeforeCallback), blank frames \(blankFrames)");fflush(stdout)
            precondition(contactBeforeCallback > 20,"Scenario must exercise late delivery after contact")
            precondition(accepted == 60,"\(kind): async letters discarded while carrier stayed extended")
            precondition(blankFrames == 0,"\(kind): letter blinked off between consecutive keystrokes")
            for frame in 361...660 { m.step(to:Double(frame)/60,dt:1.0/60) }
            precondition(m.arms[0].glyph == nil && m.arms[0].reachAmount < 0.001,"\(kind): did not clear and retract after typing stopped")
            m.input(at:12);let oldSerial = m.arms[0].strikeCount
            m.input(at:12.02);let currentSerial = m.arms[0].strikeCount
            precondition(!m.arms[0].acceptGlyph("old",forStrike:oldSerial,at:12.03))
            precondition(m.arms[0].acceptGlyph("new",forStrike:currentSerial,at:12.04))
            m.invalidateTarget(all:true)
            precondition(!m.arms[0].acceptGlyph("late",forStrike:currentSerial,at:12.05))
            precondition(m.arms[0].glyph == nil)
            m.click(at:V(100,300),time:13)
            precondition(!m.arms[0].acceptGlyph("click",forStrike:m.arms[0].strikeCount,at:13.01))
        }
        print("PASS: continuous typing keeps all letters current; inactivity clears and retracts")
    }
}
