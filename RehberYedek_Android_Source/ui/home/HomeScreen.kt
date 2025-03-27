package com.rehberyedek.app.ui.home

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Merge
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.core.content.FileProvider
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavController
import com.rehberyedek.app.model.ContactModel
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    navController: NavController,
    viewModel: HomeViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()
    
    var showMergeDialog by remember { mutableStateOf(false) }
    var showExportDialog by remember { mutableStateOf(false) }
    var showDuplicatesDialog by remember { mutableStateOf(false) }
    
    val context = LocalContext.current
    
    // Kişi birleştirme başarı mesajı
    LaunchedEffect(uiState.showMergeSuccess) {
        if (uiState.showMergeSuccess) {
            coroutineScope.launch {
                snackbarHostState.showSnackbar("Kişiler başarıyla birleştirildi")
                viewModel.clearMergeSuccessFlag()
            }
        }
    }
    
    // Hata mesajı
    LaunchedEffect(uiState.error) {
        if (uiState.error != null) {
            coroutineScope.launch {
                snackbarHostState.showSnackbar(uiState.error!!)
            }
        }
    }
    
    // Dışa aktarma işlemi tamamlandığında paylaşım ekranını göster
    LaunchedEffect(uiState.exportFileUri) {
        if (uiState.exportFileUri != null) {
            val fileUri = uiState.exportFileUri!!
            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "text/x-vcard"
                putExtra(Intent.EXTRA_STREAM, fileUri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(shareIntent, "Kişileri Paylaş"))
            viewModel.clearExportFileUri()
        }
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Rehber Yedek") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    titleContentColor = MaterialTheme.colorScheme.onPrimaryContainer
                ),
                actions = {
                    IconButton(onClick = {
                        viewModel.loadDuplicateContacts()
                        showDuplicatesDialog = true
                    }) {
                        Icon(
                            imageVector = Icons.Default.Person,
                            contentDescription = "Yinelenen Kişiler"
                        )
                    }
                    
                    IconButton(onClick = { 
                        navController.navigate("import") 
                    }) {
                        Icon(
                            imageVector = Icons.Default.Search,
                            contentDescription = "İçe Aktar"
                        )
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) },
        floatingActionButton = {
            if (uiState.selectedContactIds.size > 1) {
                FloatingActionButton(
                    onClick = { showMergeDialog = true },
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                ) {
                    Icon(
                        imageVector = Icons.Default.Merge,
                        contentDescription = "Kişileri Birleştir"
                    )
                }
            }
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            // Arama çubuğu
            SearchBar(
                searchQuery = uiState.searchQuery,
                onSearchQueryChange = { viewModel.updateSearchQuery(it) }
            )
            
            // Seçim kontrolü
            if (uiState.selectedContactIds.isNotEmpty()) {
                SelectionControlBar(
                    selectedCount = uiState.selectedContactIds.size,
                    onClearSelection = { viewModel.clearSelection() },
                    onExport = { showExportDialog = true },
                    onMerge = { 
                        if (uiState.selectedContactIds.size > 1) showMergeDialog = true 
                    }
                )
            }
            
            // Kişiler listesi
            if (uiState.isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            } else if (uiState.filteredContacts.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = if (uiState.searchQuery.isNotEmpty()) 
                                "Aramanızla eşleşen kişi bulunamadı" 
                            else
                                "Henüz kişi bulunmuyor",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize()
                ) {
                    item {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 8.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "${uiState.filteredContacts.size} kişi",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            
                            TextButton(onClick = { viewModel.toggleSelectAll() }) {
                                Text(
                                    text = if (uiState.selectedContactIds.size == uiState.filteredContacts.size) 
                                            "Seçimi Kaldır" 
                                        else 
                                            "Tümünü Seç"
                                )
                            }
                        }
                    }
                    
                    items(uiState.filteredContacts) { contact ->
                        ContactItem(
                            contact = contact,
                            isSelected = uiState.selectedContactIds.contains(contact.id),
                            onClick = { viewModel.toggleContactSelection(contact.id) }
                        )
                    }
                }
            }
        }
    }
    
    // Birleştirme onay iletişim kutusu
    if (showMergeDialog) {
        AlertDialog(
            onDismissRequest = { showMergeDialog = false },
            title = { Text("Kişileri Birleştir") },
            text = { 
                Text("Seçilen ${uiState.selectedContactIds.size} kişiyi birleştirmek istediğinize emin misiniz?")
            },
            confirmButton = {
                Button(
                    onClick = {
                        viewModel.mergeSelectedContacts()
                        showMergeDialog = false
                    }
                ) {
                    Text("Birleştir")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { showMergeDialog = false }
                ) {
                    Text("İptal")
                }
            }
        )
    }
    
    // Dışa aktarma seçenekleri iletişim kutusu
    if (showExportDialog) {
        Dialog(onDismissRequest = { showExportDialog = false }) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                shape = RoundedCornerShape(16.dp)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = "Dışa Aktarma Formatı",
                        style = MaterialTheme.typography.titleLarge
                    )
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    Button(
                        onClick = {
                            viewModel.exportSelectedContacts()
                            showExportDialog = false
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("vCard (.vcf)")
                    }
                    
                    Spacer(modifier = Modifier.height(8.dp))
                    
                    OutlinedButton(
                        onClick = { showExportDialog = false },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("İptal")
                    }
                }
            }
        }
    }
    
    // Yinelenen kişiler iletişim kutusu
    if (showDuplicatesDialog) {
        Dialog(onDismissRequest = { showDuplicatesDialog = false }) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(500.dp)
                    .padding(16.dp),
                shape = RoundedCornerShape(16.dp)
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Yinelenen Kişiler",
                            style = MaterialTheme.typography.titleLarge
                        )
                        
                        IconButton(onClick = { showDuplicatesDialog = false }) {
                            Icon(
                                imageVector = Icons.Default.Clear,
                                contentDescription = "Kapat"
                            )
                        }
                    }
                    
                    Spacer(modifier = Modifier.height(8.dp))
                    
                    if (uiState.isLoadingDuplicates) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator()
                        }
                    } else if (uiState.duplicateGroups.isEmpty()) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Icon(
                                    imageVector = Icons.Default.CheckCircle,
                                    contentDescription = null,
                                    modifier = Modifier.size(64.dp),
                                    tint = MaterialTheme.colorScheme.primary
                                )
                                
                                Spacer(modifier = Modifier.height(16.dp))
                                
                                Text(
                                    text = "Yinelenen kişi bulunamadı",
                                    style = MaterialTheme.typography.bodyLarge
                                )
                            }
                        }
                    } else {
                        LazyColumn {
                            uiState.duplicateGroups.forEachIndexed { index, group ->
                                item {
                                    Text(
                                        text = "Grup ${index + 1}",
                                        style = MaterialTheme.typography.titleMedium,
                                        modifier = Modifier.padding(vertical = 8.dp)
                                    )
                                }
                                
                                items(group) { contact ->
                                    DuplicateContactItem(contact = contact)
                                }
                                
                                item {
                                    Button(
                                        onClick = {
                                            viewModel.selectDuplicateGroupForMerge(group)
                                            showDuplicatesDialog = false
                                            showMergeDialog = true
                                        },
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(vertical = 8.dp)
                                    ) {
                                        Text("Bu Grubu Birleştir")
                                    }
                                    
                                    Divider(modifier = Modifier.padding(vertical = 8.dp))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SearchBar(
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit
) {
    TextField(
        value = searchQuery,
        onValueChange = onSearchQueryChange,
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        placeholder = { Text("Rehberde Ara") },
        leadingIcon = {
            Icon(
                imageVector = Icons.Default.Search,
                contentDescription = "Ara"
            )
        },
        trailingIcon = {
            if (searchQuery.isNotEmpty()) {
                IconButton(onClick = { onSearchQueryChange("") }) {
                    Icon(
                        imageVector = Icons.Default.Clear,
                        contentDescription = "Temizle"
                    )
                }
            }
        },
        singleLine = true,
        shape = RoundedCornerShape(50)
    )
}

@Composable
fun SelectionControlBar(
    selectedCount: Int,
    onClearSelection: () -> Unit,
    onExport: () -> Unit,
    onMerge: () -> Unit
) {
    Surface(
        color = MaterialTheme.colorScheme.primaryContainer,
        tonalElevation = 2.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "$selectedCount kişi seçildi",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )
            
            Row {
                IconButton(onClick = onClearSelection) {
                    Icon(
                        imageVector = Icons.Default.Clear,
                        contentDescription = "Seçimi Temizle",
                        tint = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
                
                IconButton(onClick = onExport) {
                    Icon(
                        imageVector = Icons.Default.Share,
                        contentDescription = "Dışa Aktar",
                        tint = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
                
                IconButton(
                    onClick = onMerge,
                    enabled = selectedCount > 1
                ) {
                    Icon(
                        imageVector = Icons.Default.Merge,
                        contentDescription = "Birleştir",
                        tint = if (selectedCount > 1) 
                            MaterialTheme.colorScheme.onPrimaryContainer 
                        else 
                            MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.5f)
                    )
                }
            }
        }
    }
}

@Composable
fun ContactItem(
    contact: ContactModel,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Avatar
        ContactAvatar(contact)
        
        Spacer(modifier = Modifier.width(16.dp))
        
        // Kişi bilgileri
        Column(
            modifier = Modifier.weight(1f)
        ) {
            Text(
                text = contact.fullName,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold
            )
            
            if (contact.phoneNumbers.isNotEmpty()) {
                Text(
                    text = contact.phoneNumbers.first().number,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        
        // Seçim durumu
        Icon(
            imageVector = if (isSelected) Icons.Default.CheckCircle else Icons.Default.Circle,
            contentDescription = if (isSelected) "Seçili" else "Seçili Değil",
            tint = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outline,
            modifier = Modifier.size(24.dp)
        )
    }
}

@Composable
fun ContactAvatar(contact: ContactModel) {
    val initials = contact.firstName.take(1) + contact.lastName.take(1)
    val backgroundColor = when ((contact.id.hashCode() % 6)) {
        0 -> Color(0xFF1A73E8) // Blue
        1 -> Color(0xFF34A853) // Green
        2 -> Color(0xFFFBBC04) // Yellow
        3 -> Color(0xFFEA4335) // Red
        4 -> Color(0xFF9C27B0) // Purple
        else -> Color(0xFF607D8B) // Blue gray
    }
    
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(CircleShape)
            .background(backgroundColor),
        contentAlignment = Alignment.Center
    ) {
        if (contact.photo != null) {
            // TODO: Image composable'ı kullanarak fotoğrafı göster
        } else {
            Text(
                text = initials.uppercase(),
                color = Color.White,
                style = MaterialTheme.typography.titleMedium
            )
        }
    }
}

@Composable
fun DuplicateContactItem(contact: ContactModel) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically
        ) {
            ContactAvatar(contact)
            
            Spacer(modifier = Modifier.width(16.dp))
            
            Text(
                text = contact.fullName,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold
            )
        }
        
        // Telefon numaraları
        contact.phoneNumbers.forEach { phone ->
            Row(
                modifier = Modifier.padding(start = 56.dp, top = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Phone,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Spacer(modifier = Modifier.width(8.dp))
                
                Text(
                    text = phone.number,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        
        // E-postalar
        contact.emails.forEach { email ->
            Row(
                modifier = Modifier.padding(start = 56.dp, top = 4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Email,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Spacer(modifier = Modifier.width(8.dp))
                
                Text(
                    text = email.address,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
} 