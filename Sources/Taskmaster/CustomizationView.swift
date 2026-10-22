import AppKit
import CompanionCore
import SwiftUI

enum CustomizationSection: String, CaseIterable {
    case look, voice, mischief, memes, habits
    var title: String {
        switch self {
        case .look: "Look & feel"
        case .voice: "Voice & quips"
        case .mischief: "Little crimes"
        case .memes: "Meme stash"
        case .habits: "Daily rhythm"
        }
    }
    var symbol: String {
        switch self {
        case .look: "tshirt"
        case .voice: "text.bubble"
        case .mischief: "pawprint"
        case .memes: "photo.on.rectangle.angled"
        case .habits: "leaf"
        }
    }
}

struct CustomizationView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Make \(model.preferences.name) yours.").font(.system(size: 29, design: .serif))
                    Text("A little more you. A little more personality.").font(.system(size: 12)).foregroundStyle(
                        Palette.secondary)
                }
                Spacer()
                Button("Done") { model.closeCustomization?() }.buttonStyle(.borderedProminent)
            }
            HStack(alignment: .top, spacing: 27) {
                VStack(spacing: 7) {
                    ForEach(CustomizationSection.allCases, id: \.self) { section in
                        Button {
                            model.customizationSection = section
                        } label: {
                            Label(section.title, systemImage: section.symbol)
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    model.customizationSection == section ? Palette.orange.opacity(0.1) : .clear,
                                    in: RoundedRectangle(cornerRadius: 11)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 11))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(model.customizationSection == section ? Palette.orange : Palette.secondary)
                    }
                    Spacer()
                    Image(systemName: "pawprint.fill").font(.system(size: 24)).foregroundStyle(
                        Palette.orange.opacity(0.25))
                    Text("small paws.\nyour kind of company.")
                        .font(.system(size: 10)).multilineTextAlignment(.center).foregroundStyle(Palette.secondary)
                }.frame(width: 151)
                Divider()
                ScrollView {
                    Group {
                        switch model.customizationSection {
                        case .look: WardrobeEditor(model: model)
                        case .voice: VoiceEditor(model: model)
                        case .mischief: MischiefEditor(model: model)
                        case .memes: MemeStash(model: model, library: model.library)
                        case .habits: RhythmEditor(model: model)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 4)
                }
            }
        }
        .padding(30)
        .padding(.top, 22)
        .frame(minWidth: 820, minHeight: 650)
        .background(Palette.paper)
        .foregroundStyle(Palette.ink)
        .tint(Palette.orange)
        .preferredColorScheme(.light)
    }
}

private struct WardrobeEditor: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            title(
                "A familiar little face. Your way.",
                subtitle: "A softer coat, a favorite color, a tiny finishing touch. Changes appear as you choose.")
            HStack(spacing: 12) {
                ForEach(AvatarKind.available, id: \.self) { avatar in
                    Button {
                        model.selectAvatar(avatar)
                    } label: {
                        VStack(spacing: 4) {
                            if let frame = model.art(for: avatar)?.frame(for: .sitting) {
                                Image(nsImage: NSImage(cgImage: frame.image, size: .zero)).resizable().scaledToFit()
                                    .frame(height: 68)
                            }
                            Text(avatar.title).font(.system(size: 12, weight: .semibold))
                        }.frame(maxWidth: .infinity).padding(10)
                            .background(
                                model.preferences.avatar == avatar ? Palette.orange.opacity(0.1) : .white.opacity(0.65),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12).stroke(
                                    model.preferences.avatar == avatar ? Palette.orange : Palette.line, lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityLabel("Choose \(avatar.title)")
                }
            }
            PetPreview(model: model, wardrobe: true)
                .frame(height: 250)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.91, blue: 0.84), Palette.paper], startPoint: .top,
                        endPoint: .bottom), in: RoundedRectangle(cornerRadius: 18)
                )
                .overlay(alignment: .topLeading) {
                    Text("\(model.preferences.name.uppercased())’S WARDROBE")
                        .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.4)
                        .foregroundStyle(Palette.secondary).padding(17)
                }
                .accessibilityLabel("Live preview of your companion’s outfit")
            HStack {
                Text("A name of their own").font(.system(size: 12))
                Spacer()
                TextField(model.preferences.avatar.title, text: $model.preferences.name).textFieldStyle(.roundedBorder)
                    .frame(width: 155)
                    .accessibilityLabel("Companion name")
            }
            if model.preferences.avatar == .miso {
                Picker("Coat tone", selection: $model.preferences.coat) {
                    ForEach(CoatStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                Picker("Little accessory", selection: $model.preferences.accessory) {
                    ForEach(AccessoryStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                HStack(spacing: 12) {
                    Text("Favorite color").font(.system(size: 12))
                    Spacer()
                    ForEach(AccessoryColor.allCases, id: \.self) { color in
                        Button {
                            model.preferences.accessoryColor = color
                        } label: {
                            Circle().fill(Color(nsColor: color.nsColor)).frame(width: 25, height: 25)
                                .overlay(Circle().stroke(.white, lineWidth: 3).padding(3))
                                .overlay(
                                    Circle().stroke(
                                        model.preferences.accessoryColor == color ? Palette.ink : .clear, lineWidth: 1.3
                                    ).padding(-3))
                        }.buttonStyle(.plain).help(color.title).accessibilityLabel("\(color.title) accessory")
                    }
                }.padding(.vertical, 4)
            }
            Button(model.preferences.avatar.signature) { model.perform(.signature) }.buttonStyle(.borderedProminent)
            setting("Desktop size", value: "\(Int(model.preferences.size * 100))%") {
                Slider(value: $model.preferences.size, in: 0.65...1.5, step: 0.05).accessibilityLabel("Companion size")
            }
            Toggle("Show their name on the desktop", isOn: $model.preferences.showName).font(.system(size: 12))
        }
    }
}

private struct MischiefEditor: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            title(
                "Small paws. Petty crimes.",
                subtitle: "Choose which kinds of trouble are welcome. Focus time stays peaceful.")
            HStack(spacing: 9) {
                ForEach(Personality.allCases, id: \.self) { mood in
                    Button {
                        model.select(mood)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: mood.symbol).font(.system(size: 20))
                            Text(mood.title).font(.system(size: 12, weight: .semibold))
                        }.frame(maxWidth: .infinity).padding(.vertical, 18)
                            .background(
                                model.preferences.personality == mood
                                    ? Palette.orange.opacity(0.1) : .white.opacity(0.7),
                                in: RoundedRectangle(cornerRadius: 13)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13).stroke(
                                    model.preferences.personality == mood ? Palette.orange : Palette.line,
                                    lineWidth: 0.8))
                    }.buttonStyle(.plain)
                }
            }
            setting("Mischief", value: "\(Int(model.preferences.mischief * 100))%") {
                Slider(value: $model.preferences.mischief, in: 0...1).accessibilityLabel("Mischief intensity")
            }
            Divider()
            Toggle("Muddy little paws", isOn: $model.preferences.muddyPaws).font(.system(size: 14, weight: .medium))
            Text(
                "In Chaos, \(model.preferences.name) leaves a trail wherever they walk. Pawprints fade on their own and never catch your clicks."
            )
            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            setting("How long the evidence stays", value: "\(Int(model.preferences.pawprintSeconds)) seconds") {
                Slider(value: $model.preferences.pawprintSeconds, in: 8...90, step: 1).accessibilityLabel(
                    "Pawprint lifetime")
            }
            HStack {
                Button("Muddy zoomies") { model.perform(.muddyZoomies) }.disabled(!model.preferences.muddyPaws)
                Button("Wipe pawprints") { model.wipePawprints() }
            }.controlSize(.small)
            Divider()
            Toggle("Let \(model.preferences.name) borrow my cursor", isOn: $model.preferences.cursorHeists).font(
                .system(size: 14, weight: .medium))
            Text(
                "Chaos only. A nearby pointer may get snatched for a tiny getaway, lasting at most 1½ seconds. Click or press Esc to end the game immediately."
            )
            .font(.system(size: 12)).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            Text(
                "Heists take a long breather between attempts. They stay off during focus, naps, full-screen presentations and Reduce Motion."
            )
            .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            Button("Invite a cursor heist") { model.inviteCursorHeist() }
                .disabled(!model.preferences.cursorHeists || model.preferences.mischief < 0.75 || model.focusActive)
            if let message = model.chaosMessage {
                Text(message).font(.system(size: 11)).foregroundStyle(Palette.orange)
            }
        }
    }
}

private struct VoiceEditor: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            title("A voice you recognize.", subtitle: "Write the things you’d like your little companion to say.")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("YOUR QUIPS").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5)
                    Spacer()
                    Text("\(model.preferences.quipLines.count) sayings").font(.system(size: 10)).foregroundStyle(
                        Palette.secondary)
                }
                TextEditor(text: $model.preferences.customQuips)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(9)
                    .frame(height: 165)
                    .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 0.7))
                    .accessibilityLabel("Custom quips, one saying per line")
                Text("One saying per line. Use {name} for your pet’s name. Up to 100 sayings, 160 characters each.")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                HStack(spacing: 8) {
                    Button("Add cozy lines") { model.addQuipPack(chaotic: false) }
                    Button("Add chaotic lines") { model.addQuipPack(chaotic: true) }
                }.controlSize(.small)
                Toggle(
                    "Mix in \(model.preferences.name)’s original sayings", isOn: $model.preferences.includeBuiltInQuips
                ).font(.system(size: 12))
            }
            setting(
                "How talkative?",
                value: model.preferences.chatter == 0
                    ? "Silent" : model.preferences.chatter < 0.5 ? "Occasional" : "Chatty"
            ) {
                Slider(value: $model.preferences.chatter, in: 0...1).accessibilityLabel("Chatter level")
            }
            setting("Time to read a saying", value: "\(Int(model.preferences.speechSeconds)) seconds") {
                Slider(value: $model.preferences.speechSeconds, in: 2...12, step: 1).accessibilityLabel(
                    "Speech duration")
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Bubble color").font(.system(size: 12, weight: .medium))
                HStack(spacing: 8) {
                    ForEach(BubbleStyle.allCases, id: \.self) { style in
                        Button {
                            model.preferences.bubbleStyle = style
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(style.color).frame(width: 13, height: 13).overlay(
                                    Circle().stroke(Palette.line, lineWidth: 0.6))
                                Text(style.title).font(.system(size: 10))
                            }
                            .padding(.horizontal, 9).padding(.vertical, 8)
                            .background(.white.opacity(0.6), in: Capsule())
                            .overlay(
                                Capsule().stroke(
                                    model.preferences.bubbleStyle == style ? Palette.orange : Palette.line, lineWidth: 1
                                ))
                        }.buttonStyle(.plain)
                    }
                }
                Text(
                    model.preferences.chatter == 0
                        ? "\(model.preferences.name) is enjoying some quiet." : model.lastQuip
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(model.preferences.bubbleStyle == .midnight ? Color.white : Palette.ink)
                .padding(16).frame(maxWidth: .infinity, minHeight: 65)
                .background(model.preferences.bubbleStyle.color, in: RoundedRectangle(cornerRadius: 16))
                Button("Say something") { model.perform(.saySomething) }
                    .disabled(
                        model.focusActive || model.preferences.chatter == 0
                            || (!model.preferences.includeBuiltInQuips && model.preferences.quipLines.isEmpty))
            }
        }
    }
}

private struct MemeStash: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: MemeLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            title(
                "Little deliveries. Big energy.",
                subtitle:
                    "\(model.preferences.name) fetches a card from off-screen, leaves it for you, then takes it home.")
            HStack {
                Button {
                    model.importMemes()
                } label: {
                    Label("Add images…", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isImporting)
                Spacer()
                if let phase = model.deliveryPhase {
                    Text(phase.description).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    Button("Send back") { model.putMemeAway() }.controlSize(.small)
                }
            }
            HStack {
                TextField("Or paste a direct HTTPS image link", text: $model.imageLink)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Meme image link")
                Button(model.isImporting ? "Adding…" : "Add link") { model.importImageLink() }
                    .disabled(
                        model.imageLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isImporting)
            }
            Text(
                "Your images are copied into \(model.preferences.name)’s stash. Original files stay untouched. Animated files use the first frame."
            )
            .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            if let message = model.libraryMessage {
                Text(message).font(.system(size: 11)).foregroundStyle(Palette.orange)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
            }
            if library.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 30)).foregroundStyle(
                        Palette.secondary)
                    Text("A little space for your sense of humor.").font(.system(size: 13))
                    Button("Restore starter cards") { library.restoreStarters() }
                }.frame(maxWidth: .infinity).padding(.vertical, 50)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 12)], spacing: 12) {
                ForEach(library.items) { item in
                    VStack(alignment: .leading, spacing: 9) {
                        Image(nsImage: library.image(for: item)).resizable().scaledToFit()
                            .frame(maxWidth: .infinity).frame(height: 125)
                            .background(Palette.paper, in: RoundedRectangle(cornerRadius: 8))
                        Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        Toggle(
                            "In rotation",
                            isOn: Binding(get: { item.enabled }, set: { library.setEnabled(item.id, $0) })
                        )
                        .font(.system(size: 10)).toggleStyle(.checkbox)
                        HStack {
                            Button("Bring this") { model.bringMeme(item) }.controlSize(.small).disabled(
                                model.deliveryPhase != nil)
                            Spacer()
                            Button {
                                library.remove(item)
                            } label: {
                                Image(systemName: "trash").font(.system(size: 10))
                            }
                            .buttonStyle(.plain).foregroundStyle(Palette.secondary)
                            .help("Remove from \(model.preferences.name)’s stash").disabled(model.deliveryPhase != nil)
                        }
                    }
                    .padding(11)
                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.line.opacity(0.7), lineWidth: 0.7))
                }
            }
            Button("Restore starter cards") { library.restoreStarters() }.controlSize(.small)
        }
    }
}

private struct RhythmEditor: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            title(
                "Company that fits your day.",
                subtitle: "Give \(model.preferences.name) a rhythm that feels welcome on your desktop.")
            VStack(alignment: .leading, spacing: 12) {
                Text("Quiet focus").font(.system(size: 17, design: .serif))
                Text(
                    "\(model.preferences.name) settles nearby while you work. When time is up, you get a gentle stretch reminder."
                )
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                HStack {
                    Text("Session length").font(.system(size: 12))
                    Spacer()
                    TextField("Minutes", value: $model.preferences.focusMinutes, format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 55).accessibilityLabel("Focus minutes")
                    Text("min").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                HStack {
                    ForEach([15, 25, 45], id: \.self) { minutes in
                        Button("\(minutes) min") { model.preferences.focusMinutes = minutes }.controlSize(.small)
                    }
                    Spacer()
                    Button(model.focusActive ? "End focus" : "Focus together") {
                        if model.focusActive { model.stopFocus() } else { model.startFocus() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                if model.focusActive {
                    Text("\(model.focusLabel) left · quiet company").font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Palette.green)
                }
                if model.preferences.completedFocusSessions > 0 {
                    Text("\(model.preferences.completedFocusSessions) little focus sessions, together.").font(
                        .system(size: 10)
                    ).foregroundStyle(Palette.secondary)
                }
            }
            Divider()
            Toggle("Occasionally bring me a meme", isOn: $model.preferences.autoMemes).font(
                .system(size: 13, weight: .medium))
            Text(
                "Only enabled cards in your stash are used. Deliveries pause during focus, naps and when \(model.preferences.name) is tucked away."
            )
            .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            setting("Time between deliveries", value: "\(Int(model.preferences.memeInterval / 60)) min") {
                Slider(value: $model.preferences.memeInterval, in: 120...3_600, step: 60).accessibilityLabel(
                    "Meme delivery interval")
            }
            setting("Leave each card for", value: "\(Int(model.preferences.memeStaySeconds)) seconds") {
                Slider(value: $model.preferences.memeStaySeconds, in: 8...120, step: 1).accessibilityLabel(
                    "Meme display time")
            }
            Divider()
            Toggle("Nap when I’ve been away", isOn: $model.preferences.quietWhenIdle)
            Toggle("Show \(model.preferences.name) on every desktop Space", isOn: $model.preferences.allSpaces)
            Toggle("Little sound effects", isOn: $model.preferences.sound)
        }
    }
}

@MainActor private func title(_ text: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 7) {
        Text(text).font(.system(size: 23, design: .serif))
        Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.secondary).fixedSize(
            horizontal: false, vertical: true)
    }
}

@MainActor private func setting<Content: View>(_ title: String, value: String, @ViewBuilder content: () -> Content)
    -> some View
{
    VStack(alignment: .leading, spacing: 7) {
        HStack {
            Text(title).font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.secondary)
        }
        content()
    }
}

extension BubbleStyle {
    fileprivate var color: Color { Color(nsColor: nsColor) }
}
