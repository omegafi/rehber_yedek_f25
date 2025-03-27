package com.rehberyedek.app.ui.home

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.rehberyedek.app.data.ContactResult
import com.rehberyedek.app.data.ContactsRepository
import com.rehberyedek.app.model.ContactModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HomeViewModel @Inject constructor(
    private val contactsRepository: ContactsRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()
    
    init {
        loadContacts()
    }
    
    fun loadContacts() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            
            contactsRepository.getAllContacts().collect { result ->
                when (result) {
                    is ContactResult.Loading -> {
                        _uiState.update { it.copy(isLoading = true) }
                    }
                    is ContactResult.Success -> {
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                contacts = result.data,
                                filteredContacts = filterContacts(result.data, it.searchQuery),
                                error = null
                            )
                        }
                    }
                    is ContactResult.Error -> {
                        _uiState.update { 
                            it.copy(
                                isLoading = false, 
                                error = result.exception.localizedMessage ?: "Bilinmeyen hata" 
                            )
                        }
                    }
                }
            }
        }
    }
    
    fun toggleContactSelection(contactId: String) {
        val selectedContactIds = _uiState.value.selectedContactIds.toMutableSet()
        
        if (selectedContactIds.contains(contactId)) {
            selectedContactIds.remove(contactId)
        } else {
            selectedContactIds.add(contactId)
        }
        
        _uiState.update { it.copy(selectedContactIds = selectedContactIds) }
    }
    
    fun toggleSelectAll() {
        val currentState = _uiState.value
        
        if (currentState.selectedContactIds.size == currentState.filteredContacts.size) {
            // Tüm seçimleri kaldır
            _uiState.update { it.copy(selectedContactIds = emptySet()) }
        } else {
            // Tümünü seç
            _uiState.update { 
                it.copy(selectedContactIds = it.filteredContacts.map { contact -> contact.id }.toSet())
            }
        }
    }
    
    fun clearSelection() {
        _uiState.update { it.copy(selectedContactIds = emptySet()) }
    }
    
    fun updateSearchQuery(query: String) {
        _uiState.update { 
            it.copy(
                searchQuery = query, 
                filteredContacts = filterContacts(it.contacts, query)
            )
        }
    }
    
    private fun filterContacts(contacts: List<ContactModel>, query: String): List<ContactModel> {
        if (query.isBlank()) {
            return contacts
        }
        
        val lowercaseQuery = query.lowercase()
        
        return contacts.filter { contact ->
            val fullName = contact.fullName.lowercase()
            val phones = contact.phoneNumbers.joinToString { it.number.lowercase() }
            val emails = contact.emails.joinToString { it.address.lowercase() }
            
            fullName.contains(lowercaseQuery) || 
                    phones.contains(lowercaseQuery) || 
                    emails.contains(lowercaseQuery)
        }
    }
    
    fun exportSelectedContacts() {
        val selectedIds = _uiState.value.selectedContactIds.toList()
        if (selectedIds.isEmpty()) return
        
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            
            when (val result = contactsRepository.exportContactsAsVCard(selectedIds)) {
                is ContactResult.Success -> {
                    _uiState.update { 
                        it.copy(
                            isLoading = false,
                            exportFileUri = result.data
                        )
                    }
                }
                is ContactResult.Error -> {
                    _uiState.update { 
                        it.copy(
                            isLoading = false,
                            error = result.exception.localizedMessage ?: "Dışa aktarma hatası"
                        )
                    }
                }
                else -> {}
            }
        }
    }
    
    fun clearExportFileUri() {
        _uiState.update { it.copy(exportFileUri = null) }
    }
    
    fun mergeSelectedContacts() {
        val selectedIds = _uiState.value.selectedContactIds.toList()
        if (selectedIds.size < 2) return
        
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            
            when (val result = contactsRepository.mergeContacts(selectedIds)) {
                is ContactResult.Success -> {
                    loadContacts()
                    _uiState.update { 
                        it.copy(
                            selectedContactIds = emptySet(),
                            showMergeSuccess = true
                        )
                    }
                }
                is ContactResult.Error -> {
                    _uiState.update { 
                        it.copy(
                            isLoading = false,
                            error = result.exception.localizedMessage ?: "Birleştirme hatası"
                        )
                    }
                }
                else -> {}
            }
        }
    }
    
    fun clearMergeSuccessFlag() {
        _uiState.update { it.copy(showMergeSuccess = false) }
    }
    
    fun loadDuplicateContacts() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingDuplicates = true, error = null) }
            
            contactsRepository.findDuplicateContacts().collect { result ->
                when (result) {
                    is ContactResult.Loading -> {
                        _uiState.update { it.copy(isLoadingDuplicates = true) }
                    }
                    is ContactResult.Success -> {
                        _uiState.update { 
                            it.copy(
                                isLoadingDuplicates = false,
                                duplicateGroups = result.data,
                                error = null
                            )
                        }
                    }
                    is ContactResult.Error -> {
                        _uiState.update { 
                            it.copy(
                                isLoadingDuplicates = false, 
                                error = result.exception.localizedMessage ?: "Yinelenen kişileri bulma hatası" 
                            )
                        }
                    }
                }
            }
        }
    }
    
    fun selectDuplicateGroupForMerge(group: List<ContactModel>) {
        val ids = group.map { it.id }.toSet()
        _uiState.update { it.copy(selectedContactIds = ids) }
    }
}

data class HomeUiState(
    val isLoading: Boolean = false,
    val isLoadingDuplicates: Boolean = false,
    val contacts: List<ContactModel> = emptyList(),
    val filteredContacts: List<ContactModel> = emptyList(),
    val selectedContactIds: Set<String> = emptySet(),
    val searchQuery: String = "",
    val duplicateGroups: List<List<ContactModel>> = emptyList(),
    val error: String? = null,
    val exportFileUri: Uri? = null,
    val showMergeSuccess: Boolean = false
) 