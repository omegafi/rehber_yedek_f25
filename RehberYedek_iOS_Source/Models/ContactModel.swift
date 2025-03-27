import Foundation
import Contacts

struct ContactModel: Identifiable, Hashable {
    var id: String
    var firstName: String
    var lastName: String
    var phoneNumbers: [PhoneNumber]
    var emails: [EmailAddress]
    var addresses: [Address]
    var organizations: [Organization]
    var photo: Data?
    
    init(id: String = UUID().uuidString, firstName: String = "", lastName: String = "", 
         phoneNumbers: [PhoneNumber] = [], emails: [EmailAddress] = [],
         addresses: [Address] = [], organizations: [Organization] = [], photo: Data? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
        self.emails = emails
        self.addresses = addresses
        self.organizations = organizations
        self.photo = photo
    }
    
    var fullName: String {
        let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "İsimsiz Kişi" : name
    }
    
    static func == (lhs: ContactModel, rhs: ContactModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // CNContact'tan ContactModel'e dönüştürme
    static func fromCNContact(_ contact: CNContact) -> ContactModel {
        let phoneNumbers = contact.phoneNumbers.map { 
            PhoneNumber(number: $0.value.stringValue, label: CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: $0.label ?? ""))
        }
        
        let emails = contact.emailAddresses.map {
            EmailAddress(address: $0.value as String, label: CNLabeledValue<NSString>.localizedString(forLabel: $0.label ?? ""))
        }
        
        let addresses = contact.postalAddresses.map {
            let value = $0.value
            return Address(
                street: value.street,
                city: value.city,
                state: value.state,
                postalCode: value.postalCode,
                country: value.country,
                label: CNLabeledValue<CNPostalAddress>.localizedString(forLabel: $0.label ?? "")
            )
        }
        
        let organizations = contact.organizationName.isEmpty ? [] : [
            Organization(name: contact.organizationName, 
                        department: contact.departmentName, 
                        title: contact.jobTitle)
        ]
        
        let photo = contact.imageData
        
        return ContactModel(
            id: contact.identifier,
            firstName: contact.givenName,
            lastName: contact.familyName,
            phoneNumbers: phoneNumbers,
            emails: emails,
            addresses: addresses,
            organizations: organizations,
            photo: photo
        )
    }
}

struct PhoneNumber: Identifiable, Hashable {
    var id = UUID()
    var number: String
    var label: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct EmailAddress: Identifiable, Hashable {
    var id = UUID()
    var address: String
    var label: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Address: Identifiable, Hashable {
    var id = UUID()
    var street: String
    var city: String
    var state: String
    var postalCode: String
    var country: String
    var label: String
    
    var formattedAddress: String {
        var components = [String]()
        if !street.isEmpty { components.append(street) }
        if !city.isEmpty { components.append(city) }
        if !state.isEmpty { components.append(state) }
        if !postalCode.isEmpty { components.append(postalCode) }
        if !country.isEmpty { components.append(country) }
        
        return components.joined(separator: ", ")
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Organization: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var department: String
    var title: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 