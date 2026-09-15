package net.xyspace.xydesk.nativeclient

import android.Manifest
import android.app.PictureInPictureParams
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Rational
import android.view.WindowManager
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.compose.ui.viewinterop.AndroidView
import org.webrtc.SurfaceViewRenderer
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

class MainActivity : ComponentActivity() {
    private var pendingSessionStart: (() -> Unit)? = null
    private val authViewModel by viewModels<AuthViewModel>()
    private val sessionViewModel by viewModels<SessionViewModel>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            XyDeskNativeRoot(authViewModel, sessionViewModel)
        }
    }

    fun requestSessionPermissions(onGranted: () -> Unit) {
        val permissions = buildList {
            if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                add(Manifest.permission.RECORD_AUDIO)
            }
            if (NativeSettings(this@MainActivity).notificationsEnabled && Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            ) {
                add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        if (permissions.isEmpty()) {
            onGranted()
        } else {
            pendingSessionStart = onGranted
            ActivityCompat.requestPermissions(this, permissions.toTypedArray(), REQUEST_AUDIO)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_AUDIO) return
        val callback = pendingSessionStart
        pendingSessionStart = null
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            callback?.invoke()
        } else {
            Toast.makeText(this, "Izin mikrofon diperlukan untuk memulai sesi.", Toast.LENGTH_LONG).show()
        }
    }

    override fun onUserLeaveHint() {
        if (NativeSettings(this).pipEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            sessionViewModel.state.value.phase == NativeSessionPhase.Connected
        ) {
            setPictureInPictureParams(
                PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(16, 9))
                    .build(),
            )
            enterPictureInPictureMode()
        }
        super.onUserLeaveHint()
    }

    companion object {
        private const val REQUEST_AUDIO = 4101
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun XyDeskNativeRoot(auth: AuthViewModel, session: SessionViewModel) {
    val authState by auth.state.collectAsState()
    val sessionState by session.state.collectAsState()
    val context = LocalContext.current
    val activity = context as? MainActivity
    val settings = remember { NativeSettings(context) }
    var selectedTab by remember { mutableStateOf(0) }
    val signedIn = authState as? AuthUiState.SignedIn
    val titles = listOf("Beranda", "Hubungkan", "Riwayat", "Akun")

    DisposableEffect(sessionState.phase) {
        if (sessionState.phase == NativeSessionPhase.Connected) {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        } else {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        onDispose { }
    }
    DisposableEffect(settings.keepScreenOn) {
        if (settings.keepScreenOn) {
            activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        onDispose { }
    }

    XyDeskTheme {
        Surface(modifier = Modifier.fillMaxSize(), color = XyDeskColors.bg) {
            Scaffold(
                topBar = {
                    if (signedIn != null) {
                        TopAppBar(
                            title = {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Image(
                                        painter = painterResource(R.drawable.logo),
                                        contentDescription = "Logo XyDesk",
                                        modifier = Modifier.size(30.dp),
                                    )
                                    Spacer(Modifier.size(8.dp))
                                    Text(titles[selectedTab])
                                }
                            },
                            colors = TopAppBarDefaults.topAppBarColors(
                                containerColor = XyDeskColors.bg,
                                scrolledContainerColor = XyDeskColors.bg,
                                titleContentColor = XyDeskColors.textHi,
                            ),
                        )
                    }
                },
                bottomBar = {
                    if (signedIn != null) {
                        NavigationBar(
                            containerColor = XyDeskColors.bg,
                            tonalElevation = 0.dp,
                        ) {
                            val destinations = listOf(
                                Triple(Icons.Filled.Home, "Beranda", 0),
                                Triple(Icons.Filled.Link, "Hubungkan", 1),
                                Triple(Icons.Filled.History, "Riwayat", 2),
                                Triple(Icons.Filled.Settings, "Akun", 3),
                            )
                            destinations.forEach { (icon, label, index) ->
                                NavigationBarItem(
                                    selected = selectedTab == index,
                                    onClick = { selectedTab = index },
                                    icon = { androidx.compose.material3.Icon(icon, contentDescription = label) },
                                    label = { Text(label) },
                                )
                            }
                        }
                    }
                },
            ) { padding ->
                when (val state = authState) {
                    AuthUiState.Loading -> LoadingPanel("Memuat sesi aman…", Modifier.padding(padding))
                    is AuthUiState.SignedIn -> when (selectedTab) {
                        0 -> NativeHomeOverview(
                            user = state.user,
                            session = session,
                            sessionState = sessionState,
                            onConnect = { selectedTab = 1 },
                            modifier = Modifier.padding(padding),
                        )
                        1 -> HomeScreen(
                            user = state.user,
                            sessionState = sessionState,
                            session = session,
                            onSignOut = { session.disconnect(); auth.signOut() },
                            onRequestAudio = { start -> activity?.requestSessionPermissions(start) },
                            modifier = Modifier.padding(padding),
                        )
                        2 -> HostHistoryScreen(
                            session = session,
                            onConnect = { selectedTab = 1 },
                            modifier = Modifier.padding(padding),
                        )
                        else -> SettingsScreen(
                            session = session,
                            onBack = { selectedTab = 0 },
                            onSignOut = { session.disconnect(); auth.signOut() },
                            modifier = Modifier.padding(padding),
                        )
                    }
                    is AuthUiState.OtpRequested -> OtpScreen(
                        email = state.email,
                        resendIn = state.resendIn,
                        onVerify = { code, name -> auth.verifyOtp(state.email, code, name) },
                        onResend = { name -> auth.requestOtp(state.email, name) },
                        onBack = { auth.signOut() },
                        modifier = Modifier.padding(padding),
                    )
                    is AuthUiState.Working -> LoadingPanel(state.label, Modifier.padding(padding))
                    is AuthUiState.Error -> when (val previous = state.previous) {
                        is AuthUiState.OtpRequested -> OtpScreen(
                            email = previous.email,
                            resendIn = previous.resendIn,
                            error = state.message,
                            onVerify = { code, name -> auth.verifyOtp(previous.email, code, name) },
                            onResend = { name -> auth.requestOtp(previous.email, name) },
                            onBack = { auth.signOut() },
                            modifier = Modifier.padding(padding),
                        )
                        else -> LoginScreen(
                            error = state.message,
                            onRequestOtp = auth::requestOtp,
                            modifier = Modifier.padding(padding),
                        )
                    }
                    AuthUiState.SignedOut -> LoginScreen(
                        error = null,
                        onRequestOtp = auth::requestOtp,
                        onGuest = auth::signInGuest,
                        modifier = Modifier.padding(padding),
                    )
                }
            }
        }
    }
}

@Composable
private fun NativeHomeOverview(
    user: AuthUser,
    session: SessionViewModel,
    sessionState: NativeSessionState,
    onConnect: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var hosts by remember { mutableStateOf(session.recentHosts()) }
    LaunchedEffect(sessionState.phase) { hosts = session.recentHosts() }
    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text("Halo, ${user.name}", style = MaterialTheme.typography.headlineMedium)
        Text("Perangkat kamu, siap terhubung.", color = XyDeskColors.textMid)
        if (hosts.isEmpty()) {
            Card(colors = XyDeskCardColors, modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Image(
                        painter = painterResource(R.drawable.empty_devices),
                        contentDescription = "Belum ada perangkat",
                        modifier = Modifier.size(150.dp),
                    )
                    Text("Belum ada perangkat", style = MaterialTheme.typography.titleLarge)
                    Text(
                        "Tambahkan host Windows dari halaman Hubungkan atau pindai QR.",
                        color = XyDeskColors.textMid,
                    )
                    Button(onClick = onConnect, colors = XyDeskButtonColors) {
                        Text("Hubungkan perangkat")
                    }
                }
            }
        } else {
            Text("Perangkat tersimpan", style = MaterialTheme.typography.titleMedium)
            hosts.forEach { host ->
                Card(colors = XyDeskCardColors, modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Image(
                            painter = painterResource(
                                if (sessionState.phase == NativeSessionPhase.Connected && sessionState.hostMeta != null) {
                                    R.drawable.pc_online
                                } else {
                                    R.drawable.pc_offline
                                },
                            ),
                            contentDescription = null,
                            modifier = Modifier.size(52.dp),
                        )
                        Column(modifier = Modifier.weight(1f)) {
                            Text(host.name, style = MaterialTheme.typography.titleMedium)
                            Text("ID ${host.id}", style = MaterialTheme.typography.bodySmall)
                            Text(
                                if (sessionState.phase == NativeSessionPhase.Connected) "Sesi aktif" else "Terakhir disimpan",
                                color = if (sessionState.phase == NativeSessionPhase.Connected) XyDeskColors.success else XyDeskColors.textMid,
                                style = MaterialTheme.typography.bodySmall,
                            )
                        }
                        TextButton(onClick = onConnect) { Text("Buka") }
                    }
                }
            }
            OutlinedButton(onClick = onConnect, modifier = Modifier.fillMaxWidth(), colors = XyDeskOutlinedButtonColors) {
                Text("Tambah atau hubungkan host")
            }
        }
        if (sessionState.phase == NativeSessionPhase.Connected) {
            StatusCard("Sesi aktif", "Buka Hubungkan untuk melihat layar dan kontrol sesi.")
        }
    }
}

@Composable
private fun HostHistoryScreen(
    session: SessionViewModel,
    onConnect: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var hosts by remember { mutableStateOf(session.recentHosts()) }
    var renaming by remember { mutableStateOf<PairedHost?>(null) }
    var name by remember { mutableStateOf("") }
    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Riwayat host", style = MaterialTheme.typography.headlineMedium)
        Text("Host yang pernah dipasangkan tersimpan terenkripsi di perangkat.", color = XyDeskColors.textMid)
        if (hosts.isEmpty()) {
            Card(colors = XyDeskCardColors, modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Image(painterResource(R.drawable.empty), "Riwayat kosong", Modifier.size(140.dp))
                    Text("Riwayat masih kosong", style = MaterialTheme.typography.titleMedium)
                    Text("Mulai dari satu host Windows.", color = XyDeskColors.textMid)
                    Button(onClick = onConnect, colors = XyDeskButtonColors) { Text("Hubungkan") }
                }
            }
        } else {
            hosts.forEach { host ->
                Card(colors = XyDeskCardColors, modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Image(painterResource(R.drawable.pc_online), null, Modifier.size(42.dp))
                            Spacer(Modifier.size(10.dp))
                            Column(Modifier.weight(1f)) {
                                Text(host.name, style = MaterialTheme.typography.titleMedium)
                                Text(host.id, style = MaterialTheme.typography.bodySmall)
                            }
                            TextButton(onClick = {
                                renaming = host
                                name = host.name
                            }) { Text("Nama") }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                            Button(onClick = onConnect, modifier = Modifier.weight(1f), colors = XyDeskButtonColors) { Text("Hubungkan") }
                            OutlinedButton(
                                onClick = {
                                    session.removeHost(host.id)
                                    hosts = session.recentHosts()
                                },
                                modifier = Modifier.weight(1f),
                                colors = XyDeskOutlinedButtonColors,
                            ) { Text("Hapus") }
                        }
                    }
                }
            }
        }
    }
    renaming?.let { host ->
        AlertDialog(
            onDismissRequest = { renaming = null },
            title = { Text("Ganti nama host") },
            text = { OutlinedTextField(value = name, onValueChange = { name = it.take(48) }, label = { Text("Nama host") }, singleLine = true) },
            confirmButton = {
                TextButton(enabled = name.trim().isNotEmpty(), onClick = {
                    session.renameHost(host.id, name)
                    hosts = session.recentHosts()
                    renaming = null
                }) { Text("Simpan") }
            },
            dismissButton = { TextButton(onClick = { renaming = null }) { Text("Batal") } },
        )
    }
}

@Composable
private fun LoadingPanel(label: String, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Image(
                painter = painterResource(R.drawable.logo),
                contentDescription = "Logo XyDesk",
                modifier = Modifier.size(88.dp),
            )
            CircularProgressIndicator(color = XyDeskColors.accent)
            Text(label, color = XyDeskColors.textMid)
        }
    }
}

@Composable
private fun LoginScreen(
    error: String?,
    onRequestOtp: (String, String) -> Unit,
    onGuest: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Spacer(Modifier.height(8.dp))
        Image(
            painter = painterResource(R.drawable.il_auth),
            contentDescription = "Ilustrasi masuk XyDesk",
            modifier = Modifier.size(168.dp),
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "Masuk ke XyDesk",
            style = MaterialTheme.typography.headlineMedium,
            color = XyDeskColors.textHi,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        Text(
            "Simpan sesi dengan aman dan mulai koneksi ke host Windows.",
            color = XyDeskColors.textMid,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            modifier = Modifier.widthIn(max = 440.dp),
        )
        if (!error.isNullOrBlank()) ErrorCard(error)
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("Nama") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Button(
            onClick = { onRequestOtp(email, name) },
            modifier = Modifier.fillMaxWidth(),
            colors = XyDeskButtonColors,
        ) { Text("Kirim kode OTP") }
        OutlinedButton(
            onClick = onGuest,
            modifier = Modifier.fillMaxWidth(),
            colors = XyDeskOutlinedButtonColors,
        ) { Text("Lanjut sebagai tamu") }
        Text("Token akun disimpan terenkripsi melalui Android Keystore. Tamu dapat melihat UI, tetapi perlu akun untuk menyambung ke host.", style = MaterialTheme.typography.bodySmall, color = XyDeskColors.textLow)

    }
}

@Composable
private fun OtpScreen(
    email: String,
    resendIn: Int,
    error: String? = null,
    onVerify: (String, String) -> Unit,
    onResend: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var digits by remember { mutableStateOf(List(6) { "" }) }
    val code = digits.joinToString("")
    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Spacer(Modifier.height(8.dp))
        Image(
            painter = painterResource(R.drawable.pair_success),
            contentDescription = "Verifikasi aman",
            modifier = Modifier.size(132.dp),
        )
        Text("Verifikasi email", style = MaterialTheme.typography.headlineMedium, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        Text(
            "Kode enam digit dikirim ke $email",
            color = XyDeskColors.textMid,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        if (!error.isNullOrBlank()) ErrorCard(error)
        Row(
            modifier = Modifier.widthIn(max = 360.dp).fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            repeat(6) { index ->
                OutlinedTextField(
                    value = digits[index],
                    onValueChange = { value ->
                        val incoming = value.filter(Char::isDigit)
                        val updated = digits.toMutableList()
                        if (incoming.length > 1) {
                            incoming.take(6).forEachIndexed { offset, digit -> updated[offset] = digit.toString() }
                        } else {
                            updated[index] = incoming.takeLast(1)
                        }
                        digits = updated
                    },
                    singleLine = true,
                    textStyle = MaterialTheme.typography.titleLarge.copy(textAlign = androidx.compose.ui.text.style.TextAlign.Center),
                    modifier = Modifier.weight(1f),
                )
            }
        }
        Button(
            onClick = { onVerify(code, "") },
            enabled = code.length == 6,
            modifier = Modifier.fillMaxWidth().widthIn(max = 440.dp),
            colors = XyDeskButtonColors,
        ) { Text("Verifikasi") }
        TextButton(onClick = { onResend("") }, enabled = resendIn == 0) {
            Text(if (resendIn > 0) "Kirim ulang dalam ${resendIn}s" else "Kirim ulang kode")
        }
        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth().widthIn(max = 440.dp), colors = XyDeskOutlinedButtonColors) {
            Text("Kembali")
        }
    }
}

@Composable
private fun HomeScreen(
    user: AuthUser,
    sessionState: NativeSessionState,
    session: SessionViewModel,
    onSignOut: () -> Unit,
    onRequestAudio: ((() -> Unit) -> Unit),
    modifier: Modifier = Modifier,
) {
    var hostId by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var settingsVisible by remember { mutableStateOf(false) }
    var recentHosts by remember { mutableStateOf(session.recentHosts()) }
    var renamingHost by remember { mutableStateOf<PairedHost?>(null) }
    var renameValue by remember { mutableStateOf("") }
    val context = LocalContext.current
    LaunchedEffect(sessionState.phase) {
        recentHosts = session.recentHosts()
    }
    if (settingsVisible) {
        SettingsScreen(
            session = session,
            onBack = { settingsVisible = false },
            onSignOut = onSignOut,
        )
        return
    }
    val qrLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        if (result.resultCode == android.app.Activity.RESULT_OK) {
            result.data?.getStringExtra(QrScannerActivity.EXTRA_HOST_ID)?.let { hostId = it }
        }
    }
    val connecting = sessionState.phase == NativeSessionPhase.Pairing || sessionState.phase == NativeSessionPhase.Negotiating
    val live = sessionState.phase == NativeSessionPhase.Connected

    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Image(
            painter = painterResource(R.drawable.connect),
            contentDescription = "Ilustrasi koneksi",
            modifier = Modifier.fillMaxWidth().height(118.dp),
        )
        Text("Halo, ${user.name}", style = MaterialTheme.typography.headlineSmall, color = XyDeskColors.textHi)
        Text("Hubungkan ke host Windows tanpa menyalin sesi Flutter.", color = XyDeskColors.textMid)
        if (recentHosts.isNotEmpty()) {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Host tersimpan", style = MaterialTheme.typography.titleMedium)
                    recentHosts.forEach { host ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            OutlinedButton(
                                onClick = {
                                    hostId = host.id
                                    password = host.password
                                },
                                modifier = Modifier.weight(1f),
                            ) { Text(host.name) }
                            TextButton(onClick = {
                                renamingHost = host
                                renameValue = host.name
                            }) { Text("Nama") }
                            TextButton(onClick = {
                                session.removeHost(host.id)
                                recentHosts = session.recentHosts()
                            }) { Text("Hapus") }
                        }
                    }
                }
            }
        }
        if (sessionState.phase == NativeSessionPhase.Error) ErrorCard(sessionState.message ?: "Koneksi gagal.")
        if (sessionState.phase == NativeSessionPhase.Rejected) ErrorCard(sessionState.message ?: "Pairing ditolak host.")
        if (sessionState.phase == NativeSessionPhase.PeerOffline) ErrorCard(sessionState.message ?: "Host tidak online.")
        if (sessionState.phase == NativeSessionPhase.HostBusy) ErrorCard(sessionState.message ?: "Host sedang dipakai.")
        if (sessionState.phase == NativeSessionPhase.Error ||
            sessionState.phase == NativeSessionPhase.Rejected ||
            sessionState.phase == NativeSessionPhase.PeerOffline ||
            sessionState.phase == NativeSessionPhase.HostBusy
        ) {
            OutlinedButton(
                onClick = { onRequestAudio { session.connect(hostId, password) } },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Coba lagi") }
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Connect", style = MaterialTheme.typography.titleLarge)
                OutlinedTextField(
                    value = hostId,
                    onValueChange = { hostId = it },
                    label = { Text("ID host") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedButton(
                    onClick = {
                        qrLauncher.launch(Intent(context, QrScannerActivity::class.java))
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Pindai QR host") }
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Password host") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(
                    onClick = { onRequestAudio { session.connect(hostId, password) } },
                    enabled = !connecting && !live,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    if (connecting) CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                    else Text("Mulai sesi")
                }
            }
        }

        if (connecting) StatusCard("Menghubungkan", sessionState.message ?: "Menunggu host menerima pairing…")
        if (live) SessionCard(sessionState, session)
        if (sessionState.phase == NativeSessionPhase.Ended || sessionState.phase == NativeSessionPhase.Error) {
            OutlinedButton(onClick = { session.disconnect() }, modifier = Modifier.fillMaxWidth()) { Text("Bersihkan sesi") }
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Pengaturan", style = MaterialTheme.typography.titleMedium)
                Text("Akun: ${user.email}", style = MaterialTheme.typography.bodySmall)
                OutlinedButton(onClick = { settingsVisible = true }, modifier = Modifier.fillMaxWidth()) { Text("Buka pengaturan") }
                OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) { Text("Keluar") }
            }
        }
    }
    renamingHost?.let { host ->
        AlertDialog(
            onDismissRequest = { renamingHost = null },
            title = { Text("Ganti nama host") },
            text = {
                OutlinedTextField(
                    value = renameValue,
                    onValueChange = { renameValue = it.take(48) },
                    label = { Text("Nama host") },
                    singleLine = true,
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        session.renameHost(host.id, renameValue)
                        recentHosts = session.recentHosts()
                        renamingHost = null
                    },
                    enabled = renameValue.trim().isNotEmpty(),
                ) { Text("Simpan") }
            },
            dismissButton = { TextButton(onClick = { renamingHost = null }) { Text("Batal") } },
        )
    }
}

@Composable
private fun SettingsScreen(
    session: SessionViewModel,
    onBack: () -> Unit,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val settings = remember { NativeSettings(context) }
    val sessionState by session.state.collectAsState()
    var audioDefault by remember { mutableStateOf(settings.audioForwardDefault) }
    var microphoneDefault by remember { mutableStateOf(settings.microphoneDefault) }
    var pipEnabled by remember { mutableStateOf(settings.pipEnabled) }
    var notificationsEnabled by remember { mutableStateOf(settings.notificationsEnabled) }
    var clipboardSync by remember { mutableStateOf(settings.clipboardSync) }
    var keepScreenOn by remember { mutableStateOf(settings.keepScreenOn) }
    var haptics by remember { mutableStateOf(settings.hapticsEnabled) }
    var relativeMouse by remember { mutableStateOf(settings.relativeMouseMode) }
    var autoReconnect by remember { mutableStateOf(settings.autoReconnect) }
    var preferredDisplay by remember { mutableStateOf(settings.preferredDisplay.toString()) }
    var signalingEndpoint by remember { mutableStateOf(settings.signalingEndpoint) }
    var updateMessage by remember { mutableStateOf<String?>(null) }
    var updateResult by remember { mutableStateOf<NativeUpdateResult?>(null) }
    var downloadId by remember { mutableStateOf<Long?>(null) }
    val updateScope = rememberCoroutineScope()
    val updateInstaller = remember { NativeUpdateInstaller(context) }
    LaunchedEffect(downloadId) {
        val result = updateResult
        downloadId?.let { id ->
            while (isActive) {
                when (updateInstaller.status(id)) {
                    NativeUpdateInstaller.DownloadStatus.Ready -> {
                        if (result == null || !updateInstaller.verify(id, result.sha256)) {
                            updateMessage = "Checksum update tidak cocok; pemasangan dibatalkan."
                            break
                        }
                        updateMessage = "Download selesai. Membuka installer Android…"
                        runCatching { updateInstaller.install(id) }
                            .onFailure { updateMessage = it.message ?: "Installer Android tidak dapat dibuka." }
                        downloadId = null
                        break
                    }
                    NativeUpdateInstaller.DownloadStatus.Failed,
                    NativeUpdateInstaller.DownloadStatus.Missing -> {
                        updateMessage = "Download update gagal."
                        downloadId = null
                        break
                    }
                    NativeUpdateInstaller.DownloadStatus.InProgress -> {
                        updateMessage = "Mengunduh update…"
                        delay(1000)
                    }
                }
            }
        }
    }
    DisposableEffect(keepScreenOn) {
        val activity = context as? MainActivity
        if (keepScreenOn) activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose { }
    }
    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Pengaturan", style = MaterialTheme.typography.headlineSmall)
        Text("Preferensi native XyDesk tersimpan di perangkat.", color = Color(0xFF625B71))
        SettingsToggle("Audio host aktif saat mulai", audioDefault) {
            audioDefault = it
            settings.audioForwardDefault = it
            session.setAudioForwardEnabled(it)
        }
        SettingsToggle("Mikrofon aktif saat mulai", microphoneDefault) {
            microphoneDefault = it
            settings.microphoneDefault = it
            session.setMicrophoneEnabled(it)
        }
        SettingsToggle("Picture-in-picture otomatis", pipEnabled) {
            pipEnabled = it
            settings.pipEnabled = it
        }
        SettingsToggle("Notifikasi sesi", notificationsEnabled) {
            notificationsEnabled = it
            settings.notificationsEnabled = it
        }
        SettingsToggle("Sinkronisasi clipboard", clipboardSync) {
            clipboardSync = it
            settings.clipboardSync = it
        }
        SettingsToggle("Layar tetap menyala saat sesi", keepScreenOn) {
            keepScreenOn = it
            settings.keepScreenOn = it
        }
        SettingsToggle("Getaran kontrol", haptics) {
            haptics = it
            settings.hapticsEnabled = it
        }
        SettingsToggle("Mode mouse relatif / trackpad", relativeMouse) {
            relativeMouse = it
            settings.relativeMouseMode = it
            session.setRelativeMouseMode(it)
        }
        SettingsToggle("Sambung ulang otomatis", autoReconnect) {
            autoReconnect = it
            settings.autoReconnect = it
        }
        OutlinedTextField(
            value = preferredDisplay,
            onValueChange = {
                preferredDisplay = it.filter(Char::isDigit)
                it.toIntOrNull()?.let { index ->
                    settings.preferredDisplay = index
                    session.selectDisplay(index)
                }
            },
            label = { Text("Display host pilihan (0 = utama)") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = signalingEndpoint,
            onValueChange = {
                signalingEndpoint = it
                settings.signalingEndpoint = it
            },
            label = { Text("Endpoint signaling") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Pembaruan aplikasi", style = MaterialTheme.typography.titleMedium)
                Text(updateMessage ?: "Periksa manifest GitHub Release resmi XyDesk.", style = MaterialTheme.typography.bodySmall)
                Button(
                    onClick = {
                        updateMessage = "Memeriksa update…"
                        updateScope.launch {
                            runCatching { NativeUpdateChecker().check() }
                                .onSuccess { result ->
                                    updateResult = result
                                    updateMessage = if (result.available) {
                                        "Versi ${result.version} tersedia (build ${result.build})."
                                    } else {
                                        "XyDesk sudah versi terbaru (${result.installedVersion})."
                                    }
                                }
                                .onFailure { error ->
                                    updateResult = null
                                    updateMessage = error.message ?: "Gagal memeriksa update."
                                }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Periksa update") }
                updateResult?.takeIf { it.available }?.let { result ->
                    Button(
                        onClick = {
                            updateMessage = "Menyiapkan download update…"
                            downloadId = updateInstaller.enqueue(result)
                        },
                        enabled = downloadId == null,
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text("Unduh dan pasang update") }
                    OutlinedButton(
                        onClick = {
                            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(result.releaseUrl)))
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text("Buka rilis resmi") }
                }
            }
        }
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Diagnostik native", style = MaterialTheme.typography.titleMedium)
                Text("State: ${sessionState.phase}", style = MaterialTheme.typography.bodySmall)
                Text("ABI: ${Build.SUPPORTED_ABIS.joinToString()}", style = MaterialTheme.typography.bodySmall)
                Text("JNI library: ${if (NativeCore.isLoaded()) "loaded" else "tidak tersedia"}", style = MaterialTheme.typography.bodySmall)
                Text(NativeCore.snapshot(), style = MaterialTheme.typography.bodySmall)
            }
        }
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Tentang", style = MaterialTheme.typography.titleMedium)
                Text("XyDesk Android Native", style = MaterialTheme.typography.bodyMedium)
                Text("Package net.xyspace.xydesk", style = MaterialTheme.typography.bodySmall)
                Text("Versi ${BuildConfig.VERSION_NAME} · Build ${BuildConfig.VERSION_CODE}", style = MaterialTheme.typography.bodySmall)
                Text("Flutter tetap fallback sampai parity device terbukti.", style = MaterialTheme.typography.bodySmall)
            }
        }
        OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) { Text("Keluar akun") }
        Button(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("Kembali") }
    }
}

@Composable
private fun SettingsToggle(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(label, modifier = Modifier.weight(1f))
            Switch(checked = checked, onCheckedChange = onCheckedChange)
        }
    }
}

@Composable
private fun SessionCard(state: NativeSessionState, session: SessionViewModel) {
    var text by remember { mutableStateOf("") }
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    val videoHeight = if (configuration.orientation == Configuration.ORIENTATION_LANDSCAPE) 320.dp else 220.dp
    val clipboard = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
    val hapticFeedback = LocalHapticFeedback.current
    val settings = remember { NativeSettings(context) }
    fun feedback() {
        if (settings.hapticsEnabled) {
            hapticFeedback.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        }
    }
    var keyboardVisible by remember { mutableStateOf(false) }
    var nowMs by remember { mutableStateOf(System.currentTimeMillis()) }
    LaunchedEffect(state.connectedAtMs) {
        while (state.connectedAtMs != null) {
            nowMs = System.currentTimeMillis()
            delay(1_000)
        }
    }
    LaunchedEffect(state.clipboard, settings.clipboardSync) {
        if (settings.clipboardSync) {
            state.clipboard?.let { value ->
                clipboard?.setPrimaryClip(android.content.ClipData.newPlainText("XyDesk PC", value))
            }
        }
    }
    val elapsedSeconds = state.connectedAtMs?.let { ((nowMs - it).coerceAtLeast(0L) / 1_000L) } ?: 0L
    val durationLabel = "%02d:%02d:%02d".format(elapsedSeconds / 3_600, (elapsedSeconds % 3_600) / 60, elapsedSeconds % 60)
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Sesi aktif", style = MaterialTheme.typography.titleLarge)
            Text("Durasi $durationLabel", style = MaterialTheme.typography.bodySmall, color = Color(0xFF625B71))
            Text(if (state.videoReady) "Video tersambung" else "Video sedang disiapkan…")
            Text(
                if (state.relativeMouseMode) "Mouse: relatif / trackpad" else "Mouse: absolute / layar",
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF625B71),
            )
            AndroidView(
                factory = { context ->
                    SurfaceViewRenderer(context).also { renderer ->
                        session.attachRenderer(renderer)
                        var previousX = 0f
                        var previousY = 0f
                        renderer.setOnTouchListener { view, event ->
                            val width = view.width.coerceAtLeast(1)
                            val height = view.height.coerceAtLeast(1)
                            when (event.actionMasked) {
                                android.view.MotionEvent.ACTION_DOWN -> {
                                    previousX = event.x
                                    previousY = event.y
                                    if (!session.isRelativeMouseMode()) {
                                        session.mouseMoveAbsolute(event.x.toDouble() / width, event.y.toDouble() / height)
                                    }
                                    session.mouseButton(0, true)
                                    true
                                }
                                android.view.MotionEvent.ACTION_MOVE -> {
                                    if (session.isRelativeMouseMode()) {
                                        session.mouseMoveRelative(
                                            (event.x - previousX).roundToInt(),
                                            (event.y - previousY).roundToInt(),
                                        )
                                    } else {
                                        session.mouseMoveAbsolute(event.x.toDouble() / width, event.y.toDouble() / height)
                                    }
                                    previousX = event.x
                                    previousY = event.y
                                    true
                                }
                                android.view.MotionEvent.ACTION_UP,
                                android.view.MotionEvent.ACTION_CANCEL -> {
                                    session.mouseButton(0, false)
                                    true
                                }
                                else -> true
                            }
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth().height(videoHeight),
                onRelease = session::detachRenderer,
            )
            Text(if (state.audioReady) "Audio tersambung" else "Menunggu audio host…")
            state.stats?.let { stats ->
                Text(
                    buildString {
                        append("Stats: ")
                        stats.width?.let { width -> append("${width}x${stats.height ?: 0} ") }
                        stats.fps?.let { append("• ${it.roundToInt()} FPS ") }
                        stats.videoKbps?.let { append("• video ${it.roundToInt()} kbps ") }
                        stats.audioKbps?.let { append("• audio ${it.roundToInt()} kbps ") }
                        stats.rttMs?.let { append("• RTT ${it.roundToInt()} ms ") }
                        stats.packetLossPercent?.let { append("• loss ${"%.1f".format(it)}% ") }
                        stats.codec?.let { append("• $it") }
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF625B71),
                )
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                OutlinedButton(
                    onClick = { feedback(); session.setAudioForwardEnabled(!state.audioForwardEnabled) },
                    modifier = Modifier.weight(1f),
                ) { Text(if (state.audioForwardEnabled) "Matikan audio" else "Nyalakan audio") }
                OutlinedButton(
                    onClick = { feedback(); session.setMicrophoneEnabled(!state.microphoneEnabled) },
                    modifier = Modifier.weight(1f),
                ) { Text(if (state.microphoneEnabled) "Matikan mic" else "Nyalakan mic") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                OutlinedButton(
                    onClick = {
                        feedback()
                        session.mouseButton(0, true)
                        session.mouseButton(0, false)
                    },
                    modifier = Modifier.weight(1f),
                ) { Text("Klik kiri") }
                OutlinedButton(
                    onClick = {
                        feedback()
                        session.mouseButton(1, true)
                        session.mouseButton(1, false)
                    },
                    modifier = Modifier.weight(1f),
                ) { Text("Klik kanan") }
                OutlinedButton(
                    onClick = {
                        feedback()
                        session.mouseButton(2, true)
                        session.mouseButton(2, false)
                    },
                    modifier = Modifier.weight(1f),
                ) { Text("Klik tengah") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                OutlinedButton(onClick = { feedback(); session.scroll(0, -480) }, modifier = Modifier.weight(1f)) { Text("Scroll atas") }
                OutlinedButton(onClick = { feedback(); session.scroll(0, 480) }, modifier = Modifier.weight(1f)) { Text("Scroll bawah") }
            }
            state.hostMeta?.displays?.takeIf { it.isNotEmpty() }?.let { displays ->
                Text("Layar host", style = MaterialTheme.typography.titleMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    displays.forEach { display ->
                        OutlinedButton(
                            onClick = { session.selectDisplay(display.index) },
                            modifier = Modifier.weight(1f),
                        ) { Text("Layar ${display.index + 1}") }
                    }
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                OutlinedButton(
                    onClick = { feedback(); session.requestClipboard() },
                    enabled = settings.clipboardSync,
                    modifier = Modifier.weight(1f),
                ) { Text("Ambil clipboard PC") }
                OutlinedButton(
                    onClick = {
                        feedback()
                        val value = clipboard?.primaryClip?.getItemAt(0)?.coerceToText(context)?.toString().orEmpty()
                        if (value.isNotEmpty()) session.sendClipboard(value)
                    },
                    enabled = settings.clipboardSync,
                    modifier = Modifier.weight(1f),
                ) { Text("Kirim clipboard") }
            }
            state.clipboard?.let { value ->
                Text("Clipboard PC diterima: ${value.take(80)}", style = MaterialTheme.typography.bodySmall)
            }
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                label = { Text("Kirim teks ke host") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = { session.sendText(text); text = "" },
                enabled = text.isNotEmpty(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Kirim teks") }
            OutlinedButton(
                onClick = { keyboardVisible = !keyboardVisible },
                modifier = Modifier.fillMaxWidth(),
            ) { Text(if (keyboardVisible) "Sembunyikan keyboard" else "Buka keyboard virtual") }
            if (keyboardVisible) KeyboardPanel(session)
            OutlinedButton(onClick = session::disconnect, modifier = Modifier.fillMaxWidth()) {
                Text("Akhiri sesi")
            }
        }
    }
}

@Composable
private fun KeyboardPanel(session: SessionViewModel) {
    val activeModifiers = remember { mutableStateOf(setOf<String>()) }
    val modifierLabels = setOf("Ctrl", "Alt", "Win", "Shift")
    DisposableEffect(Unit) {
        onDispose {
            activeModifiers.value.forEach { label ->
                KeyMapper.vkForLabel(label)?.let { session.key(it, false) }
            }
        }
    }
    val rows = listOf(
        listOf("Esc", "Tab", "Ctrl", "Alt", "Win"),
        listOf("↑", "←", "↓", "→", "Backspace", "Del"),
        listOf("`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="),
        listOf("Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"),
        listOf("Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L"),
        listOf("Z", "X", "C", "V", "B", "N", "M", ",", ".", "/"),
        listOf("Enter", "Space", "F1", "F2", "F3", "F4"),
        listOf("F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"),
    )
    Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { label ->
                    val mapped = if (label == "Space") " " else label
                    OutlinedButton(
                        onClick = {
                            KeyMapper.vkForLabel(mapped)?.let { vk ->
                                if (label in modifierLabels) {
                                    if (label in activeModifiers.value) {
                                        session.key(vk, false)
                                        activeModifiers.value = activeModifiers.value - label
                                    } else {
                                        session.key(vk, true)
                                        activeModifiers.value = activeModifiers.value + label
                                    }
                                } else {
                                    session.key(vk, true)
                                    session.key(vk, false)
                                    activeModifiers.value.forEach { modifier ->
                                        KeyMapper.vkForLabel(modifier)?.let { session.key(it, false) }
                                    }
                                    activeModifiers.value = emptySet()
                                }
                            }
                        },
                        modifier = Modifier.weight(1f),
                    ) { Text(if (label in activeModifiers.value) "[$label]" else label) }
                }
            }
        }
    }
}

@Composable
private fun ErrorCard(message: String) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Text(message, modifier = Modifier.padding(14.dp), color = Color(0xFFB42318))
    }
}

@Composable
private fun StatusCard(title: String, message: String) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Text(message, style = MaterialTheme.typography.bodySmall)
        }
    }
}
