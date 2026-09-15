package net.xyspace.xydesk.nativeclient

import android.Manifest
import android.app.PictureInPictureParams
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Rational
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.compose.setContent
import androidx.activity.viewModels
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
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.compose.ui.viewinterop.AndroidView
import org.webrtc.SurfaceViewRenderer

class MainActivity : ComponentActivity() {
    private val authViewModel by viewModels<AuthViewModel>()
    private val sessionViewModel by viewModels<SessionViewModel>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            XyDeskNativeRoot(authViewModel, sessionViewModel)
        }
    }

    fun requestAudioPermission() {
        val permissions = buildList {
            if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                add(Manifest.permission.RECORD_AUDIO)
            }
            if (Build.VERSION.SDK_INT >= 33 &&
                ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            ) {
                add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissions.toTypedArray(), REQUEST_AUDIO)
        }
    }

    override fun onUserLeaveHint() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
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

    MaterialTheme {
        Surface(modifier = Modifier.fillMaxSize(), color = Color(0xFFF7F7FB)) {
            Scaffold(
                topBar = {
                    TopAppBar(
                        title = { Text("XyDesk") },
                        colors = TopAppBarDefaults.topAppBarColors(
                            containerColor = Color.White,
                            titleContentColor = Color(0xFF201A35),
                        ),
                    )
                },
            ) { padding ->
                when (val state = authState) {
                    AuthUiState.Loading -> LoadingPanel("Memuat sesi aman…", Modifier.padding(padding))
                    is AuthUiState.SignedIn -> HomeScreen(
                        user = state.user,
                        sessionState = sessionState,
                        session = session,
                        onSignOut = auth::signOut,
                        onRequestAudio = { activity?.requestAudioPermission() },
                        modifier = Modifier.padding(padding),
                    )
                    is AuthUiState.OtpRequested -> OtpScreen(
                        email = state.email,
                        resendIn = state.resendIn,
                        onVerify = { code, name -> auth.verifyOtp(state.email, code, name) },
                        onBack = { auth.signOut() },
                        modifier = Modifier.padding(padding),
                    )
                    is AuthUiState.Working -> LoadingPanel(state.label, Modifier.padding(padding))
                    is AuthUiState.Error -> LoginScreen(
                        error = state.message,
                        onRequestOtp = auth::requestOtp,
                        modifier = Modifier.padding(padding),
                    )
                    AuthUiState.SignedOut -> LoginScreen(
                        error = null,
                        onRequestOtp = auth::requestOtp,
                        modifier = Modifier.padding(padding),
                    )
                }
            }
        }
    }
}

@Composable
private fun LoadingPanel(label: String, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            CircularProgressIndicator(color = Color(0xFF6D28D9))
            Text(label, color = Color(0xFF514A67))
        }
    }
}

@Composable
private fun LoginScreen(
    error: String?,
    onRequestOtp: (String, String) -> Unit,
    modifier: Modifier = Modifier,
) {
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Spacer(Modifier.height(26.dp))
        Text("Masuk ke XyDesk", style = MaterialTheme.typography.headlineMedium, color = Color(0xFF201A35))
        Text("Simpan sesi dengan aman dan mulai koneksi ke host Windows.", color = Color(0xFF625B71))
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
        ) { Text("Kirim kode OTP") }
        Text("Token disimpan terenkripsi melalui Android Keystore.", style = MaterialTheme.typography.bodySmall, color = Color(0xFF756E84))
    }
}

@Composable
private fun OtpScreen(
    email: String,
    resendIn: Int,
    onVerify: (String, String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var code by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }
    Column(
        modifier = modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Spacer(Modifier.height(26.dp))
        Text("Verifikasi email", style = MaterialTheme.typography.headlineMedium)
        Text("Kode dikirim ke $email.")
        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("Nama") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = code,
            onValueChange = { code = it },
            label = { Text("Kode OTP") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Button(onClick = { onVerify(code, name) }, modifier = Modifier.fillMaxWidth()) {
            Text("Verifikasi")
        }
        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("Kembali") }
        if (resendIn > 0) Text("Kode baru dapat diminta lagi setelah $resendIn detik.")
    }
}

@Composable
private fun HomeScreen(
    user: AuthUser,
    sessionState: NativeSessionState,
    session: SessionViewModel,
    onSignOut: () -> Unit,
    onRequestAudio: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var hostId by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    val context = LocalContext.current
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
        Text("Halo, ${user.name}", style = MaterialTheme.typography.headlineSmall, color = Color(0xFF201A35))
        Text("Hubungkan ke host Windows tanpa menyalin sesi Flutter.", color = Color(0xFF625B71))
        if (sessionState.phase == NativeSessionPhase.Error) ErrorCard(sessionState.message ?: "Koneksi gagal.")
        if (sessionState.phase == NativeSessionPhase.Rejected) ErrorCard(sessionState.message ?: "Pairing ditolak host.")
        if (sessionState.phase == NativeSessionPhase.PeerOffline) ErrorCard(sessionState.message ?: "Host tidak online.")
        if (sessionState.phase == NativeSessionPhase.Error ||
            sessionState.phase == NativeSessionPhase.Rejected ||
            sessionState.phase == NativeSessionPhase.PeerOffline ||
            sessionState.phase == NativeSessionPhase.HostBusy
        ) {
            OutlinedButton(
                onClick = { session.connect(hostId, password) },
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
                    onClick = { onRequestAudio(); session.connect(hostId, password) },
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
                OutlinedButton(onClick = onSignOut, modifier = Modifier.fillMaxWidth()) { Text("Keluar") }
            }
        }
    }
}

@Composable
private fun SessionCard(state: NativeSessionState, session: SessionViewModel) {
    var text by remember { mutableStateOf("") }
    val context = LocalContext.current
    val clipboard = context.getSystemService(android.content.Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
    var keyboardVisible by remember { mutableStateOf(false) }
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Sesi aktif", style = MaterialTheme.typography.titleLarge)
            Text(if (state.videoReady) "Video tersambung" else "Video sedang disiapkan…")
            AndroidView(
                factory = { context ->
                    SurfaceViewRenderer(context).also { session.attachRenderer(it) }
                },
                modifier = Modifier.fillMaxWidth().height(220.dp),
            )
            Text(if (state.audioReady) "Audio tersambung" else "Menunggu audio host…")
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                OutlinedButton(
                    onClick = { session.setAudioForwardEnabled(!state.audioForwardEnabled) },
                    modifier = Modifier.weight(1f),
                ) { Text(if (state.audioForwardEnabled) "Matikan audio" else "Nyalakan audio") }
                OutlinedButton(
                    onClick = {
                        session.mouseButton(1, true)
                        session.mouseButton(1, false)
                    },
                    modifier = Modifier.weight(1f),
                ) { Text("Klik kiri") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                OutlinedButton(onClick = { session.scroll(0, -480) }, modifier = Modifier.weight(1f)) { Text("Scroll atas") }
                OutlinedButton(onClick = { session.scroll(0, 480) }, modifier = Modifier.weight(1f)) { Text("Scroll bawah") }
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
                    onClick = { session.requestClipboard() },
                    modifier = Modifier.weight(1f),
                ) { Text("Ambil clipboard PC") }
                OutlinedButton(
                    onClick = {
                        val value = clipboard?.primaryClip?.getItemAt(0)?.coerceToText(context)?.toString().orEmpty()
                        if (value.isNotEmpty()) session.sendClipboard(value)
                    },
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
    val rows = listOf(
        listOf("Esc", "Tab", "Ctrl", "Alt", "Win"),
        listOf("↑", "←", "↓", "→", "Backspace"),
        listOf("Enter", "Space", "F1", "F2", "F3", "F4"),
        listOf("F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"),
    )
    Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp), modifier = Modifier.fillMaxWidth()) {
                row.forEach { label ->
                    val mapped = if (label == "Space") " " else label
                    OutlinedButton(
                        onClick = { session.sendKeyLabel(mapped) },
                        modifier = Modifier.weight(1f),
                    ) { Text(label) }
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
