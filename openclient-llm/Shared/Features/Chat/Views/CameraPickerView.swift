//
//  CameraPickerView.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 31/03/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

#if os(iOS)
import SwiftUI
import UIKit

struct CameraPickerView: UIViewControllerRepresentable {
    // MARK: - Properties

    @Binding var isPresented: Bool

    let onAttachment: (ChatMessage.Attachment) -> Void

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
}

// MARK: - Coordinator

extension CameraPickerView {
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        // MARK: - Properties

        private let parent: CameraPickerView

        // MARK: - Init

        init(parent: CameraPickerView) {
            self.parent = parent
        }

        // MARK: - UIImagePickerControllerDelegate

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                let fileName = "camera_\(Date().timeIntervalSince1970).jpg"
                let attachment = ChatMessage.Attachment(
                    type: .image,
                    fileName: fileName,
                    data: data
                )
                parent.onAttachment(attachment)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - View Modifier

struct CameraPickerModifier: ViewModifier {
    // MARK: - Properties

    @Binding var isPresented: Bool

    let onAttachment: (ChatMessage.Attachment) -> Void

    // MARK: - View

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                CameraPickerView(isPresented: $isPresented, onAttachment: onAttachment)
                    .ignoresSafeArea()
            }
    }
}

extension View {
    func cameraPicker(
        isPresented: Binding<Bool>,
        onAttachment: @escaping (ChatMessage.Attachment) -> Void
    ) -> some View {
        modifier(CameraPickerModifier(isPresented: isPresented, onAttachment: onAttachment))
    }
}
#endif
