import AppKit
import CompanionCore
import SwiftUI

struct BehaviourPane: View {
    @ObservedObject var model: AppModel

    private var name: String { model.preferences.sanitized().name }

    var body: some View {
        Form {
            Section {
                Picker(
                    "Mood",
                    selection: Binding(get: { model.preferences.personality }, set: { model.select($0) })
                ) {
                    ForEach(Personality.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                ValueSlider(
                    title: "Mischief", value: "\(Int((model.preferences.mischief * 100).rounded()))%",
                    amount: $model.preferences.mischief, range: 0...1)
            } header: {
                Text("Personality")
            } footer: {
                Text(
                    "\(model.preferences.personality.description) Mischief sets how often \(name) gets up to something."
                )
            }

            Section {
                ExplainedToggle(
                    "Wander around",
                    detail: "Walks somewhere new every so often. Off, \(name) stays put until you call.",
                    isOn: $model.preferences.wanders)
                ExplainedToggle(
                    "Peek in from the edges",
                    detail: "Slips off the side of the screen, then peeks back in. Pet \(name) to say you found them.",
                    isOn: $model.preferences.peeksFromEdges)
                ExplainedToggle(
                    "Investigate a wiggling cursor",
                    detail: "Playful and Chaos. A cursor jiggling nearby is an invitation to play.",
                    isOn: $model.preferences.curiousAboutCursor)
                ExplainedToggle(
                    "Take little naps", detail: "Cozy curls up for a short nap now and then.",
                    isOn: $model.preferences.napsOnItsOwn)
                ExplainedToggle(
                    "Nap when you’re away",
                    detail: "After five minutes without you, \(name) sleeps until you’re back.",
                    isOn: $model.preferences.quietWhenIdle)
                ExplainedToggle(
                    "Leave little notes", detail: "Playful and Chaos. Click a note to tidy it away.",
                    isOn: $model.preferences.leavesNotes)
                if model.preferences.avatar == .toothless {
                    ExplainedToggle(
                        "Take little flights",
                        detail: "Now and then \(name) flies across your screen. Clicks pass through while airborne.",
                        isOn: $model.preferences.takesFlights)
                }
            } header: {
                Text("On their own")
            } footer: {
                Text("These are what \(name) chooses to do. Everything in the menu bar and the room still works.")
            }

            Section("Muddy pawprints") {
                ExplainedToggle(
                    "Leave muddy pawprints",
                    detail: "In Chaos and during zoomies. The trail fades on its own and never catches your clicks.",
                    isOn: $model.preferences.muddyPaws)
                ValueSlider(
                    title: "Pawprints stay for", value: "\(Int(model.preferences.pawprintSeconds)) s",
                    amount: $model.preferences.pawprintSeconds, range: 8...90, step: 1
                )
                .disabled(!model.preferences.muddyPaws)
                HStack {
                    Spacer()
                    Button("Wipe Pawprints") { model.wipePawprints() }
                }
            }

            Section {
                LabeledContent("Session length") {
                    Stepper(
                        "\(model.preferences.focusMinutes) min", value: $model.preferences.focusMinutes, in: 1...90)
                }
                HStack {
                    Spacer()
                    Button(model.focusActive ? "End Focus" : "Focus Together") {
                        if model.focusActive { model.stopFocus() } else { model.startFocus() }
                    }
                }
            } header: {
                Text("Focus together")
            } footer: {
                Text(focusFooter)
            }
        }
        .formStyle(.grouped)
    }

    private var focusFooter: String {
        let sessions = model.preferences.completedFocusSessions
        let count =
            sessions == 0 ? "" : " \(sessions) session\(sessions == 1 ? "" : "s") together so far."
        return
            "\(name) settles nearby while you work, then suggests a stretch when time’s up. Playing a game ends focus early; settling down doesn’t pause the timer, and a session carries on if Taskmaster restarts.\(count)"
    }
}
