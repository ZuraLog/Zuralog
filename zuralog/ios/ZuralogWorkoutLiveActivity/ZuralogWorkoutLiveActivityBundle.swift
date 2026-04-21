import WidgetKit
import SwiftUI

@main
struct ZuralogWorkoutLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.1, *) {
            ZuralogWorkoutLiveActivity()
        }
    }
}
