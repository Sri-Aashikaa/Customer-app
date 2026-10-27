package com.example.ui.screens

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Assessment
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.model.CancellationRequestEntity
import com.example.data.model.DeliveryScheduleEntity
import com.example.data.model.DepositTransactionEntity
import com.example.data.model.PaymentEntity
import com.example.ui.components.ChartBarData
import com.example.ui.components.DeliveryVolumeBarChart
import com.example.ui.components.StatusBadge
import com.example.ui.components.SummaryMetricCard
import com.example.ui.theme.DairyBluePrimary
import com.example.ui.theme.DairyGreenSecondary

@Composable
fun ReportsScreen(
    deliveries: List<DeliveryScheduleEntity>,
    payments: List<PaymentEntity>,
    cancellations: List<CancellationRequestEntity>,
    deposits: List<DepositTransactionEntity>,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var selectedFilterIndex by remember { mutableIntStateOf(0) } // 0: Daily, 1: Weekly, 2: Monthly, 3: Yearly

    val filterLabels = listOf("Daily", "Weekly", "Monthly", "Yearly")

    val deliveredOnly = deliveries.filter { it.status == "Delivered" }
    val totalLitresDelivered = deliveredOnly.sumOf { it.quantityLitres }
    val totalDeliveriesCount = deliveredOnly.size
    val cancelledDeliveriesCount = deliveries.count { it.status == "Cancelled" }
    val totalBilled = payments.sumOf { it.amountDue }
    val totalPaid = payments.sumOf { it.amountPaid }
    val outstandingAmount = totalBilled - totalPaid

    // Chart dataset based on selected filter
    val chartData = when (selectedFilterIndex) {
        0 -> listOf(
            ChartBarData("Mon 21", 1.5f),
            ChartBarData("Tue 22", 1.5f),
            ChartBarData("Wed 23", 0.0f),
            ChartBarData("Thu 24", 1.5f),
            ChartBarData("Fri 25", 1.5f),
            ChartBarData("Sat 26", 1.5f)
        )
        1 -> listOf(
            ChartBarData("Wk 1", 10.5f),
            ChartBarData("Wk 2", 9.0f),
            ChartBarData("Wk 3", 10.5f),
            ChartBarData("Wk 4", 7.5f)
        )
        2 -> listOf(
            ChartBarData("Jun", 42f),
            ChartBarData("Jul", 45f),
            ChartBarData("Aug", 43.5f),
            ChartBarData("Sep", 39f)
        )
        else -> listOf(
            ChartBarData("2024", 480f),
            ChartBarData("2025", 520f),
            ChartBarData("2026", 410f)
        )
    }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Report Filter Tabs
        item {
            TabRow(
                selectedTabIndex = selectedFilterIndex,
                containerColor = MaterialTheme.colorScheme.surface,
                contentColor = DairyBluePrimary
            ) {
                filterLabels.forEachIndexed { index, label ->
                    Tab(
                        selected = selectedFilterIndex == index,
                        onClick = { selectedFilterIndex = index },
                        text = { Text(label, fontWeight = FontWeight.SemiBold, fontSize = 12.sp) },
                        modifier = Modifier.testTag("report_tab_$index")
                    )
                }
            }
        }

        // Export Button Header
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "${filterLabels[selectedFilterIndex]} Delivery & Audit Report",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text("Aggregated milk volume and billing metrics", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }

                Button(
                    onClick = {
                        val reportType = filterLabels[selectedFilterIndex]
                        val exportText = """
                            === MILKFLOW DAIRY ${reportType.uppercase()} REPORT ===
                            Generated Date: 2026-09-26
                            Total Milk Delivered: ${"%.1f".format(totalLitresDelivered)} Litres
                            Successful Deliveries: $totalDeliveriesCount
                            Cancelled Deliveries: $cancelledDeliveriesCount
                            Total Billing: ₹${"%.2f".format(totalBilled)}
                            Amount Paid: ₹${"%.2f".format(totalPaid)}
                            Outstanding Balance: ₹${"%.2f".format(outstandingAmount)}
                            Total Deposit Transactions: ${deposits.size}
                            -------------------------------------------
                            CSV Export format:
                            Period,LitresDelivered,Deliveries,Cancelled,Billing,Paid,Outstanding
                            $reportType,${"%.1f".format(totalLitresDelivered)},$totalDeliveriesCount,$cancelledDeliveriesCount,${"%.2f".format(totalBilled)},${"%.2f".format(totalPaid)},${"%.2f".format(outstandingAmount)}
                        """.trimIndent()

                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(Intent.EXTRA_TEXT, exportText)
                            type = "text/plain"
                        }
                        context.startActivity(Intent.createChooser(sendIntent, "Export Milk Report (CSV/PDF)"))
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = DairyBluePrimary),
                    shape = RoundedCornerShape(10.dp),
                    modifier = Modifier.testTag("export_report_button")
                ) {
                    Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Export / PDF", fontSize = 12.sp)
                }
            }
        }

        // Summary Metric Cards Grid
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                SummaryMetricCard(
                    title = "Delivered Milk",
                    value = "${"%.1f".format(totalLitresDelivered)} L",
                    subtitle = "$totalDeliveriesCount deliveries",
                    iconColor = DairyBluePrimary,
                    modifier = Modifier.weight(1f)
                )
                SummaryMetricCard(
                    title = "Cancelled",
                    value = "$cancelledDeliveriesCount",
                    subtitle = "Authorized pauses",
                    iconColor = Color(0xFFD97706),
                    modifier = Modifier.weight(1f)
                )
            }
        }

        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                SummaryMetricCard(
                    title = "Total Billing",
                    value = "₹${"%.2f".format(totalBilled)}",
                    subtitle = "Paid: ₹${"%.2f".format(totalPaid)}",
                    iconColor = DairyGreenSecondary,
                    modifier = Modifier.weight(1f)
                )
                SummaryMetricCard(
                    title = "Outstanding",
                    value = "₹${"%.2f".format(outstandingAmount)}",
                    subtitle = if (outstandingAmount > 0) "Payment due" else "All clear",
                    iconColor = if (outstandingAmount > 0) Color(0xFFDC2626) else Color(0xFF16A34A),
                    modifier = Modifier.weight(1f)
                )
            }
        }

        // Visual Volume Chart
        item {
            DeliveryVolumeBarChart(
                data = chartData,
                unitLabel = if (selectedFilterIndex >= 2) "Litres / Month" else "Litres"
            )
        }

        // Detailed Table Header
        item {
            Text("Breakdown Table View", fontSize = 14.sp, fontWeight = FontWeight.Bold)
        }

        // Table Rows
        when (selectedFilterIndex) {
            0 -> {
                // Daily Breakdown Table
                items(deliveries) { del ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        border = CardDefaults.outlinedCardBorder()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text("${del.dayOfWeek}, ${del.deliveryDate}", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                Text("${del.quantityLitres}L • ${del.milkType}", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            StatusBadge(status = del.status)
                        }
                    }
                }
            }
            1 -> {
                // Weekly Breakdown Table
                items(listOf("Week 38 (Current)", "Week 37", "Week 36", "Week 35")) { wk ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        border = CardDefaults.outlinedCardBorder()
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column {
                                Text(wk, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                Text("6 Delivered • 1 Cancelled", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("10.5 Litres", fontWeight = FontWeight.Bold, fontSize = 12.sp, color = DairyBluePrimary)
                                Text("Billed: $10.50", fontSize = 10.sp, color = DairyGreenSecondary)
                            }
                        }
                    }
                }
            }
            2 -> {
                // Monthly Breakdown Table
                items(payments) { p ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        border = CardDefaults.outlinedCardBorder()
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column {
                                Text(p.billingPeriod, fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                Text("Deliveries: ~45 Litres", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("$${"%.2f".format(p.amountDue)}", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                StatusBadge(status = p.status)
                            }
                        }
                    }
                }
            }
            else -> {
                // Yearly Table
                items(listOf("2026 (YTD)", "2025", "2024")) { yr ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(10.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        border = CardDefaults.outlinedCardBorder()
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column {
                                Text("Year $yr", fontWeight = FontWeight.Bold, fontSize = 12.sp)
                                Text("340 Deliveries • Deposit: $700", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("510 Litres", fontWeight = FontWeight.Bold, fontSize = 12.sp, color = DairyBluePrimary)
                                Text("Paid: $510.00", fontSize = 10.sp, color = DairyGreenSecondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
