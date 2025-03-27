import SwiftUI
import UniformTypeIdentifiers

enum ImportState {
    case initial
    case loading
    case success(count: Int)
    case error(message: String)
}

struct ImportView: View {
    @EnvironmentObject private var contactsViewModel: ContactsViewModel
    @State private var importState: ImportState = .initial
    @State private var selectedFormat: ContactFormat = .vcard
    @State private var isFilePickerPresented = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Format seçimi
                    FormatSelectionCard(
                        selectedFormat: $selectedFormat,
                        importState: importState
                    )
                    
                    // Dosya seçimi
                    FileSelectionCard(
                        selectedFormat: selectedFormat,
                        importState: importState,
                        onSelectFile: { isFilePickerPresented = true }
                    )
                    
                    // Durum mesajları
                    if case .loading = importState {
                        LoadingView()
                    } else if case .success(let count) = importState {
                        SuccessView(count: count) {
                            importState = .initial
                        }
                    } else if case .error(let message) = importState {
                        ErrorView(message: message) {
                            importState = .initial
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("İçe Aktarma")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Yardım veya bilgi gösterimi
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .fileImporter(
                isPresented: $isFilePickerPresented,
                allowedContentTypes: allowedTypes(),
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }
    
    private func allowedTypes() -> [UTType] {
        switch selectedFormat {
        case .vcard:
            return [UTType.vCard]
        case .csv:
            return [UTType.commaSeparatedText]
        case .excel:
            return [UTType.spreadsheet]
        case .json:
            return [UTType.json]
        case .pdf:
            return [UTType.pdf]
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            guard let selectedFile = try result.get().first else {
                return
            }
            
            // Dosyaya erişim izni al
            if !selectedFile.startAccessingSecurityScopedResource() {
                throw NSError(domain: "ImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dosyaya erişim izni alınamadı"])
            }
            
            // İçe aktarma işlemini başlat
            importState = .loading
            
            Task {
                defer {
                    selectedFile.stopAccessingSecurityScopedResource()
                }
                
                do {
                    switch selectedFormat {
                    case .vcard:
                        let importedCount = await contactsViewModel.importVCard(from: selectedFile)
                        await MainActor.run {
                            if importedCount > 0 {
                                importState = .success(count: importedCount)
                            } else {
                                importState = .error(message: "İçe aktarılacak kişi bulunamadı")
                            }
                        }
                    default:
                        await MainActor.run {
                            importState = .error(message: "Seçilen format henüz desteklenmiyor")
                        }
                    }
                } catch {
                    await MainActor.run {
                        importState = .error(message: error.localizedDescription)
                    }
                }
            }
        } catch {
            importState = .error(message: error.localizedDescription)
        }
    }
}

struct FormatSelectionCard: View {
    @Binding var selectedFormat: ContactFormat
    let importState: ImportState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dosya Formatı Seçin")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    FormatChip(
                        title: "vCard (.vcf)",
                        icon: "person.crop.rectangle",
                        isSelected: selectedFormat == .vcard,
                        isDisabled: isLoading
                    ) {
                        selectedFormat = .vcard
                    }
                    
                    FormatChip(
                        title: "CSV (.csv)",
                        icon: "tablecells",
                        isSelected: selectedFormat == .csv,
                        isDisabled: true
                    ) {
                        selectedFormat = .csv
                    }
                    
                    FormatChip(
                        title: "Excel (.xlsx)",
                        icon: "doc.text",
                        isSelected: selectedFormat == .excel,
                        isDisabled: true
                    ) {
                        selectedFormat = .excel
                    }
                    
                    FormatChip(
                        title: "JSON (.json)",
                        icon: "curlybraces",
                        isSelected: selectedFormat == .json,
                        isDisabled: true
                    ) {
                        selectedFormat = .json
                    }
                }
            }
            
            Text(formatDescription)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var isLoading: Bool {
        if case .loading = importState {
            return true
        }
        return false
    }
    
    private var formatDescription: String {
        switch selectedFormat {
        case .vcard:
            return "vCard (.vcf) formatı, kişi bilgilerini içeren standart bir formattır ve çoğu cihaz tarafından desteklenir."
        case .csv:
            return "CSV (.csv) formatı, virgülle ayrılmış değerler içeren bir tablo formatıdır. Excel, Google Contacts veya diğer uygulamalardan dışa aktarılan CSV dosyalarını kullanabilirsiniz."
        case .excel:
            return "Excel (.xlsx) formatı, Microsoft Excel veya benzeri uygulamalarda oluşturulan tablolar içerir."
        case .json:
            return "JSON (.json) formatı, yapılandırılmış veri saklamak için kullanılan bir metin formatıdır."
        case .pdf:
            return "PDF formatı görüntüleme içindir, içe aktarılabilir versiyon değildir."
        }
    }
}

struct FormatChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : isDisabled ? .gray : .primary)
            .cornerRadius(20)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
    }
}

struct FileSelectionCard: View {
    let selectedFormat: ContactFormat
    let importState: ImportState
    let onSelectFile: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dosya Seçimi")
                .font(.headline)
            
            Text(fileSelectionDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: onSelectFile) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Dosya Seç")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var isLoading: Bool {
        if case .loading = importState {
            return true
        }
        return false
    }
    
    private var fileSelectionDescription: String {
        switch selectedFormat {
        case .vcard:
            return "Lütfen içe aktarmak istediğiniz .vcf uzantılı vCard dosyasını seçin. Bu dosya, başka bir uygulamadan veya cihazdan dışa aktarılmış bir rehber yedeği olabilir."
        case .csv:
            return "Lütfen içe aktarmak istediğiniz .csv uzantılı CSV dosyasını seçin. Dosya, ad ve telefon numarası sütunlarını içermelidir."
        case .excel:
            return "Lütfen içe aktarmak istediğiniz .xlsx veya .xls uzantılı Excel dosyasını seçin."
        case .json:
            return "Lütfen içe aktarmak istediğiniz .json uzantılı JSON dosyasını seçin."
        case .pdf:
            return "PDF dosyaları şu anda içe aktarılamaz."
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Kişiler içe aktarılıyor...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct SuccessView: View {
    let count: Int
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(.green)
            
            Text("İçe Aktarma Başarılı!")
                .font(.headline)
            
            Text("\(count) kişi rehberinize eklendi.")
                .foregroundColor(.secondary)
            
            Button(action: onReset) {
                Text("Yeni Dosya Seç")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ErrorView: View {
    let message: String
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.red)
            
            Text("İçe Aktarma Hatası")
                .font(.headline)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: onReset) {
                Text("Tekrar Dene")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

extension ContactFormat {
    var iconName: String {
        switch self {
        case .vcard: return "person.crop.rectangle"
        case .csv: return "tablecells"
        case .excel: return "doc.text"
        case .json: return "curlybraces"
        case .pdf: return "doc.richtext"
        }
    }
}

struct ImportView_Previews: PreviewProvider {
    static var previews: some View {
        ImportView()
            .environmentObject(ContactsViewModel())
    }
} 