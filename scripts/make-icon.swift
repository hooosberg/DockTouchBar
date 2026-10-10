// 画 1024×1024 的 App 图标母版：深色圆角底 + 一条 Touch Bar，上面几个 App 图标和运行小圆点。
// 用法：swift scripts/make-icon.swift <输出.png>（通常由 scripts/make-icon.sh 调用）
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

// macOS 图标网格：主体 824×824，四周留 100，圆角约 185。
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(bodyPath)
ctx.setFillColor(color(0x15171C))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(bodyPath)
ctx.clip()
let gradient = CGGradient(colorsSpace: space, colors: [color(0x323744), color(0x0D0F13)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.restoreGState()

// Touch Bar 条
let bar = CGRect(x: 172, y: 432, width: 680, height: 160)
let barPath = CGPath(roundedRect: bar, cornerWidth: 36, cornerHeight: 36, transform: nil)
ctx.addPath(barPath)
ctx.setFillColor(color(0x000000))
ctx.fillPath()
ctx.addPath(barPath)
ctx.setStrokeColor(color(0x4A5060))
ctx.setLineWidth(4)
ctx.strokePath()

// 条上的 App 图标：第 1、3 个正在运行（下面有小圆点），第 3 个是前台（圆点更亮）。
let tileColors: [UInt32] = [0x3B82F6, 0x22C55E, 0xF59E0B, 0xEC4899, 0x8B5CF6]
let tileSize: CGFloat = 92
let gap: CGFloat = 34
let totalWidth = CGFloat(tileColors.count) * tileSize + CGFloat(tileColors.count - 1) * gap
var x = bar.midX - totalWidth / 2
let tileY = bar.minY + 44
for (index, hex) in tileColors.enumerated() {
    let tile = CGRect(x: x, y: tileY, width: tileSize, height: tileSize)
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 22, cornerHeight: 22, transform: nil))
    ctx.setFillColor(color(hex))
    ctx.fillPath()
    if index == 0 || index == 2 {
        ctx.setFillColor(color(0xFFFFFF, index == 2 ? 1 : 0.55))
        ctx.fillEllipse(in: CGRect(x: tile.midX - 8, y: bar.minY + 14, width: 16, height: 16))
    }
    x += tileSize + gap
}

// Vibecoding 版标记：右下角一只冒着烟的像素咖啡杯（和 Touch Bar 右侧的咖啡杯按钮同一幅画），和纯净版的图标一眼能分开。
let coffee = [
    "....#...#....",
    "...#...#.....",
    "....#...#....",
    ".............",
    ".#########...",
    ".#.......####",
    ".#########..#",
    ".#########..#",
    ".############",
    "..#######....",
    ".###########.",
]
let cell: CGFloat = 18
let artOrigin = CGPoint(x: 600, y: 150)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -5), blur: 12, color: color(0x000000, 0.6))
ctx.setFillColor(color(0xFFFFFF))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)  // 整幅画一起投影，格子之间不会出现缝
for (row, line) in coffee.enumerated() {
    for (column, ch) in line.enumerated() where ch == "#" {
        ctx.fill(CGRect(x: artOrigin.x + CGFloat(column) * cell,
                        y: artOrigin.y + CGFloat(coffee.count - 1 - row) * cell, width: cell, height: cell))
    }
}
ctx.endTransparencyLayer()
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
