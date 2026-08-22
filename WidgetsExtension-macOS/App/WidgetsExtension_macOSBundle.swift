//
//  WidgetsExtension_macOSBundle.swift
//  WidgetsExtension-macOS
//
//  Created by Arturo Carretero Calvo on 22/08/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import WidgetKit
import SwiftUI

// swiftlint:disable all
@main
struct WidgetsExtension_macOSBundle: WidgetBundle {
    var body: some Widget {
        WidgetsExtension_macOS()
        WidgetsExtension_macOSControl()
    }
}
// swiftlint:enable all
