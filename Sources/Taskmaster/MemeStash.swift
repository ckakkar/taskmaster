import AppKit
import CompanionCore
import SwiftUI

struct MemeStash: View {
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
