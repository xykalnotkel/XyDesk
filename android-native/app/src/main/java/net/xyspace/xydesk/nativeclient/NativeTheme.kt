package net.xyspace.xydesk.nativeclient

import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Typography
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val Inter = FontFamily(
    Font(R.font.inter_regular, FontWeight.Normal),
    Font(R.font.inter_medium, FontWeight.Medium),
    Font(R.font.inter_semibold, FontWeight.SemiBold),
    Font(R.font.inter_bold, FontWeight.Bold),
)

object XyDeskColors {
    val bg = Color(0xFFFFFFFF)
    val raised = Color(0xFFFFFFFF)
    val overlay = Color(0xFFF5F3FF)
    val input = Color(0xFFF5F3FF)
    val accent = Color(0xFF7C3AED)
    val accentDeep = Color(0xFF5B21B6)
    val accentLavender = Color(0xFFA78BFA)
    val textHi = Color(0xFF18181B)
    val textMid = Color(0xFF52525B)
    val textLow = Color(0xFF9A9AA2)
    val success = Color(0xFF167347)
    val warning = Color(0xFF855400)
    val danger = Color(0xFFA52A36)
    val border = Color(0xFFE8E3F5)
}

private val XyDeskTypography = Typography(
    displayLarge = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 34.sp, lineHeight = 40.sp, letterSpacing = (-1).sp),
    headlineMedium = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 24.sp, lineHeight = 30.sp, letterSpacing = (-0.5).sp),
    headlineSmall = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 20.sp, lineHeight = 26.sp, letterSpacing = (-0.25).sp),
    titleLarge = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, lineHeight = 23.sp),
    titleMedium = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, lineHeight = 20.sp),
    bodyLarge = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Normal, fontSize = 14.sp, lineHeight = 21.sp),
    bodyMedium = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Normal, fontSize = 13.sp, lineHeight = 20.sp),
    bodySmall = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Normal, fontSize = 12.sp, lineHeight = 18.sp),
    labelLarge = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, lineHeight = 18.sp),
    labelMedium = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Medium, fontSize = 12.sp, lineHeight = 16.sp),
)

@Composable
fun XyDeskTheme(content: @Composable () -> Unit) {
    val scheme = lightColorScheme(
        primary = XyDeskColors.accent,
        onPrimary = Color.White,
        primaryContainer = XyDeskColors.overlay,
        onPrimaryContainer = XyDeskColors.accentDeep,
        secondary = XyDeskColors.accentLavender,
        background = XyDeskColors.bg,
        onBackground = XyDeskColors.textHi,
        surface = XyDeskColors.raised,
        onSurface = XyDeskColors.textHi,
        surfaceVariant = XyDeskColors.overlay,
        onSurfaceVariant = XyDeskColors.textMid,
        outline = Color.Transparent,
        error = XyDeskColors.danger,
    )
    MaterialTheme(
        colorScheme = scheme,
        typography = XyDeskTypography,
        shapes = MaterialTheme.shapes.copy(
            extraSmall = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
            small = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
            medium = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
            large = androidx.compose.foundation.shape.RoundedCornerShape(20.dp),
            extraLarge = androidx.compose.foundation.shape.RoundedCornerShape(24.dp),
        ),
        content = content,
    )
}

val XyDeskButtonColors
    @Composable get() = ButtonDefaults.buttonColors(
        containerColor = XyDeskColors.accent,
        contentColor = Color.White,
        disabledContainerColor = XyDeskColors.overlay,
        disabledContentColor = XyDeskColors.textLow,
    )

val XyDeskOutlinedButtonColors
    @Composable get() = ButtonDefaults.outlinedButtonColors(
        contentColor = XyDeskColors.accentDeep,
        disabledContentColor = XyDeskColors.textLow,
    )

val XyDeskCardColors
    @Composable get() = CardDefaults.cardColors(
        containerColor = XyDeskColors.overlay,
    )

val XyDeskTextFieldColors
    @Composable get() = OutlinedTextFieldDefaults.colors(
        focusedBorderColor = XyDeskColors.accent,
        unfocusedBorderColor = Color.Transparent,
        disabledBorderColor = Color.Transparent,
        errorBorderColor = XyDeskColors.danger,
        focusedLabelColor = XyDeskColors.accentDeep,
        unfocusedLabelColor = XyDeskColors.textMid,
        cursorColor = XyDeskColors.accent,
        focusedContainerColor = XyDeskColors.input,
        unfocusedContainerColor = XyDeskColors.input,
    )
