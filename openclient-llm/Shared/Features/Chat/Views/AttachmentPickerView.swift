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
    let onAttachment: (ChatMessage.Attachment) -> Void

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
                        let attachment = ChatMessage.Attachment(
                            type: .image,
                            fileName: fileName,
                            data: data
                        )
                        onAttachment(attachment)
                    }
                    selectedItem = nil
                }
            }
    }
}

struct DocumentPickerModifier: ViewModifier {
    // MARK: - Properties

    @Binding var isPresented: Bool
    let onAttachment: (ChatMessage.Attachment) -> Void

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
                        let attachment = ChatMessage.Attachment(
                            type: .pdf,
                            fileName: url.lastPathComponent,
                            data: data
                        )
                        onAttachment(attachment)
                    }
                case .failure:
                    break
                }
            }
    }
}

extension View {
    func imagePicker(
        isPresented: Binding<Bool>,
        onAttachment: @escaping (ChatMessage.Attachment) -> Void
    ) -> some View {
        modifier(ImagePickerModifier(isPresented: isPresented, onAttachment: onAttachment))
    }

    func documentPicker(
        isPresented: Binding<Bool>,
        onAttachment: @escaping (ChatMessage.Attachment) -> Void
    ) -> some View {
        modifier(DocumentPickerModifier(isPresented: isPresented, onAttachment: onAttachment))
    }
}
