import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

@MainActor
extension CompanionRoom {
    var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("GOOD COMPANY, YOUR WAY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Palette.secondary)
                Text("What’s the mood?").font(.system(size: 23, weight: .regular, design: .serif))
            }
            VStack(spacing: 8) {
                ForEach(Personality.allCases, id: \.self) { personality in
                    PersonalityCard(
                        personality: personality,
                        selected: model.preferences.personality == personality
                    ) { model.select(personality) }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("A touch of mischief").font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("\(Int(model.preferences.mischief * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Palette.secondary)
                }
                Slider(value: $model.preferences.mischief, in: 0...1)
                    .accessibilityLabel("Mischief level")
                HStack {
                    Text("little angel")
                    Spacer()
                    Text("lovable menace")
                }
                .font(.system(size: 9))
                .foregroundStyle(Palette.secondary)
            }
            Rectangle().fill(Palette.line.opacity(0.75)).frame(height: 0.7)
            HStack {
                Text("LITTLE RITUALS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.7)
                    .foregroundStyle(Palette.secondary)
                Spacer()
                if model.interactions > 0 {
                    Text("\(model.interactions) little moments")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.secondary)
                }
            }
            HStack(spacing: 9) {
                RitualButton(title: "Treat", symbol: "carrot.fill") { model.perform(.treat) }
                RitualButton(
                    title: model.preferences.avatar == .toothless ? "Plasma" : "Play", symbol: "tennisball.fill"
                ) { model.perform(.play) }
                RitualButton(
                    title: model.state == .sleeping ? "Wake" : "Nap",
                    symbol: model.state == .sleeping ? "sun.max.fill" : "moon.zzz.fill"
                ) { model.toggleNap() }
            }
            HStack(spacing: 9) {
                RitualButton(
                    title: "High five", symbol: "hand.raised.fingers.spread.fill",
                    hint: "Offer a high five, then click the raised paw."
                ) { model.perform(.offerHighFive) }
                RitualButton(
                    title: model.isFollowingCursor ? "Stay here" : "Follow me", symbol: "cursorarrow.motionlines",
                    hint:
                        "\(model.preferences.name) follows your cursor along the desktop for a minute. Click Stay here to stop."
                ) {
                    model.perform(model.isFollowingCursor ? .stopFollowing : .followCursor)
                }
                RitualButton(
                    title: "Find a snack", symbol: "sparkle.magnifyingglass",
                    hint: "Watch \(model.preferences.name) find and eat a little biscuit."
                ) { model.perform(.findTreat) }
            }
            Button {
                model.perform(model.state == .flying ? .stopFollowing : .signature)
            } label: {
                Label(
                    model.state == .flying
                        ? "Land gently" : model.preferences.avatar.signature,
                    systemImage: model.preferences.avatar.symbol
                ).frame(maxWidth: .infinity)
            }.buttonStyle(.bordered).controlSize(.small)
        }
    }
}
