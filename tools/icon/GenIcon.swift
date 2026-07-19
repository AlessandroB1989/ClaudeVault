import AppKit
import CoreGraphics
import Foundation
import UniformTypeIdentifiers

// Génère l'icône ClaudeVault au vecteur (CoreGraphics), nette à chaque taille.
// Usage: swift GenIcon.swift <dossier_de_sortie>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

// Palette argile/corail (marque Anthropic).
let clayLight = rgb(233, 152, 112)   // corail clair
let clayDeep  = rgb(184, 84, 52)     // terracotta profond
let nodeColor = rgb(168, 72, 44)     // nœuds/liens (corail sombre)
let white     = rgb(255, 255, 255)

func roundedRectPath(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Dessine l'icône dans un espace 1024×1024 (origine bas-gauche), échelle s = size/1024.
func drawIcon(_ ctx: CGContext, size: CGFloat) {
    let s = size / 1024.0
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x*s, y: y*s) }
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x*s, y: y*s, width: w*s, height: h*s)
    }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Tuile squircle (grille macOS : 824 dans 1024).
    let tile = R(100, 96, 824, 824)
    let tilePath = roundedRectPath(tile, 185*s)

    // Ombre de contact douce.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10*s), blur: 18*s,
                  color: rgb(50, 18, 10, 0.14))
    ctx.addPath(tilePath)
    ctx.setFillColor(clayDeep)
    ctx.fillPath()
    ctx.restoreGState()

    // Dégradé diagonal.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let colors = [clayLight, clayDeep] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: P(180, 900), end: P(880, 150), options: [])

    // Halo doux en haut.
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [rgb(255,255,255,0.28), rgb(255,255,255,0)] as CFArray,
                          locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: P(512, 820), startRadius: 0,
                           endCenter: P(512, 820), endRadius: 520*s, options: [])
    ctx.restoreGState()

    // --- Cadenas blanc ---
    // Anse dessinée EN PREMIER (le corps la recouvre) → silhouette nette.
    // U ouvert vers le bas : arche haute et étroite bien au-dessus du corps.
    // Les pieds de l'anse doivent tomber dans la zone PLATE du haut du corps
    // (à l'intérieur des coins arrondis) sinon un coin de fond apparaît.
    ctx.saveGState()
    ctx.setStrokeColor(white)
    ctx.setLineWidth(52*s)
    ctx.setLineCap(.round)
    let cx: CGFloat = 512
    let legDx: CGFloat = 76         // anse étroite mais équilibrée → cadenas
    let legBottom: CGFloat = 545    // tucké sous le haut du corps (585)
    let arcCenterY: CGFloat = 705   // arche haute et étroite
    let shackle = CGMutablePath()
    shackle.move(to: P(cx - legDx, legBottom))
    shackle.addLine(to: P(cx - legDx, arcCenterY))
    shackle.addArc(center: P(cx, arcCenterY), radius: legDx*s,
                   startAngle: .pi, endAngle: 0, clockwise: false)
    shackle.addLine(to: P(cx + legDx, legBottom))
    ctx.addPath(shackle)
    ctx.strokePath()
    ctx.restoreGState()

    // Corps du cadenas (rectangle arrondi blanc), coins modérés → grande zone plate.
    let body = R(332, 285, 360, 300)   // x 332..692, y 285..585
    ctx.setFillColor(white)
    ctx.addPath(roundedRectPath(body, 54*s))
    ctx.fillPath()

    // Graphe mémoire à 3 nœuds dans le corps (corail), centré.
    let nodes = [P(438, 470), P(586, 470), P(512, 365)]
    ctx.setStrokeColor(nodeColor)
    ctx.setLineWidth(16*s)
    ctx.setLineCap(.round)
    let edges = CGMutablePath()
    edges.move(to: nodes[0]); edges.addLine(to: nodes[1])
    edges.move(to: nodes[0]); edges.addLine(to: nodes[2])
    edges.move(to: nodes[1]); edges.addLine(to: nodes[2])
    ctx.addPath(edges)
    ctx.strokePath()

    ctx.setFillColor(nodeColor)
    for n in nodes {
        let rr = 30*s
        ctx.addEllipse(in: CGRect(x: n.x - rr, y: n.y - rr, width: rr*2, height: rr*2))
    }
    ctx.fillPath()
}

func renderPNG(size: Int, to path: String) throws {
    let px = size
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                              bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "icon", code: 1)
    }
    drawIcon(ctx, size: CGFloat(px))
    guard let img = ctx.makeImage() else { throw NSError(domain: "icon", code: 2) }
    let url = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "icon", code: 3)
    }
    CGImageDestinationAddImage(dest, img, nil)
    if !CGImageDestinationFinalize(dest) { throw NSError(domain: "icon", code: 4) }
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
for sz in sizes {
    let p = "\(outDir)/icon_\(sz).png"
    try renderPNG(size: sz, to: p)
    print("écrit \(p)")
}
print("OK")
