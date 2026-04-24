//
//  WidgetsBundle.swift
//  Widgets
//
//  Created by Arturo Carretero Calvo on 23/04/2026.
//  Copyright © 2026 Arturo Carretero Calvo. All rights reserved.
//

import WidgetKit
import SwiftUI

@main
struct WidgetsBundle: WidgetBundle {
    var body: some Widget {
        NewChatControlWidget()
        NewChatWidget()
        SearchWidget()
        QuickActionsWidget()
        ConversationsOverviewWidget()
    }
}
