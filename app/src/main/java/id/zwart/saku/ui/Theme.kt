package id.zwart.saku.ui

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

object SakuColors {
    val cream = Color(0xFFFAF8F5)
    val card = Color(0xFFFFFFFF)
    val ink = Color(0xFF2B241D)
    val inkSoft = Color(0xFF8A8074)
    val warm = Color(0xFFFFB84C)
    val warmDeep = Color(0xFFE8930C)
    val mint = Color(0xFF7FC8A9)
    val mintDeep = Color(0xFF3E8E6C)
    val rose = Color(0xFFF6A4A4)
    val danger = Color(0xFFD6675E)
    val mascotBody = Color(0xFFFFF3DC)
    val mascotLine = Color(0xFF5B4636)

    val palette = listOf(
        Color(0xFFFFB84C),
        Color(0xFF7FC8A9),
        Color(0xFFF6A4A4),
        Color(0xFF9BB8E8),
        Color(0xFFC9A7E8),
        Color(0xFFF8C471),
        Color(0xFF96CEB4),
        Color(0xFFE8A2B8)
    )
}

private val LightScheme = lightColorScheme(
    primary = SakuColors.warmDeep,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFE7C2),
    onPrimaryContainer = SakuColors.ink,
    secondary = SakuColors.mintDeep,
    onSecondary = Color.White,
    background = SakuColors.cream,
    onBackground = SakuColors.ink,
    surface = SakuColors.card,
    onSurface = SakuColors.ink,
    surfaceVariant = Color(0xFFF1ECE5),
    onSurfaceVariant = SakuColors.ink,
    outline = Color(0xFFE4DDD2)
)

@Composable
fun SakuTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightScheme,
        shapes = SakuShapes,
        content = content
    )
}

private val SakuShapes = Shapes(
    small = RoundedCornerShape(10.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(24.dp)
)
