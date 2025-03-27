package com.rehberyedek.app.data

import android.content.ContentProviderOperation
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.ContactsContract
import android.provider.ContactsContract.CommonDataKinds.Email
import android.provider.ContactsContract.CommonDataKinds.Phone
import android.provider.ContactsContract.CommonDataKinds.StructuredName
import android.provider.ContactsContract.CommonDataKinds.StructuredPostal
import android.provider.ContactsContract.CommonDataKinds.Organization
import android.provider.ContactsContract.Data
import android.provider.ContactsContract.RawContacts
import android.provider.OpenableColumns
import android.util.Log
import com.rehberyedek.app.model.Address
import com.rehberyedek.app.model.ContactModel
import com.rehberyedek.app.model.EmailAddress
import com.rehberyedek.app.model.PhoneNumber
import com.rehberyedek.app.model.Organization as ContactOrganization
import dagger.hilt.android.qualifiers.ApplicationContext
import ezvcard.Ezvcard
import ezvcard.VCard
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import java.io.File
import java.io.FileOutputStream
import javax.inject.Inject
import javax.inject.Singleton

sealed class ContactResult<out T> {
    data class Success<T>(val data: T) : ContactResult<T>()
    data class Error(val exception: Throwable) : ContactResult<Nothing>()
    object Loading : ContactResult<Nothing>()
}

@Singleton
class ContactsRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val contentResolver: ContentResolver = context.contentResolver
    private var cachedContacts: List<ContactModel>? = null
    
    // Kişileri getirme
    fun getAllContacts(): Flow<ContactResult<List<ContactModel>>> = flow {
        emit(ContactResult.Loading)
        try {
            val contacts = queryContacts()
            cachedContacts = contacts
            emit(ContactResult.Success(contacts))
        } catch (e: Exception) {
            Log.e("ContactsRepository", "Error fetching contacts", e)
            emit(ContactResult.Error(e))
        }
    }.flowOn(Dispatchers.IO)
    
    // Kişileri ID'ye göre getirme
    suspend fun getContactById(contactId: String): ContactResult<ContactModel> {
        return try {
            val contact = queryContactById(contactId)
            ContactResult.Success(contact)
        } catch (e: Exception) {
            Log.e("ContactsRepository", "Error fetching contact by ID: $contactId", e)
            ContactResult.Error(e)
        }
    }
    
    // vCard formatında dışa aktarma
    suspend fun exportContactsAsVCard(contactIds: List<String>): ContactResult<Uri> {
        return try {
            val contacts = contactIds.mapNotNull { id ->
                when (val result = getContactById(id)) {
                    is ContactResult.Success -> result.data
                    else -> null
                }
            }
            
            if (contacts.isEmpty()) {
                throw IllegalArgumentException("No contacts found with the provided IDs")
            }
            
            // EzVCard kullanarak vCard oluşturma
            val vcards = contacts.map { contact ->
                VCard().apply {
                    formattedName = contact.fullName
                    structuredName = ezvcard.property.StructuredName().apply {
                        given = contact.firstName
                        family = contact.lastName
                    }
                    
                    // Telefon numaraları
                    contact.phoneNumbers.forEach { phone ->
                        addTelephoneNumber(phone.number)
                    }
                    
                    // E-postalar
                    contact.emails.forEach { email ->
                        addEmail(email.address)
                    }
                    
                    // Adresler
                    contact.addresses.forEach { address ->
                        addAddress(ezvcard.property.Address().apply {
                            street = address.street
                            locality = address.city
                            region = address.state
                            postalCode = address.postalCode
                            country = address.country
                        })
                    }
                    
                    // Organizasyon
                    contact.organizations.firstOrNull()?.let { org ->
                        organization = ezvcard.property.Organization().apply {
                            values.add(org.name)
                            if (org.department.isNotEmpty()) {
                                values.add(org.department)
                            }
                        }
                        title = org.title
                    }
                }
            }
            
            // vCard içeriğini oluştur
            val vCardString = Ezvcard.write(vcards).go()
            
            // Geçici dosya oluştur
            val file = File(context.cacheDir, "contacts_export_${System.currentTimeMillis()}.vcf")
            FileOutputStream(file).use { it.write(vCardString.toByteArray()) }
            
            val uri = androidx.core.content.FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )
            
            ContactResult.Success(uri)
        } catch (e: Exception) {
            Log.e("ContactsRepository", "Error exporting contacts as vCard", e)
            ContactResult.Error(e)
        }
    }
    
    // vCard içe aktarma
    suspend fun importVCard(uri: Uri): ContactResult<Int> {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: throw IllegalStateException("Cannot open input stream")
            val vCards = Ezvcard.parse(inputStream).all()
            
            var importedCount = 0
            
            for (vCard in vCards) {
                val operations = ArrayList<ContentProviderOperation>()
                
                // Yeni kişi oluştur
                operations.add(
                    ContentProviderOperation.newInsert(RawContacts.CONTENT_URI)
                        .withValue(RawContacts.ACCOUNT_TYPE, null)
                        .withValue(RawContacts.ACCOUNT_NAME, null)
                        .build()
                )
                
                // İsim ekle
                val structuredName = vCard.structuredName
                operations.add(
                    ContentProviderOperation.newInsert(Data.CONTENT_URI)
                        .withValueBackReference(Data.RAW_CONTACT_ID, 0)
                        .withValue(Data.MIMETYPE, StructuredName.CONTENT_ITEM_TYPE)
                        .withValue(StructuredName.GIVEN_NAME, structuredName?.given ?: "")
                        .withValue(StructuredName.FAMILY_NAME, structuredName?.family ?: "")
                        .build()
                )
                
                // Telefon numaraları ekle
                for (telephone in vCard.telephoneNumbers) {
                    operations.add(
                        ContentProviderOperation.newInsert(Data.CONTENT_URI)
                            .withValueBackReference(Data.RAW_CONTACT_ID, 0)
                            .withValue(Data.MIMETYPE, Phone.CONTENT_ITEM_TYPE)
                            .withValue(Phone.NUMBER, telephone.text)
                            .withValue(Phone.TYPE, Phone.TYPE_MOBILE)
                            .build()
                    )
                }
                
                // E-postalar ekle
                for (email in vCard.emails) {
                    operations.add(
                        ContentProviderOperation.newInsert(Data.CONTENT_URI)
                            .withValueBackReference(Data.RAW_CONTACT_ID, 0)
                            .withValue(Data.MIMETYPE, Email.CONTENT_ITEM_TYPE)
                            .withValue(Email.ADDRESS, email.value)
                            .withValue(Email.TYPE, Email.TYPE_HOME)
                            .build()
                    )
                }
                
                // Adresler ekle
                for (address in vCard.addresses) {
                    operations.add(
                        ContentProviderOperation.newInsert(Data.CONTENT_URI)
                            .withValueBackReference(Data.RAW_CONTACT_ID, 0)
                            .withValue(Data.MIMETYPE, StructuredPostal.CONTENT_ITEM_TYPE)
                            .withValue(StructuredPostal.STREET, address.street)
                            .withValue(StructuredPostal.CITY, address.locality)
                            .withValue(StructuredPostal.REGION, address.region)
                            .withValue(StructuredPostal.POSTCODE, address.postalCode)
                            .withValue(StructuredPostal.COUNTRY, address.country)
                            .withValue(StructuredPostal.TYPE, StructuredPostal.TYPE_HOME)
                            .build()
                    )
                }
                
                // Organizasyon ekle
                if (vCard.organization != null) {
                    operations.add(
                        ContentProviderOperation.newInsert(Data.CONTENT_URI)
                            .withValueBackReference(Data.RAW_CONTACT_ID, 0)
                            .withValue(Data.MIMETYPE, Organization.CONTENT_ITEM_TYPE)
                            .withValue(Organization.COMPANY, vCard.organization.values.firstOrNull() ?: "")
                            .withValue(Organization.DEPARTMENT, vCard.organization.values.getOrNull(1) ?: "")
                            .withValue(Organization.TITLE, vCard.title?.value ?: "")
                            .build()
                    )
                }
                
                // Tüm işlemleri uygula
                contentResolver.applyBatch(ContactsContract.AUTHORITY, operations)
                importedCount++
            }
            
            // Önbelleği temizle
            cachedContacts = null
            
            ContactResult.Success(importedCount)
        } catch (e: Exception) {
            Log.e("ContactsRepository", "Error importing vCard", e)
            ContactResult.Error(e)
        }
    }
    
    // Kişileri birleştirme
    suspend fun mergeContacts(contactIds: List<String>): ContactResult<ContactModel> {
        if (contactIds.size < 2) {
            return ContactResult.Error(IllegalArgumentException("At least 2 contacts must be selected for merging"))
        }
        
        return try {
            // Birleştirilecek kişileri getir
            val contacts = contactIds.mapNotNull { id ->
                when (val result = getContactById(id)) {
                    is ContactResult.Success -> result.data
                    else -> null
                }
            }
            
            if (contacts.size < 2) {
                throw IllegalArgumentException("At least 2 valid contacts must be selected for merging")
            }
            
            // İlk kişiyi ana kişi olarak al
            val primaryContact = contacts[0]
            val duplicateContacts = contacts.drop(1)
            
            // Yeni birleştirilmiş veri setini oluştur
            val allPhoneNumbers = mutableListOf<PhoneNumber>()
            val allEmails = mutableListOf<EmailAddress>()
            val allAddresses = mutableListOf<Address>()
            val allOrganizations = mutableListOf<ContactOrganization>()
            
            // Ana kişinin verileri
            allPhoneNumbers.addAll(primaryContact.phoneNumbers)
            allEmails.addAll(primaryContact.emails)
            allAddresses.addAll(primaryContact.addresses)
            allOrganizations.addAll(primaryContact.organizations)
            
            // Diğer kişilerin verilerini ekle (yineleme olmadan)
            for (contact in duplicateContacts) {
                // Telefon numaraları
                for (phone in contact.phoneNumbers) {
                    if (allPhoneNumbers.none { it.number == phone.number }) {
                        allPhoneNumbers.add(phone)
                    }
                }
                
                // E-postalar
                for (email in contact.emails) {
                    if (allEmails.none { it.address == email.address }) {
                        allEmails.add(email)
                    }
                }
                
                // Adresler
                for (address in contact.addresses) {
                    if (allAddresses.none { it.formattedAddress == address.formattedAddress }) {
                        allAddresses.add(address)
                    }
                }
                
                // Organizasyon
                for (org in contact.organizations) {
                    if (allOrganizations.none { it.name == org.name }) {
                        allOrganizations.add(org)
                    }
                }
            }
            
            // Ana kişiyi güncelle
            val operations = ArrayList<ContentProviderOperation>()
            
            // Önce ana kişinin mevcut telefon, e-posta, adres ve organizasyon verilerini sil
            val where = "${Data.CONTACT_ID} = ? AND ${Data.MIMETYPE} = ?"
            val phoneWhere = arrayOf(primaryContact.id, Phone.CONTENT_ITEM_TYPE)
            val emailWhere = arrayOf(primaryContact.id, Email.CONTENT_ITEM_TYPE)
            val addressWhere = arrayOf(primaryContact.id, StructuredPostal.CONTENT_ITEM_TYPE)
            val orgWhere = arrayOf(primaryContact.id, Organization.CONTENT_ITEM_TYPE)
            
            operations.add(
                ContentProviderOperation.newDelete(Data.CONTENT_URI)
                    .withSelection(where, phoneWhere)
                    .build()
            )
            
            operations.add(
                ContentProviderOperation.newDelete(Data.CONTENT_URI)
                    .withSelection(where, emailWhere)
                    .build()
            )
            
            operations.add(
                ContentProviderOperation.newDelete(Data.CONTENT_URI)
                    .withSelection(where, addressWhere)
                    .build()
            )
            
            operations.add(
                ContentProviderOperation.newDelete(Data.CONTENT_URI)
                    .withSelection(where, orgWhere)
                    .build()
            )
            
            // Tüm telefon numaralarını ekle
            for (phone in allPhoneNumbers) {
                operations.add(
                    ContentProviderOperation.newInsert(Data.CONTENT_URI)
                        .withValue(Data.RAW_CONTACT_ID, getRawContactId(primaryContact.id))
                        .withValue(Data.MIMETYPE, Phone.CONTENT_ITEM_TYPE)
                        .withValue(Phone.NUMBER, phone.number)
                        .withValue(Phone.TYPE, phone.type)
                        .withValue(Phone.LABEL, phone.label)
                        .build()
                )
            }
            
            // Tüm e-postaları ekle
            for (email in allEmails) {
                operations.add(
                    ContentProviderOperation.newInsert(Data.CONTENT_URI)
                        .withValue(Data.RAW_CONTACT_ID, getRawContactId(primaryContact.id))
                        .withValue(Data.MIMETYPE, Email.CONTENT_ITEM_TYPE)
                        .withValue(Email.ADDRESS, email.address)
                        .withValue(Email.TYPE, email.type)
                        .withValue(Email.LABEL, email.label)
                        .build()
                )
            }
            
            // Tüm adresleri ekle
            for (address in allAddresses) {
                operations.add(
                    ContentProviderOperation.newInsert(Data.CONTENT_URI)
                        .withValue(Data.RAW_CONTACT_ID, getRawContactId(primaryContact.id))
                        .withValue(Data.MIMETYPE, StructuredPostal.CONTENT_ITEM_TYPE)
                        .withValue(StructuredPostal.STREET, address.street)
                        .withValue(StructuredPostal.CITY, address.city)
                        .withValue(StructuredPostal.REGION, address.state)
                        .withValue(StructuredPostal.POSTCODE, address.postalCode)
                        .withValue(StructuredPostal.COUNTRY, address.country)
                        .withValue(StructuredPostal.TYPE, address.type)
                        .withValue(StructuredPostal.LABEL, address.label)
                        .build()
                )
            }
            
            // Organizasyon bilgilerini ekle
            for (org in allOrganizations) {
                operations.add(
                    ContentProviderOperation.newInsert(Data.CONTENT_URI)
                        .withValue(Data.RAW_CONTACT_ID, getRawContactId(primaryContact.id))
                        .withValue(Data.MIMETYPE, Organization.CONTENT_ITEM_TYPE)
                        .withValue(Organization.COMPANY, org.name)
                        .withValue(Organization.DEPARTMENT, org.department)
                        .withValue(Organization.TITLE, org.title)
                        .build()
                )
            }
            
            // Yinelenen kişileri sil
            for (contact in duplicateContacts) {
                operations.add(
                    ContentProviderOperation.newDelete(ContactsContract.Contacts.CONTENT_URI)
                        .withSelection("${ContactsContract.Contacts._ID} = ?", arrayOf(contact.id))
                        .build()
                )
            }
            
            // Tüm işlemleri uygula
            contentResolver.applyBatch(ContactsContract.AUTHORITY, operations)
            
            // Önbelleği temizle
            cachedContacts = null
            
            // Güncellenmiş kişiyi getir
            val updatedContact = queryContactById(primaryContact.id)
            ContactResult.Success(updatedContact)
        } catch (e: Exception) {
            Log.e("ContactsRepository", "Error merging contacts", e)
            ContactResult.Error(e)
        }
    }
    
    // Dosya adını URI'dan alma
    fun getFileName(uri: Uri): String {
        var result: String? = null
        if (uri.scheme == "content") {
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index != -1) {
                        result = it.getString(index)
                    }
                }
            }
        }
        if (result == null) {
            result = uri.path
            val cut = result?.lastIndexOf('/')
            if (cut != -1) {
                result = result?.substring(cut!! + 1)
            }
        }
        return result ?: "unknown"
    }
    
    // Yardımcı metotlar
    private fun queryContacts(): List<ContactModel> {
        val contacts = mutableListOf<ContactModel>()
        val uri = ContactsContract.Contacts.CONTENT_URI
        val projection = arrayOf(
            ContactsContract.Contacts._ID,
            ContactsContract.Contacts.DISPLAY_NAME,
            ContactsContract.Contacts.HAS_PHONE_NUMBER
        )
        val selection = "${ContactsContract.Contacts.HAS_PHONE_NUMBER} > 0"
        
        contentResolver.query(uri, projection, selection, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts._ID))
                val displayName = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME)) ?: ""
                
                // İsim bileşenlerini ayırma
                val (firstName, lastName) = splitName(displayName)
                
                // Telefon numaralarını getirme
                val phoneNumbers = getPhoneNumbers(id)
                
                // E-postaları getirme
                val emails = getEmails(id)
                
                // Adresleri getirme
                val addresses = getAddresses(id)
                
                // Organizasyon bilgilerini getirme
                val organizations = getOrganizations(id)
                
                // Fotoğrafı getirme
                val photo = getContactPhoto(id)
                
                contacts.add(
                    ContactModel(
                        id = id,
                        firstName = firstName,
                        lastName = lastName,
                        phoneNumbers = phoneNumbers,
                        emails = emails,
                        addresses = addresses,
                        organizations = organizations,
                        photo = photo
                    )
                )
            }
        }
        
        return contacts
    }
    
    private fun queryContactById(contactId: String): ContactModel {
        val uri = ContactsContract.Contacts.CONTENT_URI
        val projection = arrayOf(
            ContactsContract.Contacts._ID,
            ContactsContract.Contacts.DISPLAY_NAME
        )
        val selection = "${ContactsContract.Contacts._ID} = ?"
        val selectionArgs = arrayOf(contactId)
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val displayName = cursor.getString(cursor.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME)) ?: ""
                
                // İsim bileşenlerini ayırma
                val (firstName, lastName) = splitName(displayName)
                
                // Telefon numaralarını getirme
                val phoneNumbers = getPhoneNumbers(contactId)
                
                // E-postaları getirme
                val emails = getEmails(contactId)
                
                // Adresleri getirme
                val addresses = getAddresses(contactId)
                
                // Organizasyon bilgilerini getirme
                val organizations = getOrganizations(contactId)
                
                // Fotoğrafı getirme
                val photo = getContactPhoto(contactId)
                
                return ContactModel(
                    id = contactId,
                    firstName = firstName,
                    lastName = lastName,
                    phoneNumbers = phoneNumbers,
                    emails = emails,
                    addresses = addresses,
                    organizations = organizations,
                    photo = photo
                )
            }
        }
        
        throw IllegalArgumentException("Contact not found with ID: $contactId")
    }
    
    private fun splitName(displayName: String): Pair<String, String> {
        val nameParts = displayName.trim().split("\\s+".toRegex(), 2)
        val firstName = nameParts.firstOrNull() ?: ""
        val lastName = if (nameParts.size > 1) nameParts[1] else ""
        return Pair(firstName, lastName)
    }
    
    private fun getPhoneNumbers(contactId: String): List<PhoneNumber> {
        val phoneNumbers = mutableListOf<PhoneNumber>()
        val uri = Phone.CONTENT_URI
        val projection = arrayOf(
            Phone.NUMBER,
            Phone.TYPE,
            Phone.LABEL
        )
        val selection = "${Phone.CONTACT_ID} = ?"
        val selectionArgs = arrayOf(contactId)
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val number = cursor.getString(cursor.getColumnIndexOrThrow(Phone.NUMBER))
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(Phone.TYPE))
                val label = cursor.getString(cursor.getColumnIndexOrThrow(Phone.LABEL)) ?: ""
                
                phoneNumbers.add(PhoneNumber(number, label, type))
            }
        }
        
        return phoneNumbers
    }
    
    private fun getEmails(contactId: String): List<EmailAddress> {
        val emails = mutableListOf<EmailAddress>()
        val uri = Email.CONTENT_URI
        val projection = arrayOf(
            Email.ADDRESS,
            Email.TYPE,
            Email.LABEL
        )
        val selection = "${Email.CONTACT_ID} = ?"
        val selectionArgs = arrayOf(contactId)
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val address = cursor.getString(cursor.getColumnIndexOrThrow(Email.ADDRESS))
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(Email.TYPE))
                val label = cursor.getString(cursor.getColumnIndexOrThrow(Email.LABEL)) ?: ""
                
                emails.add(EmailAddress(address, label, type))
            }
        }
        
        return emails
    }
    
    private fun getAddresses(contactId: String): List<Address> {
        val addresses = mutableListOf<Address>()
        val uri = StructuredPostal.CONTENT_URI
        val projection = arrayOf(
            StructuredPostal.STREET,
            StructuredPostal.CITY,
            StructuredPostal.REGION,
            StructuredPostal.POSTCODE,
            StructuredPostal.COUNTRY,
            StructuredPostal.TYPE,
            StructuredPostal.LABEL
        )
        val selection = "${StructuredPostal.CONTACT_ID} = ?"
        val selectionArgs = arrayOf(contactId)
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val street = cursor.getString(cursor.getColumnIndexOrThrow(StructuredPostal.STREET)) ?: ""
                val city = cursor.getString(cursor.getColumnIndexOrThrow(StructuredPostal.CITY)) ?: ""
                val state = cursor.getString(cursor.getColumnIndexOrThrow(StructuredPostal.REGION)) ?: ""
                val postalCode = cursor.getString(cursor.getColumnIndexOrThrow(StructuredPostal.POSTCODE)) ?: ""
                val country = cursor.getString(cursor.getColumnIndexOrThrow(StructuredPostal.COUNTRY)) ?: ""
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(StructuredPostal.TYPE))
                val label = cursor.getString(cursor.getColumnIndexOrThrow(StructuredPostal.LABEL)) ?: ""
                
                addresses.add(Address(street, city, state, postalCode, country, label, type))
            }
        }
        
        return addresses
    }
    
    private fun getOrganizations(contactId: String): List<ContactOrganization> {
        val organizations = mutableListOf<ContactOrganization>()
        val uri = Data.CONTENT_URI
        val projection = arrayOf(
            Organization.COMPANY,
            Organization.DEPARTMENT,
            Organization.TITLE
        )
        val selection = "${Data.CONTACT_ID} = ? AND ${Data.MIMETYPE} = ?"
        val selectionArgs = arrayOf(contactId, Organization.CONTENT_ITEM_TYPE)
        
        contentResolver.query(uri, projection, selection, selectionArgs, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val company = cursor.getString(cursor.getColumnIndexOrThrow(Organization.COMPANY)) ?: ""
                val department = cursor.getString(cursor.getColumnIndexOrThrow(Organization.DEPARTMENT)) ?: ""
                val title = cursor.getString(cursor.getColumnIndexOrThrow(Organization.TITLE)) ?: ""
                
                if (company.isNotEmpty()) {
                    organizations.add(ContactOrganization(company, department, title))
                }
            }
        }
        
        return organizations
    }
    
    private fun getContactPhoto(contactId: String): android.graphics.Bitmap? {
        val contactUri = ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, contactId.toLong())
        val photoUri = Uri.withAppendedPath(contactUri, ContactsContract.Contacts.Photo.CONTENT_DIRECTORY)
        
        var photo: android.graphics.Bitmap? = null
        
        try {
            val cursor = contentResolver.query(
                photoUri,
                arrayOf(ContactsContract.Contacts.Photo.PHOTO),
                null, null, null
            )
            
            if (cursor?.moveToFirst() == true) {
                val photoColumnIndex = cursor.getColumnIndex(ContactsContract.Contacts.Photo.PHOTO)
                if (photoColumnIndex != -1) {
                    val photoBlob = cursor.getBlob(photoColumnIndex)
                    if (photoBlob != null) {
                        photo = BitmapFactory.decodeByteArray(photoBlob, 0, photoBlob.size)
                    }
                }
            }
            cursor?.close()
        } catch (e: Exception) {
            Log.e("ContactsRepository", "Error loading contact photo", e)
        }
        
        return photo
    }
    
    private fun getRawContactId(contactId: String): String? {
        val cursor = contentResolver.query(
            RawContacts.CONTENT_URI,
            arrayOf(RawContacts._ID),
            "${RawContacts.CONTACT_ID} = ?",
            arrayOf(contactId),
            null
        )
        
        var rawContactId: String? = null
        if (cursor?.moveToFirst() == true) {
            rawContactId = cursor.getString(cursor.getColumnIndexOrThrow(RawContacts._ID))
        }
        cursor?.close()
        
        return rawContactId
    }
    
    // Yinelenen kişileri bulma
    fun findDuplicateContacts(): Flow<ContactResult<List<List<ContactModel>>>> = flow {
        emit(ContactResult.Loading)
        try {
            val contacts = cachedContacts ?: queryContacts()
            val duplicateGroups = mutableListOf<List<ContactModel>>()
            
            // İsim bazlı yinelemeler
            val nameGroups = contacts.groupBy { it.fullName }
                .filter { it.key.isNotEmpty() && it.value.size > 1 }
                .map { it.value }
            
            duplicateGroups.addAll(nameGroups)
            
            // Telefon numarası bazlı yinelemeler
            val phoneMap = mutableMapOf<String, MutableList<ContactModel>>()
            
            for (contact in contacts) {
                for (phone in contact.phoneNumbers) {
                    val normalizedNumber = normalizePhoneNumber(phone.number)
                    if (normalizedNumber.isNotEmpty()) {
                        phoneMap.getOrPut(normalizedNumber) { mutableListOf() }.add(contact)
                    }
                }
            }
            
            val phoneGroups = phoneMap.values
                .filter { it.size > 1 }
                .map { group -> group.distinctBy { it.id } }
                .filter { it.size > 1 }
            
            // Aynı kişi gruplarını filtreleme
            for (group in phoneGroups) {
                val ids = group.map { it.id }.toSet()
                val alreadyExists = duplicateGroups.any { existingGroup ->
                    existingGroup.map { it.id }.toSet() == ids
                }
                
                if (!alreadyExists) {
                    duplicateGroups.add(group)
                }
            }
            
            emit(ContactResult.Success(duplicateGroups))
        } catch (e: Exception) {
            Log.e("ContactsRepository", "Error finding duplicate contacts", e)
            emit(ContactResult.Error(e))
        }
    }.flowOn(Dispatchers.IO)
    
    private fun normalizePhoneNumber(phoneNumber: String): String {
        return phoneNumber.replace(Regex("[^0-9]"), "")
    }
} 