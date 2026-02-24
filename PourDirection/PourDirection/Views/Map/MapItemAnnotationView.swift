//
//  MapPinView.swift
//  PourDirection
//
//  Reusable map annotation pin. Black fill, category-accent border + icon.
//  Closed places render at reduced opacity and saturation.
//

import SwiftUI

// MARK: - Pin Tail Shape

/// Downward-pointing triangle (apex at bottom, base at top).
private struct PinTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX,  y: rect.maxY)) // apex
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - MapPinView

struct MapPinView: View {

    let category: PlaceCategory
    let isClosed: Bool

    private var pinColor: Color { category.color }

    private var iconName: String {
        switch category {
        case .bar:        return "wineglass"
        case .restaurant: return "fork.knife"
        case .club:       return "music.note"
        case .dispensary: return "leaf"
        }
    }

    var body: some View {
        ZStack {
            // Triangle tail — drawn first so the circle sits on top of it
            ZStack {
                PinTail().fill(Color.black)
                PinTail().stroke(pinColor, lineWidth: 1.5)
            }
            .frame(width: 13, height: 9)
            .offset(y: 21)

            // Circle body — black fill with accent border
            Circle()
                .fill(Color.black)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(pinColor, lineWidth: 1.5))

            // Category icon in accent color
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(pinColor)
        }
        .opacity(isClosed ? 0.50 : 1.0)
        .saturation(isClosed ? 0.3 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 32) {
            HStack(spacing: 28) {
                MapPinView(category: .bar,        isClosed: false)
                MapPinView(category: .restaurant, isClosed: false)
                MapPinView(category: .club,       isClosed: false)
                MapPinView(category: .dispensary, isClosed: false)
            }
            HStack(spacing: 28) {
                MapPinView(category: .bar,        isClosed: true)
                MapPinView(category: .restaurant, isClosed: true)
                MapPinView(category: .club,       isClosed: true)
                MapPinView(category: .dispensary, isClosed: true)
            }
        }
    }
}
