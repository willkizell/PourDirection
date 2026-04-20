//
//  ParksIconView.swift
//  PourDirection
//
//  Renders the tree/parks icon from SVG path data.
//  viewBox 0 0 24 24 — all coordinates normalised by dividing by 24.
//  Single path: two-layer triangle tree canopy with a rectangular trunk.
//

import SwiftUI

// MARK: - Shape

private struct ParksShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var p = Path()

        // Trunk + double-layer canopy
        // M13.95 22h-3.9v-4H3l4-6H5l7-10l7 10h-2l4 6h-7.05z
        p.move(to: CGPoint(x: 13.95*s, y: 22*s))
        p.addLine(to: CGPoint(x: 10.05*s, y: 22*s))
        p.addLine(to: CGPoint(x: 10.05*s, y: 18*s))
        p.addLine(to: CGPoint(x: 3*s,     y: 18*s))
        p.addLine(to: CGPoint(x: 7*s,     y: 12*s))
        p.addLine(to: CGPoint(x: 5*s,     y: 12*s))
        p.addLine(to: CGPoint(x: 12*s,    y: 2*s))
        p.addLine(to: CGPoint(x: 19*s,    y: 12*s))
        p.addLine(to: CGPoint(x: 17*s,    y: 12*s))
        p.addLine(to: CGPoint(x: 21*s,    y: 18*s))
        p.addLine(to: CGPoint(x: 13.95*s, y: 18*s))
        p.closeSubpath()

        return p
    }
}

// MARK: - View

struct ParksIconView: View {
    var color: Color = .primary

    var body: some View {
        ParksShape()
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        ParksIconView(color: AppColors.parksGreen)
            .frame(width: 28, height: 28)
        ParksIconView(color: AppColors.parksGreen)
            .frame(width: 48, height: 48)
    }
    .padding()
    .background(Color.black)
}
