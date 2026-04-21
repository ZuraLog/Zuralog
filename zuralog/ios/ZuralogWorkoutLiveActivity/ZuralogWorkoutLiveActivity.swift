import ActivityKit
import SwiftUI
import WidgetKit

/// MUST be kept in lock-step with the identical definition in
/// `ios/Runner/WorkoutLiveActivityBridge.swift`. ActivityKit requires the
/// ContentState shape to match exactly across the requesting target
/// (Runner) and the rendering target (this Widget Extension).
public struct WorkoutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var restStartedAt: Date?
        public var plannedRestDurationSeconds: Int
        public var addedRestSeconds: Int
        public var exerciseName: String
        public var setLabel: String

        public var restEndsAt: Date? {
            guard let start = restStartedAt else { return nil }
            return start.addingTimeInterval(
                TimeInterval(plannedRestDurationSeconds + addedRestSeconds)
            )
        }
        public var isResting: Bool { restStartedAt != nil }
    }
    public var workoutStartedAt: Date
}

@available(iOS 16.1, *)
struct ZuralogWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundColor(.green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isResting, let endsAt = context.state.restEndsAt {
                        Text(timerInterval: Date()...endsAt, countsDown: true)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(
                            timerInterval: context.attributes.workoutStartedAt...Date()
                                .addingTimeInterval(3600 * 24),
                            countsDown: false
                        )
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        if !context.state.exerciseName.isEmpty {
                            Text(context.state.exerciseName)
                                .font(.headline)
                        }
                        if !context.state.setLabel.isEmpty {
                            Text(context.state.setLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.isResting ? "Rest" : "Working")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill").foregroundColor(.green)
            } compactTrailing: {
                if context.state.isResting, let endsAt = context.state.restEndsAt {
                    Text(timerInterval: Date()...endsAt, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 48)
                } else {
                    Text(
                        timerInterval: context.attributes.workoutStartedAt...Date()
                            .addingTimeInterval(3600 * 24),
                        countsDown: false
                    )
                    .monospacedDigit()
                    .frame(maxWidth: 48)
                }
            } minimal: {
                Image(systemName: "timer").foregroundColor(.green)
            }
        }
    }
}

@available(iOS 16.1, *)
struct LockScreenView: View {
    let context: ActivityViewContext<WorkoutAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "dumbbell.fill").foregroundColor(.green)
                Text("Zuralog").font(.headline)
                Spacer()
                Text(
                    timerInterval: context.attributes.workoutStartedAt...Date()
                        .addingTimeInterval(3600 * 24),
                    countsDown: false
                )
                .monospacedDigit()
                .font(.subheadline)
            }
            if !context.state.exerciseName.isEmpty {
                Text(context.state.exerciseName).font(.title3.bold())
            }
            if context.state.isResting, let endsAt = context.state.restEndsAt {
                HStack {
                    Text("Rest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(timerInterval: Date()...endsAt, countsDown: true)
                        .monospacedDigit()
                        .font(.title.bold())
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
    }
}
