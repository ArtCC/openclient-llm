//
//  ImagePreviewView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 01/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Helper

struct ExpandedImage: Identifiable {
    let id = UUID()
    let data: Data
}

// MARK: - View

struct ImagePreviewView: View {
    // MARK: - Properties

    let data: Data

    @Environment(\.dismiss) private var dismiss

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                #if os(iOS)
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(edges: .bottom)
                }
                #elseif os(macOS)
                if let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                #endif
            }
            .navigationTitle(String(localized: "Generated Image"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(String(localized: "Close"))
                }

                ToolbarItem(placement: .primaryAction) {
                    saveButton
                }
            }
        }
    }
}

// MARK: - Private

private extension ImagePreviewView {
    var saveButton: some View {
        #if os(iOS)
        Button {
            saveImageToPhotos(data)
        } label: {
            Label(String(localized: "Save to Photos"), systemImage: "square.and.arrow.down")
        }
        #elseif os(macOS)
        Button {
            saveImageToDownloads(data)
        } label: {
            Label(String(localized: "Save to Downloads"), systemImage: "square.and.arrow.down")
        }
        #endif
    }

    #if os(iOS)
    func saveImageToPhotos(_ imageData: Data) {
        guard let image = UIImage(data: imageData) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    #elseif os(macOS)
    func saveImageToDownloads(_ imageData: Data) {
        let timestamp = Int(Date().timeIntervalSince1970)
        guard let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("generated-image-\(timestamp).png") else { return }
        try? imageData.write(to: url)
    }
    #endif
}

#Preview {
    ImagePreviewView(data: Data())
}
