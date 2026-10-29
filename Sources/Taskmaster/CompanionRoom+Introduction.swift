import AppKit
import CompanionCore
import SpriteKit
import SwiftUI

@MainActor
extension CompanionRoom {
    var introduction: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 3) {
                Text("A little company.")
                Text("A little mischief.").foregroundStyle(Palette.orange)
            }
            .font(.system(size: 36, weight: .regular, design: .serif))
            .tracking(-1)
            .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 25)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.91, blue: 0.83), Color(red: 0.97, green: 0.94, blue: 0.88),
                            ], startPoint: .topLeading, endPoint: .bottomTrailing))
                RoomBackdrop()
                VStack {
                    HStack {
                        Text("MEET \(model.preferences.name.uppercased())")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(Palette.secondary)
                        Spacer()
                        Image(systemName: "sparkle").foregroundStyle(Palette.orange.opacity(0.65))
                    }
                    Spacer()
                }
                .padding(22)
                PetPreview(model: model)
                    .padding(.top, 35)
                    .accessibilityLabel(
                        model.state == .highFive
                            ? "\(model.preferences.name) offers a high five. Press to return it."
                            : "\(model.preferences.name), your \(model.preferences.avatar.title) companion. Press to pet."
                    )
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { model.perform(.pet) }
                HStack(spacing: 5) {
                    Image(systemName: model.state == .sleeping ? "moon.zzz.fill" : "heart.fill")
                        .font(.system(size: 10))
                    Text(
                        model.isPaused
                            ? "Just being here"
                            : model.focusActive
                                ? "Quiet company · \(model.focusLabel)"
                                : model.isStealingCursor
                                    ? "A very tiny crime in progress"
                                    : model.deliveryPhase?.description
                                        ?? (model.isFollowingCursor
                                            ? "Following your little arrow" : model.state.description)
                    )
                    .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Palette.paper.opacity(0.9), in: Capsule())
                .padding(.bottom, 15)
            }
            .frame(height: 302)
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(.white.opacity(0.8), lineWidth: 1))

            HStack(spacing: 7) {
                Image(systemName: "hand.draw").font(.system(size: 13))
                Text(
                    model.state == .highFive
                        ? "Click the raised paw. Tiny teamwork."
                        : model.state == .flying
                            ? "Flying passes clicks through. Land gently to interact."
                            : "Move your cursor close. Stroke gently."
                ).font(.system(size: 12))
            }
            .foregroundStyle(Palette.secondary)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: model.focusActive || model.focusFinished ? "leaf.fill" : "leaf")
                        .foregroundStyle(Palette.green)
                    Text(
                        model.focusActive
                            ? "Quiet company · \(model.focusLabel)"
                            : model.focusFinished ? "Focus complete. Nicely done." : "A little focus, together."
                    )
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    Spacer()
                    if model.focusFinished && !model.focusActive {
                        Button("Thanks") { model.acknowledgeFocus() }.controlSize(.small)
                    }
                    Button(model.focusActive ? "End Focus" : "Start \(model.preferences.focusMinutes)-Minute Focus") {
                        if model.focusActive { model.stopFocus() } else { model.startFocus() }
                    }.controlSize(.small)
                }
                if model.focusActive {
                    ProgressView(value: model.focusProgress).tint(Palette.green)
                    Text("Playing a game ends focus early. Settling down doesn’t pause the timer.")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                } else {
                    HStack {
                        Button {
                            if model.deliveryPhase == nil { model.bringMeme() } else { model.putMemeAway() }
                        } label: {
                            Label(
                                model.deliveryPhase == nil ? "Bring a meme" : "Send it back",
                                systemImage: "photo.on.rectangle")
                        }
                        Spacer()
                        Button("My meme stash") { model.openSettings(.memes) }
                    }.font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(Palette.secondary)
                }
            }
            .padding(14)
            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Palette.line.opacity(0.6), lineWidth: 0.7))
        }
    }
}
