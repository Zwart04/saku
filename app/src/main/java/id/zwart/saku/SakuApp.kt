package id.zwart.saku

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationManagerCompat
import id.zwart.saku.ai.AgentResult
import id.zwart.saku.ai.MoneyAgent
import id.zwart.saku.data.ChartKind
import id.zwart.saku.data.DashboardCard
import id.zwart.saku.data.Expense
import id.zwart.saku.data.ExpenseRepository
import id.zwart.saku.data.PendingExpense
import id.zwart.saku.data.defaultDashboard
import id.zwart.saku.storage.FolderStore
import id.zwart.saku.storage.Prefs
import id.zwart.saku.ui.ChartView
import id.zwart.saku.ui.Mascot
import id.zwart.saku.ui.Mood
import id.zwart.saku.ui.SakuColors
import id.zwart.saku.ui.SakuTheme
import id.zwart.saku.voice.VoiceInput
import kotlinx.coroutines.launch

data class ChatMessage(val fromAgent: Boolean, val text: String)

private fun notifAccessGranted(context: Context): Boolean =
    NotificationManagerCompat.getEnabledListenerPackages(context)
        .contains(context.packageName)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppRoot() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val store = remember { FolderStore(context) }
    val prefs = remember { Prefs(context) }
    val repo = remember { ExpenseRepository(store) }
    val voice = remember { VoiceInput(context) }

    var tab by rememberSaveable { mutableIntStateOf(0) }
    var ready by remember { mutableStateOf(store.isReady()) }
    var expenses by remember { mutableStateOf(emptyList<Expense>()) }
    var pending by remember { mutableStateOf(emptyList<PendingExpense>()) }
    var cards by remember { mutableStateOf(defaultDashboard()) }
    var chats by remember {
        mutableStateOf(
            listOf(
                ChatMessage(
                    true,
                    "Hai, aku Saku! Titip pengeluaranmu ke aku, misal: \"makan bakso 25 ribu\". Mau ubah tampilan juga boleh, coba \"ubah grafik jadi pie\"."
                )
            )
        )
    }
    var input by rememberSaveable { mutableStateOf("") }
    var listening by remember { mutableStateOf(false) }
    var status by rememberSaveable { mutableStateOf("") }
    var autoAdd by remember { mutableStateOf(prefs.autoAddNotifications) }

    val refresh: () -> Unit = {
        scope.launch {
            expenses = repo.expenses()
            pending = repo.pending()
            cards = repo.dashboard()
        }
    }

    val runAgent: (String) -> Unit = { text ->
        if (text.isNotBlank()) {
            chats = chats + ChatMessage(false, text)
            scope.launch {
                val result = MoneyAgent.run(text, expenses, cards)
                when (result) {
                    is AgentResult.Recorded -> repo.add(result.expense)
                    is AgentResult.DashboardUpdated -> repo.saveDashboard(result.cards)
                    is AgentResult.Info -> Unit
                }
                refresh()
                chats = chats + ChatMessage(true, result.message)
            }
            input = ""
        }
    }

    val startVoice: () -> Unit = {
        if (!voice.isAvailable()) {
            status = "Voice recognition tidak tersedia di HP ini."
        } else {
            val granted = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
            if (granted) {
                listening = true
                voice.start(
                    onResult = { text ->
                        listening = false
                        runAgent(text)
                    },
                    onError = { error ->
                        listening = false
                        status = error
                    }
                )
            } else {
                status = "Izin mikrofon belum diberikan."
            }
        }
    }

    val micPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) {
            startVoice()
        } else {
            status = "Izin mikrofon ditolak — aktifkan lewat setelan izin HP kalau mau pakai suara."
        }
    }

    val folderPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        if (uri != null) {
            store.takePersistablePermission(uri)
            store.setTreeUri(uri)
            scope.launch {
                val ok = repo.initFolder()
                ready = ok && store.isReady()
                if (ok) refresh()
                status = if (ok) {
                    "Folder data siap. Datamu tetap aman di sini bahkan kalau aplikasinya dibongkar."
                } else {
                    "Folder belum bisa dipakai, coba pilih lagi ya."
                }
            }
        }
    }

    val openNotifAccess: () -> Unit = {
        context.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    LaunchedEffect(ready) {
        if (ready) {
            repo.initFolder()
            refresh()
        }
    }

    DisposableEffect(Unit) {
        onDispose { voice.destroy() }
    }

    SakuTheme {
        Scaffold(
            containerColor = SakuColors.cream,
            topBar = {
                TopAppBar(
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = SakuColors.cream),
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Mascot(
                                mood = when {
                                    listening -> Mood.LISTENING
                                    status.startsWith("Dicatat") -> Mood.HAPPY
                                    status.startsWith("Izin") -> Mood.SURPRISED
                                    else -> Mood.IDLE
                                },
                                size = 38.dp
                            )
                            Spacer(Modifier.width(10.dp))
                            Text(
                                "Halo, aku Saku!",
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 19.sp,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                        }
                    }
                )
            },
            bottomBar = {
                NavigationBar(containerColor = SakuColors.card) {
                    val tabs = listOf(
                        Triple("Dasbor", Icons.Filled.Home, 0),
                        Triple("Agent", Icons.Filled.Send, 1),
                        Triple("Konfirmasi", Icons.Filled.Notifications, 2),
                        Triple("Setelan", Icons.Filled.Settings, 3)
                    )
                    tabs.forEach { (label, icon, index) ->
                        NavigationBarItem(
                            selected = tab == index,
                            onClick = { tab = index },
                            icon = { Icon(icon, contentDescription = label) },
                            label = { Text(label, fontSize = 11.sp) }
                        )
                    }
                }
            }
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                when (tab) {
                    0 -> DashboardTab(
                        ready,
                        expenses,
                        pending,
                        cards,
                        input,
                        { input = it },
                        runAgent,
                        {
                            if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                                PackageManager.PERMISSION_GRANTED
                            ) startVoice() else micPermission.launch(Manifest.permission.RECORD_AUDIO)
                        },
                        listening,
                        status,
                        { folderPicker.launch(null) },
                        openNotifAccess,
                        { card ->
                            scope.launch {
                                repo.saveDashboard(cards.filterNot { it.id == card.id })
                                refresh()
                            }
                        },
                        { id ->
                            scope.launch {
                                repo.acceptPending(id)
                                refresh()
                            }
                        },
                        { id ->
                            scope.launch {
                                repo.rejectPending(id)
                                refresh()
                            }
                        }
                    )
                    1 -> AgentTab(chats, input, { input = it }, runAgent, {
                        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
                            PackageManager.PERMISSION_GRANTED
                        ) startVoice() else micPermission.launch(Manifest.permission.RECORD_AUDIO)
                    }, listening)
                    2 -> PendingTab(
                        pending,
                        { id ->
                            scope.launch {
                                repo.acceptPending(id)
                                refresh()
                            }
                        },
                        { id ->
                            scope.launch {
                                repo.rejectPending(id)
                                refresh()
                            }
                        },
                        openNotifAccess
                    )
                    else -> SettingsTab(
                        store,
                        ready,
                        autoAdd,
                        { v ->
                            autoAdd = v
                            prefs.autoAddNotifications = v
                        },
                        { folderPicker.launch(null) },
                        openNotifAccess,
                        {
                            scope.launch {
                                val ok = repo.exportCsv()
                                status = if (ok) "CSV diekspor ke folder data kamu."
                                else "Ekspor gagal — pastikan folder data masih bisa diakses."
                            }
                        },
                        notifAccessGranted(context)
                    )
                }
            }
        }
    }
}

@Composable
private fun DashboardTab(
    ready: Boolean,
    expenses: List<Expense>,
    pending: List<PendingExpense>,
    cards: List<DashboardCard>,
    input: String,
    setInput: (String) -> Unit,
    onSend: (String) -> Unit,
    onVoice: () -> Unit,
    listening: Boolean,
    status: String,
    onPickFolder: () -> Unit,
    onOpenNotifAccess: () -> Unit,
    onDeleteCard: (DashboardCard) -> Unit,
    onAcceptPending: (String) -> Unit,
    onRejectPending: (String) -> Unit
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(SakuColors.cream),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        if (!ready) {
            item {
                Card(shape = RoundedCornerShape(24.dp)) {
                    Column(
                        Modifier.padding(18.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Mascot(Mood.SURPRISED, 46.dp)
                            Spacer(Modifier.width(12.dp))
                            Text(
                                "Buat folder penyimpanan",
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.weight(1f)
                            )
                        }
                        Text(
                            "Pilih (atau buat) folder untuk kotak penyimpanan Saku. Kalau aplikasi dibongkar, isi folder ini tetap ada dan dipakai lagi begitu Saku dipasang lagi.",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Button(onPickFolder, Modifier.fillMaxWidth()) {
                            Text("Pilih / buat folder Saku")
                        }
                        TextButton(onOpenNotifAccess, Modifier.fillMaxWidth()) {
                            Text("Aktifkan pembaca notifikasi")
                        }
                    }
                }
            }
        }

        item { AgentComposer(input, setInput, onSend, onVoice, listening) }

        if (status.isNotBlank()) {
            item {
                Text(
                    status,
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.secondary
                )
            }
        }

        items(cards.filter { it.enabled }, key = { it.id }) { card ->
            DashboardCardView(card, expenses) { onDeleteCard(card) }
        }

        if (pending.isNotEmpty()) {
            item {
                Text(
                    "Menunggu konfirmasi dari notifikasi HP",
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 14.sp
                )
            }
            items(pending.take(5), key = { it.id }) { p ->
                PendingRow(p, { onAcceptPending(p.id) }, { onRejectPending(p.id) })
            }
        }

        item {
            Text(
                "Semua catatan tersimpan lokal di HP kamu. Saku hanya membaca notifikasi keuangan, tanpa koneksi internet untuk datamu.",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 10.dp)
            )
        }
    }
}

@Composable
private fun AgentTab(
    chats: List<ChatMessage>,
    input: String,
    setInput: (String) -> Unit,
    onSend: (String) -> Unit,
    onVoice: () -> Unit,
    listening: Boolean
) {
    val examples = listOf(
        "makan bakso 25 ribu",
        "grab 30k",
        "ubah grafik jadi pie",
        "tampilkan pengeluaran 1-7 Oktober",
        "tambah kartu kategori bulan ini",
        "rekap minggu ini"
    )
    Column(
        Modifier
            .fillMaxSize()
            .background(SakuColors.cream)
    ) {
        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            items(chats) { message ->
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = if (message.fromAgent) Arrangement.Start else Arrangement.End
                ) {
                    Surface(
                        shape = RoundedCornerShape(18.dp),
                        color = if (message.fromAgent) {
                            MaterialTheme.colorScheme.surface
                        } else {
                            MaterialTheme.colorScheme.primaryContainer
                        }
                    ) {
                        Text(
                            message.text,
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                            fontSize = 14.sp
                        )
                    }
                }
            }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        "Contoh perintah",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    examples.chunked(3).forEach { chunk ->
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            chunk.forEach { example ->
                                Surface(
                                    shape = RoundedCornerShape(10.dp),
                                    color = MaterialTheme.colorScheme.surface,
                                    modifier = Modifier.clickable { setInput(example) }
                                ) {
                                    Text(
                                        example,
                                        fontSize = 11.sp,
                                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        AgentComposer(
            input,
            setInput,
            onSend,
            onVoice,
            listening,
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp)
                .navigationBarsPadding()
        )
    }
}

@Composable
private fun PendingTab(
    pending: List<PendingExpense>,
    onAccept: (String) -> Unit,
    onReject: (String) -> Unit,
    onOpenNotifAccess: () -> Unit
) {
    Column(
        Modifier
            .fillMaxSize()
            .background(SakuColors.cream)
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(Modifier.weight(1f)) {
                Text("Menunggu konfirmasi", fontWeight = FontWeight.SemiBold, fontSize = 18.sp)
                Text(
                    "Draft pengeluaran dari notifikasi Gopay/OVO/bank. Belum masuk grafik sebelum kamu setuju.",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                TextButton(onClick = onOpenNotifAccess) {
                    Text("Atur pembaca notifikasi", fontSize = 13.sp)
                }
            }
            Mascot(Mood.THINKING, 44.dp)
        }
        LazyColumn(
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            if (pending.isEmpty()) {
                item {
                    Surface(shape = RoundedCornerShape(18.dp), color = MaterialTheme.colorScheme.surface) {
                        Text(
                            "Belum ada draft menunggu. Datamu tetap aman, tenang aja.",
                            modifier = Modifier.padding(16.dp),
                            fontSize = 13.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
            items(pending, key = { it.id }) { p ->
                PendingRow(p, { onAccept(p.id) }, { onReject(p.id) })
            }
        }
    }
}

@Composable
private fun SettingsTab(
    store: FolderStore,
    ready: Boolean,
    autoAdd: Boolean,
    onAutoAdd: (Boolean) -> Unit,
    onPickFolder: () -> Unit,
    onOpenNotifAccess: () -> Unit,
    onExport: () -> Unit,
    notifAccessGranted: Boolean
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(SakuColors.cream),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Text("Setelan", fontWeight = FontWeight.Bold, fontSize = 20.sp)
        }
        item {
            Card(shape = RoundedCornerShape(20.dp)) {
                Column(
                    Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Mascot(Mood.HAPPY, 40.dp)
                        Spacer(Modifier.width(12.dp))
                        Text("Penyimpanan lokal", fontWeight = FontWeight.SemiBold)
                    }
                    Text(
                        if (ready) {
                            "Folder aktif: " + (store.treeUri?.lastPathSegment ?: "-")
                        } else {
                            "Belum ada folder data."
                        },
                        fontSize = 12.sp
                    )
                    Text(
                        "Data Saku tersimpan sebagai file JSON biasa di folder pilihanmu, jadi tetap ada walau aplikasi dibongkar. Ingin data bisa dibuka dari laptop (beda Wi-Fi juga boleh)? Pilih folder di Google Drive lewat file picker, semua isi kartu data Saku ikut tersinkron ke cloud Drive.",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Button(onPickFolder) {
                        Text(if (ready) "Ganti folder data" else "Pilih folder data")
                    }
                }
            }
        }
        item {
            Card(shape = RoundedCornerShape(20.dp)) {
                Column(
                    Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text("Pembaca notifikasi", fontWeight = FontWeight.SemiBold)
                    Text(
                        "Saku membaca notifikasi Gopay/OVO/bank, menangkap nominalnya, lalu menunggu konfirmasimu — atau langsung mencatat kalau auto-add aktif.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Row(
                        Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            if (notifAccessGranted) "Akses notifikasi: aktif" else "Akses notifikasi: belum aktif",
                            Modifier.weight(1f),
                            fontSize = 13.sp
                        )
                        OutlinedButton(onClick = onOpenNotifAccess) {
                            Text("Buka setelan")
                        }
                    }
                    Row(
                        Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            "Langsung catat tanpa konfirmasi",
                            Modifier.weight(1f),
                            fontSize = 13.sp
                        )
                        Switch(checked = autoAdd, onCheckedChange = onAutoAdd)
                    }
                }
            }
        }
        item {
            Card(shape = RoundedCornerShape(20.dp)) {
                Column(
                    Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text("Ekspor ke CSV", fontWeight = FontWeight.SemiBold)
                    Text(
                        "Simpan salinan semua pengeluaran sebagai CSV di folder data — bisa dibuka di Excel atau Sheets.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    FilledTonalButton(onExport) {
                        Text("Ekspor CSV")
                    }
                }
            }
        }
        item {
            Text(
                "Saku — asisten pengeluaran pribadi. Offline untuk datamu, tanpa iklan, tanpa server.",
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(bottom = 12.dp)
            )
        }
    }
}

@Composable
fun AgentComposer(
    input: String,
    setInput: (String) -> Unit,
    onSend: (String) -> Unit,
    onVoice: () -> Unit,
    listening: Boolean,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 2.dp
    ) {
        Row(
            Modifier.padding(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = input,
                onValueChange = setInput,
                modifier = Modifier.weight(1f),
                placeholder = { Text("Pengeluaran / perintah untuk Saku") },
                singleLine = true,
                shape = RoundedCornerShape(16.dp)
            )
            IconButton(onClick = onVoice) {
                Icon(
                    Icons.Filled.Mic,
                    contentDescription = "Rekam suara",
                    tint = if (listening) SakuColors.warmDeep else MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Button(
                onClick = { onSend(input) },
                enabled = input.isNotBlank(),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = SakuColors.warmDeep)
            ) {
                Icon(Icons.Filled.Send, contentDescription = "Kirim")
            }
        }
    }
}

@Composable
private fun DashboardCardView(
    card: DashboardCard,
    expenses: List<Expense>,
    onRemove: () -> Unit
) {
    Card(
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(card.title, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                IconButton(onClick = onRemove, modifier = Modifier.size(22.dp)) {
                    Icon(
                        Icons.Filled.Close,
                        contentDescription = "Hapus kartu",
                        modifier = Modifier.size(18.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            Text(
                card.rangeLabel(),
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            val inRange = ExpenseRepository.expensesInRange(expenses, card)
            when (card.type) {
                "total" -> {
                    Text(
                        MoneyAgent.formatRupiah(inRange.sumOf { it.amount }),
                        fontSize = 30.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        "${inRange.size} transaksi",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                "chart" -> ChartView(card.chartKind, inRange, Modifier.fillMaxWidth())
                "category" -> ChartView(ChartKind.PIE, inRange, Modifier.fillMaxWidth())
                else -> {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        inRange.take(card.limit).forEach { expense ->
                            ExpenseRow(expense)
                        }
                        if (inRange.size > card.limit) {
                            Text(
                                "+${inRange.size - card.limit} transaksi lainnya",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        if (inRange.isEmpty()) {
                            Text(
                                "Belum ada transaksi di rentang ini.",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ExpenseRow(expense: Expense) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                expense.merchant.ifBlank { "Pengeluaran" },
                fontWeight = FontWeight.Medium,
                fontSize = 14.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                expense.category + " • " + ExpenseRepository.dateOf(expense.timestamp),
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Text(
            "-" + MoneyAgent.formatRupiah(expense.amount),
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp
        )
    }
}

@Composable
private fun PendingRow(
    p: PendingExpense,
    onAccept: () -> Unit,
    onReject: () -> Unit
) {
    Card(shape = RoundedCornerShape(18.dp)) {
        Column(
            Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    MoneyAgent.formatRupiah(p.amount),
                    fontWeight = FontWeight.Bold,
                    fontSize = 17.sp
                )
                Text(
                    ExpenseRepository.dateOf(p.timestamp),
                    fontSize = 11.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Text(
                p.merchant.ifBlank { "Transaksi" } + " • " + p.category,
                fontSize = 13.sp
            )
            Text(
                p.rawText,
                fontSize = 11.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                TextButton(onClick = onReject) { Text("Abaikan") }
                Button(onClick = onAccept) {
                    Icon(Icons.Filled.Check, contentDescription = null)
                    Spacer(Modifier.width(6.dp))
                    Text("Catat")
                }
            }
        }
    }
}
