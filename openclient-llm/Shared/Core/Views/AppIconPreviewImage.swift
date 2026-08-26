//
//  AppIconPreviewImage.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 26/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

#if os(iOS)
import SwiftUI
import UIKit

struct AppIconPreviewImage: View {
    let icon: AppIcon

    var body: some View {
        Group {
            if let image = AppIconPreviewLoader.image(for: icon) {
                Image(uiImage: image)
                    .resizable()
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private enum AppIconPreviewLoader {
    static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 8
        return cache
    }()

    static func image(for icon: AppIcon) -> UIImage? {
        let key = icon.rawValue as NSString
        if let cachedImage = cache.object(forKey: key) {
            return cachedImage
        }
        guard let url = Bundle.main.url(forResource: icon.rawValue, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
#endif
