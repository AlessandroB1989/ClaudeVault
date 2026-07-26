import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

// Rendu d'un aperçu animé de ClaudeVault (frames PNG → GIF via ffmpeg).
// Usage: swift RenderDemo.swift <outDir> <totalFrames> [singleFrameIndex]

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "./frames"
let TOTAL = args.count > 2 ? Int(args[2]) ?? 60 : 60
let single = args.count > 3 ? Int(args[3]) : nil
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let W: CGFloat = 1200, H: CGFloat = 750

func c(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}
// Palette
let bg = c(233,233,236)
let winBg = c(255,255,255)
let titleBar = c(246,246,247)
let sidebar = c(244,243,245)
let clay = c(190,90,56)
let clayLight = c(233,152,112)
let clayTint = c(190,90,56,0.12)
let tPrim = c(29,29,31)
let tSec = c(134,134,139)
let chipDark = c(44,44,46)
let green = c(40,200,80)

func clamp(_ x: CGFloat, _ lo: CGFloat = 0, _ hi: CGFloat = 1) -> CGFloat { min(max(x, lo), hi) }
func smooth(_ f: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
    let t = clamp((f - a) / (b - a)); return t * t * (3 - 2 * t)
}

func roundRect(_ ctx: CGContext, _ r: CGRect, _ rad: CGFloat) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil))
}
func fillRound(_ ctx: CGContext, _ r: CGRect, _ rad: CGFloat, _ col: NSColor) {
    ctx.saveGState(); roundRect(ctx, r, rad); ctx.setFillColor(col.cgColor); ctx.fillPath(); ctx.restoreGState()
}

func text(_ s: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat, color: NSColor,
          weight: NSFont.Weight = .regular, mono: Bool = false, alpha: CGFloat = 1) {
    guard alpha > 0.01, !s.isEmpty else { return }
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
                    : NSFont.systemFont(ofSize: size, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color.withAlphaComponent(alpha)
    ]
    NSAttributedString(string: s, attributes: attrs).draw(at: NSPoint(x: x, y: y))
}
func textWidth(_ s: String, size: CGFloat, weight: NSFont.Weight = .regular, mono: Bool = false) -> CGFloat {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
                    : NSFont.systemFont(ofSize: size, weight: weight)
    return NSAttributedString(string: s, attributes: [.font: font]).size().width
}
func reveal(_ s: String, _ frac: CGFloat) -> String {
    let n = Int(clamp(frac) * CGFloat(s.count))
    return String(s.prefix(n))
}

func drawFrame(_ ctx: CGContext, _ fi: Int) {
    let f = CGFloat(fi)
    // Contexte AppKit en repère haut-gauche.
    ctx.saveGState()
    ctx.translateBy(x: 0, y: H); ctx.scaleBy(x: 1, y: -1)
    let ns = NSGraphicsContext(cgContext: ctx, flipped: true)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns

    // Fond
    ctx.setFillColor(bg.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

    let appear = smooth(f, 0, 7)            // fade-in global
    // Fenêtre + ombre
    let win = CGRect(x: 36, y: 26, width: 1128, height: 700)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 30, color: c(0,0,0,0.14 * appear).cgColor)
    fillRound(ctx, win, 18, winBg.withAlphaComponent(appear))
    ctx.restoreGState()
    ctx.saveGState(); roundRect(ctx, win, 18); ctx.clip()

    // Barre de titre
    ctx.setFillColor(titleBar.withAlphaComponent(appear).cgColor)
    ctx.fill(CGRect(x: 36, y: 26, width: 1128, height: 46))
    for (i, col) in [c(255,95,87), c(254,188,46), c(40,200,64)].enumerated() {
        ctx.setFillColor(col.withAlphaComponent(appear).cgColor)
        ctx.fillEllipse(in: CGRect(x: 58 + CGFloat(i)*22, y: 42, width: 13, height: 13))
    }
    let tW = textWidth("ClaudeVault", size: 15, weight: .semibold)
    text("ClaudeVault", (W - tW)/2, 40, size: 15, color: tSec, weight: .semibold, alpha: appear)

    // Sidebar
    ctx.setFillColor(sidebar.withAlphaComponent(appear).cgColor)
    ctx.fill(CGRect(x: 36, y: 72, width: 264, height: 654))
    text("PROFILS", 60, 96, size: 11, color: tSec, weight: .semibold, alpha: appear)
    let profiles = ["Business IA", "Voyages", "Écriture"]
    for (i, name) in profiles.enumerated() {
        let y = 120 + CGFloat(i) * 46
        if i == 0 { // sélectionné
            fillRound(ctx, CGRect(x: 50, y: y, width: 236, height: 40), 9, clayTint.withAlphaComponent(appear))
        }
        ctx.setFillColor((i == 0 ? clay : tSec).withAlphaComponent(appear).cgColor)
        ctx.fillEllipse(in: CGRect(x: 66, y: y + 14, width: 12, height: 12))
        text(name, 92, y + 10, size: 14, color: i == 0 ? tPrim : tSec,
             weight: i == 0 ? .semibold : .regular, alpha: appear)
    }
    ctx.setFillColor(c(0,0,0,0.06 * appear).cgColor)
    ctx.fill(CGRect(x: 50, y: 278, width: 236, height: 1))
    text("VAULT", 60, 296, size: 11, color: tSec, weight: .semibold, alpha: appear)
    ctx.setFillColor(clayLight.withAlphaComponent(appear).cgColor)
    ctx.fillEllipse(in: CGRect(x: 66, y: 322, width: 12, height: 12))
    text("Clés API", 92, 318, size: 14, color: tSec, alpha: appear)

    // Zone principale : entête
    let mx: CGFloat = 328
    text("Business IA", mx, 96, size: 20, color: tPrim, weight: .bold, alpha: appear)
    text("mémoire pilotée par Claude via MCP", mx, 126, size: 13, color: tSec, alpha: appear)

    // 1) Bulle utilisateur (droite), typing f8→20
    let uA = smooth(f, 8, 12)
    if uA > 0 {
        let full = "Retiens : Acme signé, MVP le 30/07"
        let shown = reveal(full, smooth(f, 8, 20))
        let bw = max(textWidth(full, size: 15) + 40, 120)
        let bx = 1140 - bw, by: CGFloat = 168
        fillRound(ctx, CGRect(x: bx, y: by, width: bw, height: 46), 14, clay.withAlphaComponent(uA))
        text(shown, bx + 20, by + 13, size: 15, color: .white, alpha: uA)
    }

    // 2) Chip d'appel d'outil (gauche), slide-up f22→30
    let cA = smooth(f, 22, 30)
    if cA > 0 {
        let off = (1 - cA) * 14
        let label = "write_note"
        let arg = "  business-ia / clients/acme.md"
        let cw = textWidth(label, size: 13, weight: .semibold, mono: true)
             + textWidth(arg, size: 13, mono: true) + 62
        let cx = mx, cy = 250 + off
        fillRound(ctx, CGRect(x: cx, y: cy, width: cw, height: 42), 11, chipDark.withAlphaComponent(cA))
        // petite roue
        ctx.setFillColor(clayLight.withAlphaComponent(cA).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx + 16, y: cy + 15, width: 12, height: 12))
        text(label, cx + 38, cy + 12, size: 13, color: .white, weight: .semibold, mono: true, alpha: cA)
        text(arg, cx + 38 + textWidth(label, size: 13, weight: .semibold, mono: true),
             cy + 12, size: 13, color: c(210,210,215), mono: true, alpha: cA)
    }

    // 3) Carte notes/ avec le fichier qui apparaît, f34→42 + check f42
    let nA = smooth(f, 34, 42)
    if nA > 0 {
        let card = CGRect(x: mx, y: 320, width: 500, height: 110)
        fillRound(ctx, card, 12, c(248,247,249).withAlphaComponent(nA))
        text("notes/", mx + 18, 334, size: 12, color: tSec, weight: .semibold, alpha: nA)
        // rangée fichier
        let rowA = smooth(f, 38, 46)
        if rowA > 0 {
            let ry: CGFloat = 366 + (1 - rowA) * 8
            ctx.setFillColor(clay.withAlphaComponent(rowA).cgColor)
            // glyphe doc
            fillRound(ctx, CGRect(x: mx + 20, y: ry, width: 16, height: 20), 3, clayLight.withAlphaComponent(rowA))
            text("clients/acme.md", mx + 46, ry + 1, size: 14, color: tPrim, weight: .medium, alpha: rowA)
            // check vert
            let ck = smooth(f, 44, 50)
            if ck > 0 {
                ctx.setStrokeColor(green.withAlphaComponent(ck).cgColor)
                ctx.setLineWidth(3); ctx.setLineCap(.round)
                let gx = mx + 210, gy = ry + 11
                ctx.beginPath()
                ctx.move(to: CGPoint(x: gx, y: gy))
                ctx.addLine(to: CGPoint(x: gx + 6 * ck, y: gy + 6 * ck))
                ctx.addLine(to: CGPoint(x: gx + 6 * ck + 12 * ck, y: gy - 8 * ck))
                ctx.strokePath()
            }
        }
        // ligne mémoire + compteur de tokens
        let mem = smooth(f, 40, 48)
        if mem > 0 {
            let my: CGFloat = 400
            text("memory.md", mx + 20, my, size: 13, color: tSec, alpha: mem)
            let tok = Int(120 + 22 * smooth(f, 40, 50))
            let tw = "~\(tok) / 5000 tokens"
            text(tw, mx + 130, my, size: 13, color: clay, weight: .semibold, mono: true, alpha: mem)
        }
    }

    // 4) Bulle assistant finale (gauche), typing f48→57 puis hold
    let aA = smooth(f, 46, 50)
    if aA > 0 {
        let full = "Enregistré dans Business IA ✅"
        let shown = reveal(full, smooth(f, 48, 57))
        let bw = max(textWidth(full, size: 15) + 40, 120)
        let by: CGFloat = 452
        fillRound(ctx, CGRect(x: mx, y: by, width: bw, height: 46), 14, c(240,238,236).withAlphaComponent(aA))
        text(shown, mx + 20, by + 13, size: 15, color: tPrim, alpha: aA)
    }

    ctx.restoreGState() // clip fenêtre
    NSGraphicsContext.restoreGraphicsState()
    ctx.restoreGState()
}

func render(_ fi: Int) {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    drawFrame(ctx, fi)
    let img = ctx.makeImage()!
    let path = String(format: "%@/frame_%04d.png", outDir, fi)
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                               UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    _ = CGImageDestinationFinalize(dest)
}

if let s = single {
    render(s); print("frame \(s) rendu")
} else {
    for fi in 0..<TOTAL { render(fi) }
    print("\(TOTAL) frames rendues dans \(outDir)")
}
