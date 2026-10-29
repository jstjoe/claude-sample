// Moves the mouse pointer to a point on screen, for example onto the menu bar
// so that it stays out of a screencapture region. It needs no permissions.
//
//   swiftc -O -o warp warp.swift && ./warp 1300 12
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 3, let x = Double(args[1]), let y = Double(args[2]) else {
    print("usage: warp <x> <y>")
    exit(2)
}
CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
