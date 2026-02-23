//
//  EditProfileView.swift
//  PourDirection
//
//  Edit Profile screen — editable fields for name, gender, birthday, email,
//  and default city. All data is mock for now. Save delegates to parent via closure.
//

import SwiftUI

struct EditProfileView: View {

    @State private var fullName: String     = "William Kizell"
    @State private var gender: String       = "Male"
    @State private var birthday: String     = "09-22-2003"
    @State private var email: String        = "wkizell@gmail.com"
    @State private var defaultCity: String  = "Vancouver, BC"
    @State private var showCityPicker       = false

    let onBack: () -> Void

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Fixed Header with back button ────────────────────────────
                HStack(spacing: AppSpacing.sm) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColors.secondary)
                    }
                    .buttonStyle(.plain)

                    (Text("Edit")
                        .foregroundColor(AppColors.primary)
                     + Text("Profile")
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

                        // ── Avatar ───────────────────────────────────────────
                        VStack(spacing: AppSpacing.xs) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 72))
                                .foregroundColor(AppColors.secondary.opacity(0.5))

                            Text(fullName)
                                .font(AppTypography.header)
                                .foregroundColor(AppColors.secondary)
                        }
                        .padding(.top, AppSpacing.md)
                        .padding(.bottom, AppSpacing.lg)

                        // ── Form Fields ──────────────────────────────────────
                        VStack(spacing: AppSpacing.sm) {

                            ProfileTextField(label: "Full Name", text: $fullName)

                            // Gender + Birthday side by side
                            HStack(spacing: AppSpacing.sm) {
                                ProfileTextField(label: "Gender", text: $gender)
                                ProfileTextField(label: "Birthday", text: $birthday)
                            }

                            ProfileTextField(label: "Email", text: $email, keyboardType: .emailAddress)
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                        // ── Default City ─────────────────────────────────────
                        HStack {
                            Image(systemName: "building.2")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.primary)
                            Text("Default City")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.4))
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.top, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xs)

                        HStack {
                            Text(defaultCity)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.secondary)
                            Spacer()
                            Button("Change") { showCityPicker = true }
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.primary)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.cardSurface.opacity(0.8))
                        .cornerRadius(AppRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.sm)
                                .stroke(AppColors.secondary.opacity(0.08), lineWidth: 0.5)
                        )
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                        // ── Save Button ──────────────────────────────────────
                        PrimaryButton(title: "Save") {
                            // Future phase — persist to backend
                            onBack()
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.top, AppSpacing.xl)

                        Spacer().frame(height: AppSpacing.xxxl)
                    }
                }
            }
        }
        .sheet(isPresented: $showCityPicker) {
            ChangeCitySheet(selectedCity: $defaultCity)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Profile Text Field

/// Styled text field matching the Edit Profile mockup.
/// Dark surface background with floating label above the value.
struct ProfileTextField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary.opacity(0.4))

            TextField("", text: $text)
                .font(AppTypography.body)
                .foregroundColor(AppColors.secondary)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.cardSurface.opacity(0.8))
        .cornerRadius(AppRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.sm)
                .stroke(AppColors.secondary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Change City Sheet

/// Bottom-up city picker presented as a sheet from EditProfileView.
struct ChangeCitySheet: View {

    @Binding var selectedCity: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private let popularCities = [
        "Vancouver, BC",
        "New York, NY",
        "Los Angeles, CA",
        "Miami, FL",
        "Chicago, IL",
        "Austin, TX",
        "Nashville, TN",
        "San Francisco, CA",
        "Seattle, WA",
        "Denver, CO",
        "Toronto, ON",
        "Montreal, QC",
    ]

    private var filteredCities: [String] {
        if searchText.isEmpty { return popularCities }
        return popularCities.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────
                (Text("Change ")
                    .foregroundColor(AppColors.primary)
                 + Text("City")
                    .foregroundColor(AppColors.secondary))
                    .font(AppTypography.titleMedium)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.md)

                // ── Search Bar ────────────────────────────────────────────
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.secondary.opacity(0.4))
                    TextField("Search cities...", text: $searchText)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.secondary)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.cardSurface.opacity(0.8))
                .cornerRadius(AppRadius.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .stroke(AppColors.secondary.opacity(0.08), lineWidth: 0.5)
                )
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                // ── Section Label ─────────────────────────────────────────
                HStack {
                    Text(searchText.isEmpty ? "Popular Cities" : "Results")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.4))
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xs)

                // ── City List ─────────────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.xxs) {
                        ForEach(filteredCities, id: \.self) { city in
                            Button {
                                selectedCity = city
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "building.2")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.primary)
                                        .frame(width: 24, alignment: .center)
                                    Text(city)
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.secondary)
                                    Spacer()
                                    if city == selectedCity {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(AppColors.cardSurface.opacity(0.6))
                                .cornerRadius(AppRadius.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.bottom, AppSpacing.xxxl)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    EditProfileView(onBack: {})
        .preferredColorScheme(.dark)
}
