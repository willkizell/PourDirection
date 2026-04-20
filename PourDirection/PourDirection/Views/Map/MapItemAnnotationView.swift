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
    private var pinFill:  Color { AppColors.background }

    private var iconName: String {
        switch category {
        case .bar:         return "wineglass"
        case .restaurant:  return "fork.knife"
        case .club:        return "music.note"
        case .dispensary:  return "leaf"
        case .liquorStore: return "cart"
        case .casino:      return "suit.spade.fill"
        case .patio:       return ""
        case .brunch:      return "fork.knife.circle"
        case .coffee:      return "cup.and.saucer.fill"
        case .dayDrinks:   return "wineglass"
        case .parks:       return ""
        case .dessert:     return "birthday.cake"
        }
    }

    var body: some View {
        ZStack {
            // Triangle tail — drawn first so the circle sits on top of it
            ZStack {
                PinTail().fill(pinFill)
                PinTail().stroke(pinColor, lineWidth: 1.5)
            }
            .frame(width: 13, height: 9)
            .offset(y: 21)

            // Circle body — adaptive fill with accent border
            Circle()
                .fill(pinFill)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(pinColor, lineWidth: 2))
                .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1)

            // Category icon in accent color
            if category == .patio {
                PatioIconView(color: pinColor).frame(width: 16, height: 16)
            } else if category == .parks {
                ParksIconView(color: pinColor).frame(width: 16, height: 16)
            } else {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(pinColor)
            }
        }
        .opacity(isClosed ? 0.50 : 1.0)
        .saturation(isClosed ? 0.3 : 1.0)
    }
}

// MARK: - Home Pin View

/// Inverted-color pin for the home annotation on the map.
/// Brand primary fill + dark house icon (opposite of category pins).
struct HomePinView: View {

    var body: some View {
        ZStack {
            ZStack {
                PinTail().fill(AppColors.primary)
                PinTail().stroke(AppColors.primary.opacity(0.5), lineWidth: 1.5)
            }
            .frame(width: 13, height: 9)
            .offset(y: 21)

            Circle()
                .fill(AppColors.primary)
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(AppColors.primary.opacity(0.4), lineWidth: 1.5))

            Image(systemName: "house.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.background)
        }
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
