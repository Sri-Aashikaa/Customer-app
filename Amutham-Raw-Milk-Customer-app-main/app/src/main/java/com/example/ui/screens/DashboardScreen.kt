package com.example.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.PauseCircle
import androidx.compose.material.icons.filled.Payment
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.model.CustomerEntity
import com.example.data.model.DeliveryPersonEntity
import com.example.data.model.DeliveryScheduleEntity
import com.example.data.model.DepositDetailEntity
import com.example.data.model.PaymentEntity
import com.example.ui.components.PayNowDialog
import com.example.ui.components.StatusBadge
import com.example.ui.theme.DairyAmber
import com.example.ui.theme.DairyAmberContainer
import com.example.ui.theme.DairyBlueContainer
import com.example.ui.theme.DairyBlueLight
import com.example.ui.theme.DairyBlueOnContainer
import com.example.ui.theme.DairyBluePrimary
import com.example.ui.theme.DairyGreenSecondary

@Composable
fun DashboardScreen(
    customer: CustomerEntity,
    todayDelivery: DeliveryScheduleEntity?,
    nextDelivery: DeliveryScheduleEntity?,
    assignedPerson: DeliveryPersonEntity?,
    depositDetail: DepositDetailEntity?,
    pendingPayment: PaymentEntity?,
    onNavigateToDelivery: () -> Unit,
    onNavigateToPayment: () -> Unit,
    onNavigateToDeposit: () -> Unit,
    onProcessPayment: (payment: PaymentEntity, method: String, ref: String) -> Unit,
    onAdvanceDeliveryStatus: (Long, String) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var showPayDialog by remember { mutableStateOf(false) }
    var showSimulationPanel by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        // Customer Welcome Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = "Good Morning,",
                    fontSize = 13.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = customer.fullName,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "ID: ${customer.customerIdNo}",
                        fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = DairyBluePrimary
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .background(Color(0xFFDCFCE7))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = customer.accountStatus,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFF16A34A)
                        )
                    }
                }
            }

            // Simulator button to easily test state changes
            OutlinedButton(
                onClick = { showSimulationPanel = !showSimulationPanel },
                modifier = Modifier.testTag("admin_sim_toggle_button")
            ) {
                Icon(Icons.Default.Tune, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text("Simulate", fontSize = 11.sp)
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Animated Milk Wave Card
        com.example.ui.components.MilkWaveAnimationCard(
            title = "Amutham Organic Raw Milk",
            subtitle = "${customer.dailyQuantityLitres} Litres Daily • Delivered 05:30 - 07:00 AM"
        )

        // Optional Simulation Panel
        AnimatedVisibility(visible = showSimulationPanel) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
                border = CardDefaults.outlinedCardBorder()
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(
                        text = "Delivery Simulation Control (Admin Flow)",
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        color = DairyBluePrimary
                    )
                    Text(
                        text = "Advance today's delivery status to test live tracker & customer updates:",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        listOf("Preparing", "Out for Delivery", "Near Customer", "Delivered").forEach { nextStatus ->
                            OutlinedButton(
                                onClick = {
                                    todayDelivery?.let { onAdvanceDeliveryStatus(it.id, nextStatus) }
                                },
                                modifier = Modifier.weight(1f)
                            ) {
                                Text(nextStatus.take(8), fontSize = 9.sp)
                            }
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Card 1: Today's Delivery Summary Card
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onNavigateToDelivery() }
                .testTag("todays_delivery_card"),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            border = CardDefaults.outlinedCardBorder()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(DairyBlueContainer),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.LocalShipping,
                                contentDescription = "Today's Delivery",
                                tint = DairyBluePrimary,
                                modifier = Modifier.size(22.dp)
                            )
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = "Today's Delivery",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = todayDelivery?.deliveryDate ?: "No delivery scheduled today",
                                fontSize = 12.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    StatusBadge(status = todayDelivery?.status ?: "Scheduled")
                }

                Spacer(modifier = Modifier.height(14.dp))

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(10.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        .padding(12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column {
                        Text("Milk Quantity", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "${todayDelivery?.quantityLitres ?: customer.dailyQuantityLitres} L",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = DairyBluePrimary
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Surface(
                                shape = CircleShape,
                                color = Color(0xFFDCFCE7),
                                modifier = Modifier.size(20.dp)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Text("+", fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF16A34A))
                                }
                            }
                        }
                        Text(
                            text = todayDelivery?.milkType ?: customer.milkType,
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Column(horizontalAlignment = Alignment.End) {
                        Text("Expected Arrival", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            text = todayDelivery?.expectedTime ?: customer.regularTimeSlot.split("-").firstOrNull() ?: "06:15 AM",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = if (todayDelivery?.status == "Delivered") "Delivered on time" else "Regular Slot: ${customer.regularTimeSlot}",
                            fontSize = 10.sp,
                            color = if (todayDelivery?.status == "Delivered") Color(0xFF16A34A) else MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                if (todayDelivery?.delayMessage != null) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        color = DairyAmberContainer,
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Info, contentDescription = null, tint = DairyAmber, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = todayDelivery.delayMessage,
                                fontSize = 11.sp,
                                color = Color(0xFF7C2D12),
                                fontWeight = FontWeight.Medium
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "View live delivery details & timeline",
                        fontSize = 12.sp,
                        color = DairyBluePrimary,
                        fontWeight = FontWeight.SemiBold
                    )
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                        contentDescription = null,
                        tint = DairyBluePrimary,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Card 2: Payment Due Card
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onNavigateToPayment() }
                .testTag("payment_due_card"),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            border = CardDefaults.outlinedCardBorder()
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(Color(0xFFE0F2FE)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.Payment,
                                contentDescription = "Payment Due",
                                tint = DairyBluePrimary,
                                modifier = Modifier.size(22.dp)
                            )
                        }
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text("Payment Due", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                            Text(pendingPayment?.billingPeriod ?: "Current Billing Cycle", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }

                    StatusBadge(status = pendingPayment?.status ?: "Paid")
                }

                Spacer(modifier = Modifier.height(14.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text("Current Amount Due", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text(
                            text = "₹${"%.2f".format(pendingPayment?.amountDue ?: 0.0)}",
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold,
                            color = if ((pendingPayment?.amountDue ?: 0.0) > 0) Color(0xFFDC2626) else Color(0xFF16A34A)
                        )
                        Text(
                            text = "Due Date: ${pendingPayment?.dueDate ?: "All Clear"}",
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    if ((pendingPayment?.amountDue ?: 0.0) > 0) {
                        Button(
                            onClick = { showPayDialog = true },
                            colors = ButtonDefaults.buttonColors(containerColor = DairyBluePrimary),
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier.testTag("dashboard_pay_now_button")
                        ) {
                            Text("Pay Now", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                        }
                    } else {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color(0xFFDCFCE7))
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text("No Dues Pending", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color(0xFF16A34A))
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Row of 2 Cards: Deposit Balance & Next Delivery
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Deposit Balance Card
            Card(
                modifier = Modifier
                    .weight(1f)
                    .clickable { onNavigateToDeposit() }
                    .testTag("deposit_balance_card"),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = CardDefaults.outlinedCardBorder()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier
                                .size(32.dp)
                                .clip(CircleShape)
                                .background(Color(0xFFDCFCE7)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Default.Inventory2,
                                contentDescription = "Deposit Balance",
                                tint = DairyGreenSecondary,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                        Text(
                            text = "₹${"%.0f".format(depositDetail?.totalDepositPaid ?: 700.0)}",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                            color = DairyGreenSecondary
                        )
                    }
                    Spacer(modifier = Modifier.height(10.dp))
                    Text("Deposit Balance", fontSize = 13.sp, fontWeight = FontWeight.Bold)
                    Text(
                        text = "${depositDetail?.bottleQty ?: 4} Bottles • ${depositDetail?.iceBoxQty ?: 1} Ice Box",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text("100% Refundable", fontSize = 10.sp, color = Color(0xFF16A34A), fontWeight = FontWeight.SemiBold)
                }
            }

            // Next Delivery Card
            Card(
                modifier = Modifier
                    .weight(1f)
                    .clickable { onNavigateToDelivery() }
                    .testTag("next_delivery_card"),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = CardDefaults.outlinedCardBorder()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(Icons.Default.Schedule, contentDescription = null, tint = DairyBluePrimary, modifier = Modifier.size(20.dp))
                        Text(
                            text = nextDelivery?.dayOfWeek?.take(3) ?: "Sun",
                            fontWeight = FontWeight.Bold,
                            fontSize = 12.sp,
                            color = DairyBluePrimary
                        )
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Next Delivery", fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Text(
                        text = nextDelivery?.deliveryDate ?: "Tomorrow",
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text("Slot: ${customer.regularTimeSlot}", fontSize = 9.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))

        // Card 3: Assigned Delivery Person Card
        assignedPerson?.let { agent ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = CardDefaults.outlinedCardBorder()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(44.dp)
                                    .clip(CircleShape)
                                    .background(DairyBlueContainer),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.Person, contentDescription = null, tint = DairyBluePrimary, modifier = Modifier.size(24.dp))
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(agent.name, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                    Spacer(modifier = Modifier.width(6.dp))
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFEAB308), modifier = Modifier.size(13.dp))
                                        Text(text = "${agent.rating}", fontSize = 11.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                                Text("Employee ID: ${agent.employeeId}", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(agent.assignedRoute, fontSize = 10.sp, color = DairyBluePrimary, fontWeight = FontWeight.Medium)
                            }
                        }

                        Button(
                            onClick = {
                                val intent = Intent(Intent.ACTION_DIAL).apply {
                                    data = Uri.parse("tel:${agent.mobile}")
                                }
                                context.startActivity(intent)
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = DairyGreenSecondary),
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier.testTag("call_delivery_person_button")
                        ) {
                            Icon(Icons.Default.Call, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Call", fontSize = 12.sp)
                        }
                    }
                }
            }
        }
    }

    if (showPayDialog && pendingPayment != null) {
        PayNowDialog(
            payment = pendingPayment,
            onDismiss = { showPayDialog = false },
            onConfirmPayment = { method, ref ->
                onProcessPayment(pendingPayment, method, ref)
            }
        )
    }
}
