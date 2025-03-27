import Foundation
import Contacts
import ContactsUI
import UniformTypeIdentifiers

enum ContactFormat {
    case vcard
    case csv
    case excel
    case json
    case pdf
}

enum ContactServiceError: Error {
    case permissionDenied
    case noContactsSelected
    case failedToFetchContacts
    case fileCreationError
    case importError
    case unsupportedFormat
    
    var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "Kişilere erişim izni verilmedi"
        case .noContactsSelected:
            return "Hiçbir kişi seçilmedi"
        case .failedToFetchContacts:
            return "Kişiler yüklenemedi"
        case .fileCreationError:
            return "Dosya oluşturma hatası"
        case .importError:
            return "İçe aktarma hatası"
        case .unsupportedFormat:
            return "Desteklenmeyen format"
        }
    }
}

class ContactsService {
    private let contactStore = CNContactStore()
    private var cachedContacts: [CNContact]?
    
    // İzin isteme
    func requestAccess() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            contactStore.requestAccess(for: .contacts) { granted, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: granted)
            }
        }
    }
    
    // Tüm kişileri getirme
    func fetchAllContacts() async throws -> [ContactModel] {
        let hasPermission = try await requestAccess()
        guard hasPermission else {
            throw ContactServiceError.permissionDenied
        }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactDepartmentNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor
        ]
        
        var contacts = [CNContact]()
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        try contactStore.enumerateContacts(with: request) { contact, _ in
            contacts.append(contact)
        }
        
        self.cachedContacts = contacts
        
        return contacts.map { ContactModel.fromCNContact($0) }
    }
    
    // Kişileri dışa aktarma (vCard formatında)
    func exportContactsAsVCard(contacts: [ContactModel]) async throws -> URL {
        guard !contacts.isEmpty else {
            throw ContactServiceError.noContactsSelected
        }
        
        let hasPermission = try await requestAccess()
        guard hasPermission else {
            throw ContactServiceError.permissionDenied
        }
        
        // Kişileri CNContact formatına çevirme
        var cnContacts: [CNContact] = []
        if let cachedContacts = self.cachedContacts {
            // Seçilen kişileri cached içinden bul
            for contact in contacts {
                if let cnContact = cachedContacts.first(where: { $0.identifier == contact.id }) {
                    cnContacts.append(cnContact)
                }
            }
        } else {
            // Tüm kişileri yeniden yükle
            let fetchedContacts = try await fetchAllCNContacts()
            for contact in contacts {
                if let cnContact = fetchedContacts.first(where: { $0.identifier == contact.id }) {
                    cnContacts.append(cnContact)
                }
            }
        }
        
        // Geçici dosya URL'si oluşturma
        let fileName = "contacts_\(Date().timeIntervalSince1970).vcf"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // vCard verisi oluşturma
        let data = try CNContactVCardSerialization.data(with: cnContacts)
        
        // Dosyaya yazma
        try data.write(to: fileURL)
        
        return fileURL
    }
    
    // vCard içe aktarma
    func importVCard(from url: URL) async throws -> Int {
        let hasPermission = try await requestAccess()
        guard hasPermission else {
            throw ContactServiceError.permissionDenied
        }
        
        let data = try Data(contentsOf: url)
        let contacts = try CNContactVCardSerialization.contacts(with: data)
        
        if contacts.isEmpty {
            throw ContactServiceError.importError
        }
        
        // Her bir kişiyi kaydetme
        var successCount = 0
        let saveRequest = CNSaveRequest()
        
        for contact in contacts {
            // Tam kaydetme için mutable kopya oluştur
            let mutableContact = contact.mutableCopy() as! CNMutableContact
            saveRequest.add(mutableContact, toContainerWithIdentifier: nil)
            successCount += 1
        }
        
        try contactStore.execute(saveRequest)
        
        // Önbelleği temizleme
        self.cachedContacts = nil
        
        return successCount
    }
    
    // Kişileri birleştirme
    func mergeContacts(contactIds: [String]) async throws -> ContactModel {
        guard contactIds.count >= 2 else {
            throw ContactServiceError.noContactsSelected
        }
        
        let hasPermission = try await requestAccess()
        guard hasPermission else {
            throw ContactServiceError.permissionDenied
        }
        
        // Birleştirilecek kişileri getir
        var contacts: [CNContact] = []
        
        if let cachedContacts = self.cachedContacts {
            for id in contactIds {
                if let contact = cachedContacts.first(where: { $0.identifier == id }) {
                    contacts.append(contact)
                }
            }
        } else {
            let allContacts = try await fetchAllCNContacts()
            for id in contactIds {
                if let contact = allContacts.first(where: { $0.identifier == id }) {
                    contacts.append(contact)
                }
            }
        }
        
        guard contacts.count >= 2 else {
            throw ContactServiceError.noContactsSelected
        }
        
        // İlk kişiyi ana kişi olarak al
        let primaryContact = contacts[0].mutableCopy() as! CNMutableContact
        let duplicateContacts = Array(contacts.dropFirst())
        
        // Diğer kişilerin bilgilerini ana kişiye ekle
        for contact in duplicateContacts {
            // Telefon numaralarını ekle
            for phoneNumber in contact.phoneNumbers {
                if !primaryContact.phoneNumbers.contains(where: { $0.value.stringValue == phoneNumber.value.stringValue }) {
                    primaryContact.phoneNumbers.append(phoneNumber)
                }
            }
            
            // E-postaları ekle
            for email in contact.emailAddresses {
                if !primaryContact.emailAddresses.contains(where: { $0.value as String == email.value as String }) {
                    primaryContact.emailAddresses.append(email)
                }
            }
            
            // Adresleri ekle
            for address in contact.postalAddresses {
                if !primaryContact.postalAddresses.contains(where: { 
                    $0.value.street == address.value.street && 
                    $0.value.city == address.value.city 
                }) {
                    primaryContact.postalAddresses.append(address)
                }
            }
            
            // Organizasyon bilgilerini ekle
            if primaryContact.organizationName.isEmpty && !contact.organizationName.isEmpty {
                primaryContact.organizationName = contact.organizationName
                primaryContact.departmentName = contact.departmentName
                primaryContact.jobTitle = contact.jobTitle
            }
        }
        
        // Değişiklikleri kaydet
        let saveRequest = CNSaveRequest()
        saveRequest.update(primaryContact)
        
        // Yinelenen kişileri sil
        for contact in duplicateContacts {
            let mutableDuplicate = contact.mutableCopy() as! CNMutableContact
            saveRequest.delete(mutableDuplicate)
        }
        
        try contactStore.execute(saveRequest)
        
        // Önbelleği temizleme
        self.cachedContacts = nil
        
        return ContactModel.fromCNContact(primaryContact)
    }
    
    // Yardımcı metot - Tüm CNContact'ları getirme
    private func fetchAllCNContacts() async throws -> [CNContact] {
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactDepartmentNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactImageDataKey as CNKeyDescriptor
        ]
        
        var contacts = [CNContact]()
        
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        
        try contactStore.enumerateContacts(with: request) { contact, _ in
            contacts.append(contact)
        }
        
        self.cachedContacts = contacts
        
        return contacts
    }
    
    // Yinelenen kişileri bul
    func findDuplicateContacts() async throws -> [[ContactModel]] {
        let contacts = try await fetchAllContacts()
        
        var duplicateGroups: [[ContactModel]] = []
        var processedNames = Set<String>()
        
        // İsim bazlı yinelemeler
        for contact in contacts {
            let fullName = contact.fullName
            if fullName.isEmpty || processedNames.contains(fullName) {
                continue
            }
            
            let sameNames = contacts.filter { $0.fullName == fullName }
            if sameNames.count > 1 {
                duplicateGroups.append(sameNames)
                processedNames.insert(fullName)
            }
        }
        
        // Telefon numarası bazlı yinelemeler
        var phoneContactMap = [String: [ContactModel]]()
        
        for contact in contacts {
            for phone in contact.phoneNumbers {
                let normalizedNumber = normalizePhoneNumber(phone.number)
                if !normalizedNumber.isEmpty {
                    if phoneContactMap[normalizedNumber] == nil {
                        phoneContactMap[normalizedNumber] = [contact]
                    } else {
                        phoneContactMap[normalizedNumber]?.append(contact)
                    }
                }
            }
        }
        
        for (_, contactGroup) in phoneContactMap {
            if contactGroup.count > 1 {
                // Aynı kişileri içermeyen grupları ekle
                let uniqueIds = Set(contactGroup.map { $0.id })
                let alreadyProcessed = duplicateGroups.contains { group in
                    let groupIds = Set(group.map { $0.id })
                    return groupIds == uniqueIds
                }
                
                if !alreadyProcessed {
                    duplicateGroups.append(contactGroup)
                }
            }
        }
        
        return duplicateGroups
    }
    
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        return phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
    }
} 