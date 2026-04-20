//
//  CasinoIconView.swift
//  PourDirection
//
//  Renders the casino icon from SVG path data.
//  viewBox 0 0 512 512 — all coordinates normalised by dividing by 512.
//  Path 1 (3 sub-paths) draws the overlapping card outlines (nonZero fill creates holes).
//  Path 2 draws the solid marks (squares + parallelograms) on each card face.
//

import SwiftUI

// MARK: - Shape

private struct CasinoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 512
        return buildPath(scale: s)
    }

    private func pt(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat) -> CGPoint {
        CGPoint(x: x * s, y: y * s)
    }

    private func buildPath(scale s: CGFloat) -> Path {
        var p = Path()

        // ── Path 1, Sub-path 1: outer combined boundary (CCW in screen) ─────────
        // Arcs replaced with straight lines — radius ≈ 32/512 ≈ 1.75 pt at 28 pt
        p.move(to: pt(495.24, 267.592, s))
        p.addLine(to: pt(445.066, 41.083, s))
        p.addLine(to: pt(406.9, 16.76, s))
        p.addLine(to: pt(180.393, 66.934, s))
        p.addLine(to: pt(156.071, 105.1, s))
        p.addLine(to: pt(177.092, 200, s))
        p.addLine(to: pt(48, 200, s))
        p.addLine(to: pt(16, 232, s))
        p.addLine(to: pt(16, 464, s))
        p.addLine(to: pt(48, 496, s))
        p.addLine(to: pt(280, 496, s))
        p.addLine(to: pt(312, 464, s))
        p.addLine(to: pt(312, 340.957, s))
        p.addLine(to: pt(470.917, 305.757, s))
        p.closeSubpath()

        // ── Path 1, Sub-path 2: bottom-left card inner region (CW → hole) ───────
        p.move(to: pt(280, 464, s))
        p.addLine(to: pt(48, 464, s))
        p.addLine(to: pt(48, 232, s))
        p.addLine(to: pt(184.181, 232, s))
        p.addLine(to: pt(206.244, 331.606, s))
        p.addLine(to: pt(244.408, 355.929, s))
        p.addLine(to: pt(280.008, 348.043, s))
        p.closeSubpath()

        // ── Path 1, Sub-path 3: rotated card inner region (CW → hole) ───────────
        p.move(to: pt(464, 274.513, s))
        p.addLine(to: pt(237.487, 324.686, s))
        p.addLine(to: pt(187.314, 98.176, s))
        p.addLine(to: pt(413.824, 48, s))
        p.closeSubpath()

        // ── Path 2: solid detail marks ───────────────────────────────────────────
        // Four squares on bottom-left card
        p.addRect(CGRect(x: 80*s, y: 264*s, width: 40*s, height: 40*s))
        p.addRect(CGRect(x: 80*s, y: 392*s, width: 40*s, height: 40*s))
        p.addRect(CGRect(x: 208*s, y: 392*s, width: 40*s, height: 40*s))
        p.addRect(CGRect(x: 144*s, y: 328*s, width: 40*s, height: 40*s))

        // Three parallelograms on rotated card
        p.move(to: pt(225.456, 122.567, s))
        p.addLine(to: pt(264.51, 113.923, s))
        p.addLine(to: pt(273.154, 152.978, s))
        p.addLine(to: pt(234.1, 161.622, s))
        p.closeSubpath()

        p.move(to: pt(378.128, 219.79, s))
        p.addLine(to: pt(417.182, 211.14, s))
        p.addLine(to: pt(425.832, 250.194, s))
        p.addLine(to: pt(386.778, 258.844, s))
        p.closeSubpath()

        p.move(to: pt(301.804, 171.141, s))
        p.addLine(to: pt(340.857, 162.491, s))
        p.addLine(to: pt(349.507, 201.544, s))
        p.addLine(to: pt(310.455, 210.194, s))
        p.closeSubpath()

        return p
    }
}

// MARK: - View

struct CasinoIconView: View {
    var color: Color = .primary

    var body: some View {
        CasinoShape()
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        CasinoIconView(color: AppColors.casinoGold)
            .frame(width: 28, height: 28)
        CasinoIconView(color: AppColors.casinoGold)
            .frame(width: 48, height: 48)
        CasinoIconView(color: .white)
            .frame(width: 64, height: 64)
    }
    .padding()
    .background(Color.black)
}
