package com.rehberyedek.app.ui.import

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.rehberyedek.app.data.ContactResult
import com.rehberyedek.app.data.ContactsRepository
import com.rehberyedek.app.model.ContactFormat
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ImportViewModel @Inject constructor(
    private val contactsRepository: ContactsRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(ImportUiState())
    val uiState: StateFlow<ImportUiState> = _uiState.asStateFlow()
    
    fun updateSelectedFormat(format: ContactFormat) {
        _uiState.update { it.copy(selectedFormat = format) }
    }
    
    fun importContacts(uri: Uri) {
        // Dosya adını al
        val fileName = contactsRepository.getFileName(uri)
        
        // Sadece seçili formata uygun dosyaları kabul et
        val isValidFormat = when (_uiState.value.selectedFormat) {
            ContactFormat.VCARD -> fileName.endsWith(".vcf", ignoreCase = true)
            ContactFormat.CSV -> fileName.endsWith(".csv", ignoreCase = true)
            ContactFormat.EXCEL -> fileName.endsWith(".xlsx", ignoreCase = true) || fileName.endsWith(".xls", ignoreCase = true)
            ContactFormat.JSON -> fileName.endsWith(".json", ignoreCase = true)
            ContactFormat.PDF -> fileName.endsWith(".pdf", ignoreCase = true)
        }
        
        if (!isValidFormat) {
            _uiState.update { 
                it.copy(
                    error = "Seçilen dosya '${_uiState.value.selectedFormat.name.lowercase()}' formatına uygun değil"
                )
            }
            return
        }
        
        // Şu an için sadece vCard formatını destekliyoruz
        if (_uiState.value.selectedFormat != ContactFormat.VCARD) {
            _uiState.update { 
                it.copy(
                    error = "Şu anda sadece vCard (.vcf) formatı desteklenmektedir"
                )
            }
            return
        }
        
        viewModelScope.launch {
            _uiState.update { it.copy(importState = ImportState.LOADING, error = null) }
            
            when (val result = contactsRepository.importVCard(uri)) {
                is ContactResult.Success -> {
                    if (result.data > 0) {
                        _uiState.update { 
                            it.copy(
                                importState = ImportState.SUCCESS,
                                importedCount = result.data,
                                error = null
                            )
                        }
                    } else {
                        _uiState.update {
                            it.copy(
                                importState = ImportState.ERROR,
                                error = "İçe aktarılacak kişi bulunamadı"
                            )
                        }
                    }
                }
                is ContactResult.Error -> {
                    _uiState.update {
                        it.copy(
                            importState = ImportState.ERROR,
                            error = result.exception.localizedMessage ?: "İçe aktarma hatası"
                        )
                    }
                }
                else -> {} // Loading state is already set
            }
        }
    }
    
    fun resetImportState() {
        _uiState.update { it.copy(importState = ImportState.INITIAL, error = null) }
    }
    
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}

data class ImportUiState(
    val selectedFormat: ContactFormat = ContactFormat.VCARD,
    val importState: ImportState = ImportState.INITIAL,
    val importedCount: Int = 0,
    val error: String? = null
)

enum class ImportState {
    INITIAL,
    LOADING,
    SUCCESS,
    ERROR
} 