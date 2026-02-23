//
//  HelpView.swift
//  PourDirection
//
//  Help & Support screen — FAQ accordion + contact/feedback options.
//  Pushed from ProfileView. Back navigation via closure.
//

import SwiftUI

// MARK: - FAQ Item

struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

// MARK: - Help View

struct HelpView: View {

    let onBack: () -> Void

    @State private var expandedID: UUID? = nil

    private let faqs: [FAQItem] = [
        FAQItem(
            question: "What is PourDirection?",
            answer: "PourDirection helps you find the best bars, events, and nightlife near you. Just tell us what vibe you're after and we'll point you in the right direction."
        ),
        FAQItem(
            question: "How does the compass work?",
            answer: "Once you pick a spot and tap \"Let's Go!\", the compass activates and guides you toward your destination. It works using your phone's location services."
        ),
        FAQItem(
            question: "What is PourPro?",
            answer: "PourPro is our premium membership ($9.99/year) that removes all ads and gives you unlimited suggestions. You can upgrade anytime from your Profile."
        ),
        FAQItem(
            question: "How do I save a place?",
            answer: "Tap the heart icon on any suggestion card to save it. You can view all your saved spots in the Saved tab."
        ),
        FAQItem(
            question: "Can I change my default city?",
            answer: "Yes! Go to Edit Profile and scroll down to the Default City section. Tap \"Change\" to pick a new city."
        ),
        FAQItem(
            question: "How do I report a problem?",
            answer: "Tap \"Contact Support\" below to send us an email. We read every message and typically respond within 24 hours."
        ),
    ]

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Fixed Header ─────────────────────────────────────────────
                HStack(spacing: AppSpacing.sm) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColors.secondary)
                    }
                    .buttonStyle(.plain)

                    (Text("Help ")
                        .foregroundColor(AppColors.primary)
                     + Text("& Support")
                        .foregroundColor(AppColors.secondary))
                        .font(AppTypography.titleSmall)

                    Spacer()
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)
                .background(AppColors.background.ignoresSafeArea(edges: .top))

                // ── Scrollable Content ───────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── FAQ Section Header ───────────────────────────────
                        HStack {
                            Text("Frequently Asked Questions")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.4))
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xs)

                        // ── FAQ List ─────────────────────────────────────────
                        VStack(spacing: AppSpacing.xs) {
                            ForEach(faqs) { faq in
                                FAQRow(
                                    item: faq,
                                    isExpanded: expandedID == faq.id,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedID = expandedID == faq.id ? nil : faq.id
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                        // ── Contact Section ──────────────────────────────────
                        HStack {
                            Text("Still need help?")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.4))
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.top, AppSpacing.xl)
                        .padding(.bottom, AppSpacing.xs)

                        VStack(spacing: AppSpacing.xs) {
                            contactRow(
                                icon: "envelope",
                                title: "Contact Support",
                                subtitle: "support@pourdirection.com"
                            )
                            contactRow(
                                icon: "bubble.left",
                                title: "Send Feedback",
                                subtitle: "Help us improve the app"
                            )
                            contactRow(
                                icon: "star",
                                title: "Rate PourDirection",
                                subtitle: "Leave a review on the App Store"
                            )
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                        // ── Version ──────────────────────────────────────────
                        Text("PourDirection v1.0.0")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.2))
                            .padding(.top, AppSpacing.xl)

                        Spacer().frame(height: AppSpacing.xxxl)
                    }
                }
            }
        }
    }

    // ── Contact Row ──────────────────────────────────────────────────────
    private func contactRow(icon: String, title: String, subtitle: String) -> some View {
        Button {
            // Future phase — deep links to mail, App Store, etc.
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.secondary)
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.4))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.secondary.opacity(0.3))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.cardSurface.opacity(0.85))
            .cornerRadius(AppRadius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FAQ Row

private struct FAQRow: View {
    let item: FAQItem
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(item.question)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.secondary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.secondary.opacity(0.3))
                }

                if isExpanded {
                    Text(item.answer)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.6))
                        .padding(.top, AppSpacing.xs)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.cardSurface.opacity(0.85))
            .cornerRadius(AppRadius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HelpView(onBack: {})
        .preferredColorScheme(.dark)
}
