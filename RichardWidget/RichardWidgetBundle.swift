//
//  RichardWidgetBundle.swift
//  RichardWidget
//
//  Created by 채영 on 4/15/26.
//

import WidgetKit
import SwiftUI

@main
struct RichardWidgetBundle: WidgetBundle {
    var body: some Widget {
        RichardWidget()
        RichardWidgetControl()
        RichardWidgetLiveActivity()
    }
}
