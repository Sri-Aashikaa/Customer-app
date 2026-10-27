package com.example.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Store
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.DairyBluePrimary

data class TimelineStep(
    val title: String,
    val subtitle: String,
    val icon: ImageVector,
    val statusKey: String
)

val DELIVERY_STEPS = listOf(
    TimelineStep("Scheduled", "Order queued in dairy system", Icons.Default.Schedule, "Scheduled"),
    TimelineStep("Preparing", "Fresh milk bottles chilled & packed", Icons.Default.Store, "Preparing"),
    TimelineStep("Assigned", "Assigned to route delivery agent", Icons.Default.Person, "Assigned to Delivery Person"),
    TimelineStep("Out for Delivery", "Delivery vehicle on the morning route", Icons.Default.LocalShipping, "Out for Delivery"),
    TimelineStep("Near Customer", "Driver within 500m of your location", Icons.Default.NotificationsActive, "Near Customer"),
    TimelineStep("Delivered", "Placed in doorstep insulated box", Icons.Default.Check, "Delivered")
)

@Composable
fun DeliveryTimelineView(
    currentStatus: String,
    expectedTime: String,
    actualDeliveredTime: String?,
    modifier: Modifier = Modifier
) {
    val isCancelled = currentStatus.equals("Cancelled", ignoreCase = true)
    val isFailed = currentStatus.equals("Delivery Failed", ignoreCase = true)

    val currentStepIndex = when {
        isCancelled || isFailed -> -1
        currentStatus == "Delivered" -> 5
        currentStatus == "Near Customer" -> 4
        currentStatus == "Out for Delivery" -> 3
        currentStatus == "Assigned to Delivery Person" -> 2
        currentStatus == "Preparing" -> 1
        else -> 0
    }

    Column(modifier = modifier.fillMaxWidth()) {
        if (isCancelled || isFailed) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (isCancelled) Color(0xFFF3F4F6) else Color(0xFFFEE2E2))
                    .padding(14.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = null,
                        tint = if (isCancelled) Color(0xFF4B5563) else Color(0xFFDC2626),
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Column {
                        Text(
                            text = if (isCancelled) "Delivery Cancelled" else "Delivery Attempt Failed",
                            fontWeight = FontWeight.Bold,
                            color = if (isCancelled) Color(0xFF374151) else Color(0xFF991B1B),
                            fontSize = 14.sp
                        )
                        Text(
                            text = if (isCancelled) "Delivery paused as per approved customer request." else "Delivery partner could not access gate. Will retry next slot.",
                            fontSize = 12.sp,
                            color = if (isCancelled) Color(0xFF6B7280) else Color(0xFFB91C1C)
                        )
                    }
                }
            }
        } else {
            DELIVERY_STEPS.forEachIndexed { index, step ->
                val isCompleted = index < currentStepIndex
                val isCurrent = index == currentStepIndex
                val isPending = index > currentStepIndex

                val stepColor by animateColorAsState(
                    targetValue = when {
                        isCurrent -> DairyBluePrimary
                        isCompleted -> Color(0xFF16A34A)
                        else -> Color(0xFFCBD5E1)
                    },
                    label = "stepColor"
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.Top
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.width(36.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(30.dp)
                                .clip(CircleShape)
                                .background(
                                    when {
                                        isCurrent -> DairyBluePrimary
                                        isCompleted -> Color(0xFF16A34A)
                                        else -> Color(0xFFF1F5F9)
                                    }
                                )
                                .border(
                                    width = 2.dp,
                                    color = if (isCurrent) DairyBluePrimary else Color.Transparent,
                                    shape = CircleShape
                                ),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                imageVector = if (isCompleted) Icons.Default.Check else step.icon,
                                contentDescription = null,
                                tint = if (isCompleted || isCurrent) Color.White else Color(0xFF94A3B8),
                                modifier = Modifier.size(16.dp)
                            )
                        }

                        if (index < DELIVERY_STEPS.size - 1) {
                            Box(
                                modifier = Modifier
                                    .width(2.dp)
                                    .height(34.dp)
                                    .background(
                                        if (index < currentStepIndex) Color(0xFF16A34A) else Color(0xFFE2E8F0)
                                    )
                            )
                        }
                    }

                    Spacer(modifier = Modifier.width(10.dp))

                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .padding(bottom = if (index < DELIVERY_STEPS.size - 1) 18.dp else 4.dp)
                    ) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = step.title,
                                fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.SemiBold,
                                color = if (isCurrent) DairyBluePrimary else if (isCompleted) Color(0xFF1E293B) else Color(0xFF94A3B8),
                                fontSize = 13.sp
                            )
                            if (isCurrent) {
                                Spacer(modifier = Modifier.width(8.dp))
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(4.dp))
                                        .background(Color(0xFFE0E7FF))
                                        .padding(horizontal = 6.dp, vertical = 2.dp)
                                ) {
                                    Text(
                                        text = "In Progress",
                                        fontSize = 9.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = DairyBluePrimary
                                    )
                                }
                            }
                        }
                        Text(
                            text = if (step.statusKey == "Delivered" && actualDeliveredTime != null) {
                                "Completed at $actualDeliveredTime"
                            } else if (isCurrent && step.statusKey == "Out for Delivery") {
                                "Expected at $expectedTime"
                            } else {
                                step.subtitle
                            },
                            fontSize = 11.sp,
                            color = if (isPending) Color(0xFF94A3B8) else Color(0xFF64748B)
                        )
                    }
                }
            }
        }
    }
}
