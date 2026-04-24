//
//  ShareSheet.swift
//  PourDirection
//
//  Thin SwiftUI wrapper around UIActivityViewController.
//  Used to hand a rendered ShareCardView + caption to the system share sheet.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}
