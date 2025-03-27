package com.rehberyedek.app.model

import android.graphics.Bitmap
import android.provider.ContactsContract

data class ContactModel(
    val id: String,
    val firstName: String = "",
    val lastName: String = "",
    val phoneNumbers: List<PhoneNumber> = emptyList(),
    val emails: List<EmailAddress> = emptyList(),
    val addresses: List<Address> = emptyList(),
    val organizations: List<Organization> = emptyList(),
    val photo: Bitmap? = null
) {
    val fullName: String
        get() {
            val name = listOf(firstName, lastName).filter { it.isNotEmpty() }.joinToString(" ")
            return if (name.isEmpty()) "İsimsiz Kişi" else name
        }
    
    // Yardımcı sınıflar ve metotlar
    companion object {
        fun fromContentUri(id: String, firstName: String, lastName: String, phoneNumbers: List<PhoneNumber>): ContactModel {
            return ContactModel(
                id = id,
                firstName = firstName,
                lastName = lastName,
                phoneNumbers = phoneNumbers
            )
        }
    }
}

data class PhoneNumber(
    val number: String,
    val label: String = "",
    val type: Int = ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE
)

data class EmailAddress(
    val address: String,
    val label: String = "",
    val type: Int = ContactsContract.CommonDataKinds.Email.TYPE_HOME
)

data class Address(
    val street: String = "",
    val city: String = "",
    val state: String = "",
    val postalCode: String = "",
    val country: String = "",
    val label: String = "",
    val type: Int = ContactsContract.CommonDataKinds.StructuredPostal.TYPE_HOME
) {
    val formattedAddress: String
        get() {
            val components = mutableListOf<String>()
            if (street.isNotEmpty()) components.add(street)
            if (city.isNotEmpty()) components.add(city)
            if (state.isNotEmpty()) components.add(state)
            if (postalCode.isNotEmpty()) components.add(postalCode)
            if (country.isNotEmpty()) components.add(country)
            
            return components.joinToString(", ")
        }
}

data class Organization(
    val name: String,
    val department: String = "",
    val title: String = ""
)

enum class ContactFormat {
    VCARD,
    CSV,
    EXCEL,
    JSON,
    PDF
} 