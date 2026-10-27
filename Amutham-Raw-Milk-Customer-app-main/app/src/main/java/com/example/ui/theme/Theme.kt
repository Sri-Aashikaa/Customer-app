package com.example.ui.theme

import android.os.Build
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val FreshWhiteGreenColorScheme = lightColorScheme(
    primary = DairyGreenPrimary,
    onPrimary = Color.White,
    primaryContainer = DairyGreenContainer,
    onPrimaryContainer = DairyGreenOnContainer,
    secondary = DairyGreenLight,
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFD1FAE5),
    onSecondaryContainer = Color(0xFF065F46),
    tertiary = DairyAmber,
    onTertiary = Color.White,
    tertiaryContainer = DairyAmberContainer,
    onTertiaryContainer = Color(0xFF78350F),
    background = CleanBackground,
    onBackground = TextPrimary,
    surface = PureSurface,
    onSurface = TextPrimary,
    surfaceVariant = Color(0xFFF1F5F9),
    onSurfaceVariant = TextSecondary,
    outline = CardBorderColor
)

@Composable
fun MyApplicationTheme(
    darkTheme: Boolean = false, // Enforce crisp fresh white theme with green accents
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = FreshWhiteGreenColorScheme,
        typography = Typography,
        content = content
    )
}
