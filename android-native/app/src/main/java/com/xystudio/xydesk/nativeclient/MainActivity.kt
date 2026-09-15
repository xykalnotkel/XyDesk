package com.xystudio.xydesk.nativeclient

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { XyDeskNativeApp() }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun XyDeskNativeApp() {
    var snapshot by remember { mutableStateOf(NativeCore.snapshot()) }

    MaterialTheme {
        Scaffold(
            topBar = { TopAppBar(title = { Text("XyDesk Native") }) },
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .padding(horizontal = 20.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "Client Android native",
                    style = MaterialTheme.typography.headlineSmall,
                )
                Text(
                    text = "Fondasi Kotlin, Compose, AndroidX, WebRTC native, dan library .so milik XyDesk.",
                    style = MaterialTheme.typography.bodyMedium,
                )
                NativeCard(
                    title = "Library native",
                    body = snapshot,
                )
                NativeCard(
                    title = "ABI target",
                    body = "arm64-v8a + armeabi-v7a",
                )
                NativeCard(
                    title = "Tahap migrasi",
                    body = "Compose dan JNI siap. Signaling, PeerConnection, audio route, auth, PiP, dan MediaProjection menyusul sebelum APK ini menggantikan Flutter.",
                )
                Row(modifier = Modifier.fillMaxWidth()) {
                    Button(onClick = { snapshot = NativeCore.snapshot() }) {
                        Text("Periksa native core")
                    }
                }
            }
        }
    }
}

@Composable
private fun NativeCard(title: String, body: String) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(6.dp))
            Text(body, style = MaterialTheme.typography.bodySmall)
        }
    }
}
