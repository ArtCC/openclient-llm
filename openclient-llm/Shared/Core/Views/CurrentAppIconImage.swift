//
//  CurrentAppIconImage.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 26/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import SwiftUI

struct CurrentAppIconImage: View {
    var body: some View {
#if os(iOS)
        AppIconPreviewImage(icon: AppIconManager().selectedIcon)
#else
        Image("logo")
            .resizable()
            .aspectRatio(1, contentMode: .fit)
#endif
    }
}
