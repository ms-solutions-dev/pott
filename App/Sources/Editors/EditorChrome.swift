import PottDesign
import SwiftUI

/// The frame of every editor sheet: title, cancel, scrolling content, save and optional delete.
struct EditorSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    var title: LocalizedStringKey
    var canSave: Bool
    var save: () -> Void
    var delete: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content()
                    if let delete {
                        Button(role: .destructive) {
                            delete()
                            dismiss()
                        } label: {
                            Text("Delete").textRole(.bodyStrong).frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .foregroundStyle(Palette.negative.color)
                    }
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.background.color)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                // Save stays visible above the keyboard, as everywhere in iOS.
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!canSave)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

/// A row of chips with a caption.
struct ChoiceRow<Value: Hashable, Item>: View {
    var title: LocalizedStringKey
    var items: [Item]
    var value: (Item) -> Value
    var label: (Item) -> String
    var dot: ((Item) -> Color)? = nil
    @Binding var selection: Value

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).textRole(.caption).foregroundStyle(Palette.secondaryText.color)
            FlowLayout(spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Chip(label(item), isSelected: selection == value(item), dot: dot?(item)) {
                        selection = value(item)
                    }
                }
            }
        }
    }
}
