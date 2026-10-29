import AppKit
import CompanionCore
import SwiftUI

struct MemesPane: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: MemeLibrary

    private var name: String { model.preferences.sanitized().name }

    var body: some View {
        Form {
            Section("Deliveries") {
                ExplainedToggle(
                    "Bring me a meme every so often",
                    detail: "\(name) walks off-screen and comes back pulling a card from your stash.",
                    isOn: $model.preferences.autoMemes)
                ValueSlider(
                    title: "Time between deliveries", value: "\(Int(model.preferences.memeInterval / 60)) min",
                    amount: $model.preferences.memeInterval, range: 120...3_600, step: 60
                )
                .disabled(!model.preferences.autoMemes)
                ValueSlider(
                    title: "Leave each card for", value: "\(Int(model.preferences.memeStaySeconds)) s",
                    amount: $model.preferences.memeStaySeconds, range: 8...120, step: 1)
                HStack {
                    if let phase = model.deliveryPhase {
                        Text(phase.description).foregroundStyle(.secondary)
                        Spacer()
                        Button("Send It Back") { model.putMemeAway() }
                    } else {
                        Text("Deliveries wait for a quiet moment: never mid-game, during focus or a nap.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Bring One Now") { model.bringMeme() }
                    }
                }
            }

            Section {
                HStack {
                    Button {
                        model.importMemes()
                    } label: {
                        Label("Add Images…", systemImage: "plus")
                    }
                    Button("Paste Image") { model.pasteImage() }
                    Spacer()
                    Button("Restore Starter Cards") { library.restoreStarters() }
                        .disabled(library.items.count >= MemeLibrary.capacity)
                }
                .disabled(model.isImporting)
                HStack {
                    TextField(
                        "Image link", text: $model.imageLink, prompt: Text("Paste a direct HTTPS image link")
                    )
                    .onSubmit { model.importImageLink() }
                    Button("Add Link") { model.importImageLink() }
                        .disabled(
                            model.imageLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || model.isImporting)
                }
                if let progress = model.importProgress {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(progress)
                        Spacer()
                        Button("Stop") { model.cancelImport() }
                    }
                }
                if let message = model.libraryMessage {
                    Text(message).foregroundStyle(Palette.orange).fixedSize(horizontal: false, vertical: true)
                }
                if let notice = library.notice {
                    HStack(alignment: .firstTextBaseline) {
                        Text(notice).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button("OK") { library.notice = nil }
                    }
                }
                if let removed = library.lastRemoved {
                    HStack {
                        Text("Removed “\(removed.item.title)”.").foregroundStyle(.secondary)
                        Spacer()
                        Button("Undo") { library.undoRemove() }
                        Button("Dismiss") { library.forgetRemoval() }.buttonStyle(.borderless)
                    }
                }
                if library.items.isEmpty {
                    Text("Nothing here yet. Add or drop your own images, or restore the starter cards.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)], spacing: 12
                    ) {
                        ForEach(library.items) { item in
                            MemeCardCell(model: model, library: library, item: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Your stash · \(library.items.count) of \(MemeLibrary.capacity)")
            } footer: {
                Text(
                    "Drop images here, too. PNG, JPEG, GIF, HEIC and other image files up to 25 MB are copied in and resized to at most 1600 pixels; your originals stay where they are. Animated images use their first frame."
                )
            }
        }
        .formStyle(.grouped)
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            if !files.isEmpty {
                model.importFiles(files)
                return true
            }
            guard let link = urls.first(where: { $0.scheme?.lowercased() == "https" }) else { return false }
            model.imageLink = link.absoluteString
            model.importImageLink()
            return true
        }
    }
}

private struct MemeCardCell: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: MemeLibrary
    let item: MemeItem
    @ViewState private var title: String

    init(model: AppModel, library: MemeLibrary, item: MemeItem) {
        self.model = model
        self.library = library
        self.item = item
        _title = ViewState(initialValue: item.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                model.openMeme(item)
            } label: {
                Image(nsImage: library.image(for: item)).resizable().scaledToFit()
                    .frame(maxWidth: .infinity).frame(height: 96)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                    .opacity(item.enabled ? 1 : 0.45)
            }
            .buttonStyle(.plain)
            .help("See it bigger")
            TextField("Title", text: $title)
                .labelsHidden()
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .onSubmit { library.rename(item.id, to: title) }
                .onDisappear { library.rename(item.id, to: title) }
                .accessibilityLabel("Title")
            HStack(spacing: 6) {
                Toggle(
                    "In rotation", isOn: Binding(get: { item.enabled }, set: { library.setEnabled(item.id, $0) })
                )
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                Spacer()
                Button {
                    model.bringMeme(item)
                } label: {
                    Image(systemName: "paperplane")
                }
                .buttonStyle(.borderless)
                .help("Bring this one now")
                .accessibilityLabel("Bring \(item.title) now")
                .disabled(model.deliveryPhase != nil)
                Button {
                    library.remove(item)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove from the stash")
                .accessibilityLabel("Remove \(item.title)")
                .disabled(model.deliveryPhase != nil)
            }
        }
        .padding(9)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.08)))
    }
}
