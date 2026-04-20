//
//  PatioIconView.swift
//  PourDirection
//
//  Renders the patio heater icon from SVG path data.
//  viewBox 0 0 24 24 — all coordinates normalised by dividing by 24.
//  Five subpaths: base, reflector cap, collar ring, body, band.
//  Bezier curves (< 1pt at 28pt size) approximated with straight lines.
//

import SwiftUI

// MARK: - Shape

private struct PatioShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var p = Path()

        // Subpath 1: base bar at bottom
        p.move(to: CGPoint(x: 15*s, y: 22*s))
        p.addLine(to: CGPoint(x: 9*s,  y: 22*s))
        p.addLine(to: CGPoint(x: 9*s,  y: 21*s))
        p.addLine(to: CGPoint(x: 15*s, y: 21*s))
        p.closeSubpath()

        // Subpath 2: reflector cap (trapezoidal top)
        p.move(to: CGPoint(x: 19*s, y: 4*s))
        p.addLine(to: CGPoint(x: 15*s, y: 2*s))
        p.addLine(to: CGPoint(x: 9*s,  y: 2*s))
        p.addLine(to: CGPoint(x: 5*s,  y: 4*s))
        p.closeSubpath()

        // Subpath 3: collar ring (y 5–6)
        p.move(to: CGPoint(x: 8*s,   y: 5*s))
        p.addLine(to: CGPoint(x: 8.4*s,  y: 6*s))
        p.addLine(to: CGPoint(x: 15.6*s, y: 6*s))
        p.addLine(to: CGPoint(x: 16*s,   y: 5*s))
        p.closeSubpath()

        // Subpath 4: body / pole (curves approximated as lines)
        p.move(to: CGPoint(x: 10*s,   y: 10*s))
        p.addLine(to: CGPoint(x: 11*s,  y: 10*s))
        p.addLine(to: CGPoint(x: 11*s,  y: 15*s))
        p.addLine(to: CGPoint(x: 10*s,  y: 16*s))   // approx cubic bezier
        p.addLine(to: CGPoint(x: 10*s,  y: 20*s))
        p.addLine(to: CGPoint(x: 14*s,  y: 20*s))
        p.addLine(to: CGPoint(x: 14*s,  y: 16*s))
        p.addLine(to: CGPoint(x: 13*s,  y: 15*s))   // approx cubic bezier
        p.addLine(to: CGPoint(x: 13*s,  y: 10*s))
        p.addLine(to: CGPoint(x: 14*s,  y: 10*s))
        p.addLine(to: CGPoint(x: 14.4*s, y: 9*s))
        p.addLine(to: CGPoint(x: 9.6*s,  y: 9*s))
        p.closeSubpath()

        // Subpath 5: band (y 7–8)
        p.move(to: CGPoint(x: 9.2*s,  y: 8*s))
        p.addLine(to: CGPoint(x: 14.8*s, y: 8*s))
        p.addLine(to: CGPoint(x: 15.2*s, y: 7*s))
        p.addLine(to: CGPoint(x: 8.8*s,  y: 7*s))
        p.closeSubpath()

        return p
    }
}

// MARK: - View

struct PatioIconView: View {
    var color: Color = .primary

    var body: some View {
        PatioShape()
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        PatioIconView(color: AppColors.primary)
            .frame(width: 28, height: 28)
        PatioIconView(color: AppColors.primary)
            .frame(width: 48, height: 48)
    }
    .padding()
    .background(Color.black)
}
