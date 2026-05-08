import ActivityKit
import WidgetKit
import SwiftUI

struct RichardWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RichardActivityAttributes.self) { context in
            // 잠금화면 (Lock Screen) UI
            HStack {
                Image(context.state.currentFrameImageName)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading) {
                    Text(context.state.stateLabel).bold()
                    Text(context.state.shortText).font(.caption).foregroundColor(.gray)
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color.cyan.opacity(0.2))
            
        } dynamicIsland: { context in
            DynamicIsland {
                // 확장되었을 때 (Expanded) UI
                DynamicIslandExpandedRegion(.leading) {
                    Image(context.state.currentFrameImageName)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 44, height: 44)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.shortText)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.stateLabel).font(.headline)
                }
            } compactLeading: {
                Image(context.state.currentFrameImageName)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                Text(context.state.shortText)
            } minimal: {
                Image(context.state.currentFrameImageName)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 18, height: 18)
            }
        }
    }
}
