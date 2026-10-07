package id.zwart.saku.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

enum class Mood { IDLE, HAPPY, LISTENING, THINKING, SURPRISED }

/**
 * Mascot "Saku" — kantong uang mungil yang digambar total pakai Compose Canvas,
 * tanpa aset gambar supaya APK tetap ringan.
 */
@Composable
fun Mascot(
    mood: Mood = Mood.IDLE,
    size: Dp = 48.dp,
    modifier: Modifier = Modifier
) {
    Canvas(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(Color(0xFFF2EDE4))
    ) {
        val w = this.size.width
        val h = this.size.height
        val line = SakuColors.mascotLine

        // badan kantong
        drawCircle(
            color = SakuColors.mascotBody,
            radius = w * 0.34f,
            center = Offset(w * 0.5f, h * 0.56f)
        )
        drawCircle(
            color = line,
            radius = w * 0.34f,
            center = Offset(w * 0.5f, h * 0.56f),
            style = Stroke(width = w * 0.045f)
        )

        // simpul tali
        drawRoundRect(
            color = line,
            topLeft = Offset(w * 0.42f, h * 0.18f),
            size = Size(w * 0.16f, h * 0.09f),
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.04f)
        )

        // mata
        val eyeR = w * 0.055f
        val eyeY = h * 0.50f
        val eyeSpacing = w * 0.11f
        when (mood) {
            Mood.HAPPY -> {
                drawArc(
                    color = line,
                    startAngle = 200f,
                    sweepAngle = 140f,
                    useCenter = false,
                    topLeft = Offset(w * 0.5f - eyeSpacing - eyeR, eyeY),
                    size = Size(eyeR * 2f, eyeR * 1.6f),
                    style = Stroke(w * 0.04f, cap = StrokeCap.Round)
                )
                drawArc(
                    color = line,
                    startAngle = 200f,
                    sweepAngle = 140f,
                    useCenter = false,
                    topLeft = Offset(w * 0.5f + eyeSpacing - eyeR, eyeY),
                    size = Size(eyeR * 2f, eyeR * 1.6f),
                    style = Stroke(w * 0.04f, cap = StrokeCap.Round)
                )
            }
            else -> {
                drawCircle(line, eyeR, Offset(w * 0.5f - eyeSpacing, eyeY))
                drawCircle(line, eyeR, Offset(w * 0.5f + eyeSpacing, eyeY))
            }
        }

        // pipi
        drawCircle(
            color = Color(0xFFF6A4A4).copy(alpha = 0.55f),
            radius = w * 0.05f,
            center = Offset(w * 0.5f - w * 0.19f, h * 0.6f)
        )
        drawCircle(
            color = Color(0xFFF6A4A4).copy(alpha = 0.55f),
            radius = w * 0.05f,
            center = Offset(w * 0.5f + w * 0.19f, h * 0.6f)
        )

        // mulut
        when (mood) {
            Mood.LISTENING -> drawCircle(
                color = line,
                radius = w * 0.05f,
                center = Offset(w * 0.5f, h * 0.68f)
            )
            Mood.SURPRISED -> drawCircle(
                color = line,
                radius = w * 0.045f,
                center = Offset(w * 0.5f, h * 0.69f)
            )
            else -> drawArc(
                color = line,
                startAngle = -25f,
                sweepAngle = if (mood == Mood.HAPPY) 70f else 50f,
                useCenter = false,
                topLeft = Offset(w * 0.40f, h * 0.58f),
                size = Size(w * 0.20f, h * 0.10f),
                style = Stroke(w * 0.04f, cap = StrokeCap.Round)
            )
        }
    }
}
