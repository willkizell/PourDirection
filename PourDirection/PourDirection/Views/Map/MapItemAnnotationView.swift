//
//  MapItemAnnotationView.swift
//  PourDirection
//
//  Custom map pin annotation. Shows a category-specific SF Symbol
//  inside a teal-branded circle with a pointed tail.
//

import SwiftUI

struct MapItemAnnotationView: View {

    let category: PlaceCategory
    let isSelected: Bool

    private var iconName: String {
        switch category {
        case .bar:         return "wineglass.fill"
        case .club:        return "music.note"
        case .liquorStore: return "basket.fill"
        case .event:       return "star.fill"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pin head
            ZStack {
                Circle()
                    .fill(isSelected ? AppColors.primary : AppColors.cardSurface)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(AppColors.primary, lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(
                        color: AppColors.primary.opacity(isSelected ? 0.5 : 0.2),
                        radius: isSelected ? 8 : 4
                    )

                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? AppColors.secondary : AppColors.primary)
            }

            // Pin tail
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(isSelected ? AppColors.primary : AppColors.cardSurface)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 24) {
            MapItemAnnotationView(category: .bar, isSelected: false)
            MapItemAnnotationView(category: .club, isSelected: true)
            MapItemAnnotationView(category: .event, isSelected: false)
            MapItemAnnotationView(category: .liquorStore, isSelected: false)
        }
    }
}
