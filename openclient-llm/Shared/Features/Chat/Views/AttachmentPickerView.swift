//
//  AttachmentPickerView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ImagePickerModifier: ViewModifier {
    // MARK: - Properties

    @Binding var isPresented: Bool
    let onAttachmentData: (Data, String, ChatMessage.AttachmentType) -> Void

    @State private var selectedItem: PhotosPickerItem?

    // MARK: - View

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: $isPresented,
                selection: $selectedItem,
                matching: .images
            )
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        let fileName = "photo_\(Date().timeIntervalSince1970).jpg"
                        onAttachmentData(data, fileName, .image)
                    }
                    selectedItem = nil
                }
            }
    }
}

struct DocumentPickerModifier: ViewModifier {
    // MARK: - Properties

    @Binding var isPresented: Bool
    let onAttachmentData: (Data, String, ChatMessage.AttachmentType) -> Void

    // MARK: - View

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let gotAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if gotAccess { url.stopAccessingSecurityScopedResource() }
                    }
                    if let data = try? Data(contentsOf: url) {
                        onAttachmentData(data, url.lastPathComponent, .pdf)
                    }
                case .failure:
                    break
                }
            }
    }
}

#if os(macOS)
struct ImageFilePickerModifier: ViewModifier {
    // MARK: - Properties

    @Binding var isPresented: Bool
    let onAttachmentData: (Data, String, ChatMessage.AttachmentType) -> Void

    // MARK: - View

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let gotAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if gotAccess { url.stopAccessingSecurityScopedResource() }
                    }
                    if let data = try? Data(contentsOf: url) {
                        onAttachmentData(data, url.lastPathComponent, .image)
                    }
                case .failure:
                    break
                }
            }
    }
}
#endif

extension View {
    func imagePicker(
        isPresented: Binding<Bool>,
        onAttachmentData: @escaping (Data, String, ChatMessage.AttachmentType) -> Void
    ) -> some View {
        modifier(ImagePickerModifier(isPresented: isPresented, onAttachmentData: onAttachmentData))
    }

    func documentPicker(
        isPresented: Binding<Bool>,
        onAttachmentData: @escaping (Data, String, ChatMessage.AttachmentType) -> Void
    ) -> some View {
        modifier(DocumentPickerModifier(isPresented: isPresented, onAttachmentData: onAttachmentData))
    }

#if os(macOS)
    func imageFilePicker(
        isPresented: Binding<Bool>,
        onAttachmentData: @escaping (Data, String, ChatMessage.AttachmentType) -> Void
    ) -> some View {
        modifier(ImageFilePickerModifier(isPresented: isPresented, onAttachmentData: onAttachmentData))
    }
#endif
}
