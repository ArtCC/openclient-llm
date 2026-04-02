//
//  Font.swift
//  openclient-llm
//
//  Created by Arturo Carretero Calvo on 29/03/2026.
//  Copyright © 2026 ArtCC. All rights reserved.
//

import SwiftUI

extension Font {
    static func poppins(_ style: PoppinsFont, size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        Font.custom(style.rawValue, size: size, relativeTo: textStyle)
    }
}
