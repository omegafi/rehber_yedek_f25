import SwiftUI

class ContactsViewModel: ObservableObject {
    private let contactsService = ContactsService()
    
    @Published var contacts: [ContactModel] = []
    @Published var selectedContactIds: Set<String> = []
    @Published var duplicateGroups: [[ContactModel]] = []
    @Published var isLoading = false
    @Published var error: String? = nil
    @Published var searchText = ""
    
    var filteredContacts: [ContactModel] {
        if searchText.isEmpty {
            return contacts
        } else {
            return contacts.filter { contact in
                let fullName = contact.fullName.lowercased()
                let phones = contact.phoneNumbers.map { $0.number.lowercased() }
                let emails = contact.emails.map { $0.address.lowercased() }
                
                let searchQuery = searchText.lowercased()
                
                return fullName.contains(searchQuery) ||
                       phones.contains(where: { $0.contains(searchQuery) }) ||
                       emails.contains(where: { $0.contains(searchQuery) })
            }
        }
    }
    
    // Kişileri yükleme
    func loadContacts() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let loadedContacts = try await contactsService.fetchAllContacts()
            await MainActor.run {
                self.contacts = loadedContacts
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // Kişileri vCard olarak dışa aktarma
    func exportAsVCard() async -> URL? {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let selectedContacts = contacts.filter { selectedContactIds.contains($0.id) }
            let fileURL = try await contactsService.exportContactsAsVCard(contacts: selectedContacts)
            
            await MainActor.run {
                self.isLoading = false
            }
            
            return fileURL
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            return nil
        }
    }
    
    // vCard dosyası içe aktarma
    func importVCard(from url: URL) async -> Int {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let importedCount = try await contactsService.importVCard(from: url)
            await loadContacts()
            return importedCount
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            return 0
        }
    }
    
    // Kişileri birleştirme
    func mergeSelectedContacts() async {
        guard selectedContactIds.count >= 2 else {
            await MainActor.run {
                self.error = "En az iki kişi seçmelisiniz"
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let _ = try await contactsService.mergeContacts(contactIds: Array(selectedContactIds))
            
            // Kişileri yeniden yükle
            await loadContacts()
            
            // Seçimleri temizle
            await MainActor.run {
                selectedContactIds.removeAll()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // Yinelenen kişileri bulma
    func findDuplicates() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let groups = try await contactsService.findDuplicateContacts()
            await MainActor.run {
                self.duplicateGroups = groups
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // Kişi seçimini değiştirme
    func toggleSelection(for contactId: String) {
        if selectedContactIds.contains(contactId) {
            selectedContactIds.remove(contactId)
        } else {
            selectedContactIds.insert(contactId)
        }
    }
    
    // Tüm kişileri seç/seçimi kaldır
    func toggleSelectAll() {
        if selectedContactIds.count == filteredContacts.count {
            selectedContactIds.removeAll()
        } else {
            selectedContactIds = Set(filteredContacts.map { $0.id })
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var contactsViewModel: ContactsViewModel
    @State private var showingExportOptions = false
    @State private var showingMergeConfirmation = false
    @State private var showingDuplicatesSheet = false
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Arama çubuğu
                    SearchBar(text: $contactsViewModel.searchText)
                    
                    // Seçim kontrolü
                    if !contactsViewModel.selectedContactIds.isEmpty {
                        SelectionControlBar(
                            selectedCount: contactsViewModel.selectedContactIds.count,
                            onClearSelection: { contactsViewModel.selectedContactIds.removeAll() },
                            onExport: { showingExportOptions = true },
                            onMerge: { showingMergeConfirmation = true }
                        )
                    }
                    
                    // Kişiler listesi
                    ContactsList(
                        contacts: contactsViewModel.filteredContacts,
                        selectedIds: contactsViewModel.selectedContactIds,
                        onToggleSelection: { contactsViewModel.toggleSelection(for: $0) }
                    )
                    .refreshable {
                        isRefreshing = true
                        await contactsViewModel.loadContacts()
                        isRefreshing = false
                    }
                }
                
                // Yükleniyor göstergesi
                if contactsViewModel.isLoading && !isRefreshing {
                    ProgressView("Yükleniyor...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Rehber")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        contactsViewModel.toggleSelectAll()
                    }) {
                        Text(contactsViewModel.selectedContactIds.count == contactsViewModel.filteredContacts.count ? "Seçimi Kaldır" : "Tümünü Seç")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await contactsViewModel.findDuplicates()
                            showingDuplicatesSheet = true
                        }
                    }) {
                        Label("Yinelenen Kişiler", systemImage: "person.2.slash")
                    }
                }
            }
            .alert(item: Binding<ContactsAlert?>(
                get: { contactsViewModel.error != nil ? ContactsAlert(message: contactsViewModel.error!) : nil },
                set: { _ in contactsViewModel.error = nil }
            )) { alert in
                Alert(title: Text("Hata"), message: Text(alert.message), dismissButton: .default(Text("Tamam")))
            }
            .sheet(isPresented: $showingDuplicatesSheet) {
                DuplicatesView()
                    .environmentObject(contactsViewModel)
            }
            .confirmationDialog("Dışa Aktar", isPresented: $showingExportOptions, titleVisibility: .visible) {
                Button("vCard (.vcf)") {
                    Task {
                        if let fileURL = await contactsViewModel.exportAsVCard() {
                            shareFile(fileURL)
                        }
                    }
                }
                
                Button("İptal", role: .cancel) {}
            }
            .alert("Kişileri Birleştir", isPresented: $showingMergeConfirmation) {
                Button("Birleştir", role: .destructive) {
                    Task {
                        await contactsViewModel.mergeSelectedContacts()
                    }
                }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Seçilen \(contactsViewModel.selectedContactIds.count) kişiyi birleştirmek istediğinize emin misiniz? Bu işlem geri alınamaz.")
            }
        }
        .onAppear {
            Task {
                await contactsViewModel.loadContacts()
            }
        }
    }
    
    // Dosya paylaşımı
    func shareFile(_ fileURL: URL) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        // iPad için popover sunum
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            activityVC.popoverPresentationController?.sourceView = rootViewController.view
            rootViewController.present(activityVC, animated: true, completion: nil)
        }
    }
}

// Yardımcı bileşenler
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Rehberde Ara", text: $text)
                .disableAutocorrection(true)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct SelectionControlBar: View {
    let selectedCount: Int
    let onClearSelection: () -> Void
    let onExport: () -> Void
    let onMerge: () -> Void
    
    var body: some View {
        HStack {
            Text("\(selectedCount) kişi seçildi")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onClearSelection) {
                Text("Temizle")
                    .font(.subheadline)
            }
            
            Button(action: onExport) {
                Label("Dışa Aktar", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
            }
            
            Button(action: onMerge) {
                Label("Birleştir", systemImage: "person.2")
                    .font(.subheadline)
            }
            .disabled(selectedCount < 2)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
    }
}

struct ContactsList: View {
    let contacts: [ContactModel]
    let selectedIds: Set<String>
    let onToggleSelection: (String) -> Void
    
    var body: some View {
        List {
            ForEach(contacts) { contact in
                ContactRow(
                    contact: contact,
                    isSelected: selectedIds.contains(contact.id),
                    onToggleSelection: { onToggleSelection(contact.id) }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

struct ContactRow: View {
    let contact: ContactModel
    let isSelected: Bool
    let onToggleSelection: () -> Void
    
    var body: some View {
        HStack {
            ContactAvatar(contact: contact)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading) {
                Text(contact.fullName)
                    .font(.headline)
                
                if !contact.phoneNumbers.isEmpty {
                    Text(contact.phoneNumbers[0].number)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleSelection()
        }
    }
}

struct ContactAvatar: View {
    let contact: ContactModel
    
    var body: some View {
        Group {
            if let photoData = contact.photo, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
            }
        }
        .clipShape(Circle())
    }
    
    var initials: String {
        let firstInitial = contact.firstName.first.map(String.init) ?? ""
        let lastInitial = contact.lastName.first.map(String.init) ?? ""
        return (firstInitial + lastInitial).uppercased()
    }
    
    var backgroundColor: Color {
        let hash = abs(contact.id.hashValue)
        return [
            Color.blue, Color.green, Color.orange, 
            Color.purple, Color.pink, Color.red
        ][hash % 6]
    }
}

struct DuplicatesView: View {
    @EnvironmentObject private var contactsViewModel: ContactsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if contactsViewModel.duplicateGroups.isEmpty {
                    ContentUnavailableView(
                        "Yinelenen Kişi Bulunamadı",
                        systemImage: "person.crop.circle.badge.checkmark",
                        description: Text("Rehberinizde yinelenen kişi bulunmuyor.")
                    )
                } else {
                    List {
                        ForEach(Array(contactsViewModel.duplicateGroups.enumerated()), id: \.element.first!.id) { index, group in
                            Section(header: Text("Grup \(index + 1)")) {
                                ForEach(group) { contact in
                                    ContactDuplicateRow(contact: contact) {
                                        contactsViewModel.toggleSelection(for: contact.id)
                                    }
                                    .background(
                                        contactsViewModel.selectedContactIds.contains(contact.id) ?
                                        Color.blue.opacity(0.1) : Color.clear
                                    )
                                }
                                
                                Button(action: {
                                    // Gruptaki tüm kişileri seç
                                    for contact in group {
                                        contactsViewModel.selectedContactIds.insert(contact.id)
                                    }
                                    dismiss()
                                }) {
                                    Label("Bu Grubu Birleştir", systemImage: "arrow.triangle.merge")
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Yinelenen Kişiler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ContactDuplicateRow: View {
    let contact: ContactModel
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                ContactAvatar(contact: contact)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading) {
                    Text(contact.fullName)
                        .font(.headline)
                }
                
                Spacer()
            }
            
            if !contact.phoneNumbers.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(contact.phoneNumbers) { phone in
                        HStack {
                            Image(systemName: "phone")
                                .font(.subheadline)
                            Text(phone.number)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.leading)
                .foregroundColor(.secondary)
            }
            
            if !contact.emails.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(contact.emails) { email in
                        HStack {
                            Image(systemName: "envelope")
                                .font(.subheadline)
                            Text(email.address)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.leading)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

struct ContactsAlert: Identifiable {
    var id: String { message }
    let message: String
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(ContactsViewModel())
    }
} 