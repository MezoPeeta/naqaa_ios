import SwiftUI

struct LanguagePickerSheet: View {
    @Environment(LanguageStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pending: AppLanguage = .system
    var onConfirm: () -> Void = {}
    
    var body: some View {
        NavigationStack {
            List(AppLanguage.allChoices, id: \.self) { option in
                Button { pending = option } label: {
                    HStack {
                        if let name = option.nativeName {
                            Text(name)
                        } else {
                            Text("System")
                        }
                        Spacer()
                        if pending == option {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.apply(pending)
                    dismiss()
                    onConfirm()
                } label: {
                    Text("Confirm").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12).foregroundStyle(.black)
                }
                .buttonStyle(.glassProminent)
                .padding()
            }
        }
        .onAppear { pending = store.language }
        .presentationDetents([.medium])
    }
}

#Preview {
    LanguagePickerSheet()
        .environment(LanguageStore())
}
