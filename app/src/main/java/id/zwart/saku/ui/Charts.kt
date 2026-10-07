package id.zwart.saku.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import id.zwart.saku.data.ChartKind
import id.zwart.saku.data.Expense
import id.zwart.saku.data.ExpenseRepository
import id.zwart.saku.ai.MoneyAgent

data class DailyBucket(val date: String, val total: Long)

fun dailyBuckets(expenses: List<Expense>): List<DailyBucket> =
    expenses.groupBy { ExpenseRepository.dateOf(it.timestamp) }
        .map { (day, list) -> DailyBucket(day, list.sumOf { it.amount }) }
        .sortedBy { it.date }

fun categoryTotals(expenses: List<Expense>): List<Pair<String, Long>> =
    expenses.groupBy { it.category }
        .map { (cat, list) -> cat to list.sumOf { it.amount } }
        .sortedByDescending { it.second }

@Composable
fun ChartView(kind: ChartKind, expenses: List<Expense>, modifier: Modifier = Modifier) {
    when (kind) {
        ChartKind.BAR -> BarChart(expenses, modifier)
        ChartKind.LINE -> LineChart(expenses, modifier)
        ChartKind.PIE -> PieChart(expenses, modifier)
    }
}

@Composable
private fun EmptyChart() {
    Box(
        Modifier
            .fillMaxWidth()
            .height(150.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            "Belum ada data di rentang ini",
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            fontSize = 13.sp
        )
    }
}

@Composable
fun BarChart(expenses: List<Expense>, modifier: Modifier = Modifier) {
    val buckets = dailyBuckets(expenses).takeLast(14)
    if (buckets.isEmpty()) {
        EmptyChart()
        return
    }
    val maxValue = buckets.maxOf { it.total }.coerceAtLeast(1L)
    Canvas(
        modifier
            .fillMaxWidth()
            .height(150.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xFFF4F0E9))
    ) {
        val count = buckets.size
        val slot = size.width / count
        val barWidth = slot * 0.52f
        buckets.forEachIndexed { index, bucket ->
            val height = (bucket.total.toFloat() / maxValue.toFloat()) * (size.height * 0.86f)
            val x = index * slot + (slot - barWidth) / 2f
            drawRoundRect(
                color = SakuColors.warm,
                topLeft = Offset(x, size.height - height - 12.dp.toPx()),
                size = Size(barWidth, height),
                cornerRadius = CornerRadius(barWidth / 2.2f, barWidth / 2.2f)
            )
        }
    }
    Spacer(Modifier.height(4.dp))
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        buckets.takeLast(4).forEach { bucket ->
            Text(
                bucket.date.takeLast(5),
                fontSize = 9.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
fun LineChart(expenses: List<Expense>, modifier: Modifier = Modifier) {
    val buckets = dailyBuckets(expenses).takeLast(14)
    if (buckets.isEmpty()) {
        EmptyChart()
        return
    }
    val maxValue = buckets.maxOf { it.total }.coerceAtLeast(1L)
    Canvas(
        modifier
            .fillMaxWidth()
            .height(150.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(Color(0xFFF4F0E9))
    ) {
        if (buckets.size == 1) {
            val cx = size.width / 2f
            val cy = size.height - (buckets[0].total.toFloat() / maxValue.toFloat()) * (size.height * 0.86f)
            drawCircle(SakuColors.mintDeep, 8.dp.toPx(), Offset(cx, cy))
            return@Canvas
        }
        val stepX = size.width / (buckets.size - 1)
        val path = Path()
        buckets.forEachIndexed { index, bucket ->
            val x = index * stepX
            val y = size.height - (bucket.total.toFloat() / maxValue.toFloat()) * (size.height * 0.82f) - 10.dp.toPx()
            if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        drawPath(
            path,
            color = SakuColors.mintDeep,
            style = Stroke(width = 5f, cap = StrokeCap.Round)
        )
        buckets.forEachIndexed { index, bucket ->
            val x = index * stepX
            val y = size.height - (bucket.total.toFloat() / maxValue.toFloat()) * (size.height * 0.82f) - 10.dp.toPx()
            drawCircle(SakuColors.mint, 9f, Offset(x, y))
            drawCircle(SakuColors.mintDeep, 4f, Offset(x, y))
        }
    }
    Spacer(Modifier.height(4.dp))
    Row(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        buckets.takeLast(4).forEach { bucket ->
            Text(
                bucket.date.takeLast(5),
                fontSize = 9.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
fun PieChart(expenses: List<Expense>, modifier: Modifier = Modifier) {
    val totals = categoryTotals(expenses)
    if (totals.isEmpty()) {
        EmptyChart()
        return
    }
    val sum = totals.sumOf { it.second }.coerceAtLeast(1L)
    Column(modifier.fillMaxWidth()) {
        Canvas(
            Modifier
                .fillMaxWidth()
                .height(150.dp)
                .padding(horizontal = 8.dp)
        ) {
            val radius = minOf(size.width, size.height) / 2.4f
            val center = Offset(size.width / 2f, size.height / 2f)
            var startAngle = -90f
            totals.forEachIndexed { index, (_, total) ->
                val sweep = 360f * (total.toFloat() / sum.toFloat())
                drawArc(
                    color = SakuColors.palette[index % SakuColors.palette.size],
                    startAngle = startAngle,
                    sweepAngle = sweep,
                    useCenter = true,
                    topLeft = Offset(center.x - radius, center.y - radius),
                    size = Size(radius * 2f, radius * 2f)
                )
                startAngle += sweep
            }
            drawCircle(
                color = SakuColors.card,
                radius = radius * 0.45f,
                center = center
            )
        }
        Spacer(Modifier.height(8.dp))
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            totals.take(6).forEachIndexed { index, (category, total) ->
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            Modifier
                                .padding(end = 6.dp)
                                .size(12.dp)
                                .background(
                                    SakuColors.palette[index % SakuColors.palette.size],
                                    RoundedCornerShape(6.dp)
                                )
                        )
                        Text(category, fontSize = 12.sp)
                    }
                    Text(
                        MoneyAgent.formatRupiah(total),
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

