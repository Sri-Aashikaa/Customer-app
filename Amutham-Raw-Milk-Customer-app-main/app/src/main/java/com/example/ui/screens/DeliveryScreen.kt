package com.example.ui.screens

import android.content.Intent
import android.net.Uri
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.EventBusy
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
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
import com.example.data.model.CancellationRequestEntity
import com.example.data.model.CustomerEntity
import com.example.data.model.DeliveryPersonEntity
import com.example.data.model.DeliveryScheduleEntity
import com.example.ui.components.DeliveryTimelineView
import com.example.ui.components.LeafletMapView
import com.example.ui.components.StatusBadge
import com.example.ui.theme.DairyAmber
import com.example.ui.theme.DairyAmberContainer
import com.example.ui.theme.DairyBlueContainer
import com.example.ui.theme.DairyBluePrimary
import com.example.ui.theme.DairyGreenPrimary
import com.example.ui.theme.DairyGreenSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeliveryScreen(
    customer: CustomerEntity,
    todayDelivery: DeliveryScheduleEntity?,
    assignedPerson: DeliveryPersonEntity?,
    cancellationRequests: List<CancellationRequestEntity>,
    onSubmitCancellation: (date: String, day: String, start: String, end: String, reason: String) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var selectedTab by remember { mutableIntStateOf(0) } // 0: Live Delivery & Timing, 1: Pause / Cancellation Permission
    var showCancellationDialog by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        TabRow(
            selectedTabIndex = selectedTab,
            containerColor = MaterialTheme.colorScheme.surface,
            contentColor = DairyBluePrimary
        ) {
            Tab(
                selected = selectedTab == 0,
                onClick = { selectedTab = 0 },
                text = { Text("Live Tracker & Timing", fontWeight = FontWeight.SemiBold, fontSize = 13.sp) }
            )
            Tab(
                selected = selectedTab == 1,
                onClick = { selectedTab = 1 },
                text = { Text("Cancellation Permission", fontWeight = FontWeight.SemiBold, fontSize = 13.sp) }
            )
        }

        if (selectedTab == 0) {
            // TAB 1: Live Delivery, Route Map, and Delivery Timing
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Admin Broadcast Banner if delay or notice
                if (todayDelivery?.delayMessage != null) {
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = DairyAmberContainer),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(14.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.Notifications, contentDescription = null, tint = DairyAmber, modifier = Modifier.size(24.dp))
                                Spacer(modifier = Modifier.width(10.dp))
                                Column {
                                    Text("Dairy Broadcast Notice", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color(0xFF7C2D12))
                                    Text(todayDelivery.delayMessage, fontSize = 12.sp, color = Color(0xFF7C2D12))
                                }
                            }
                        }
                    }
                }

                // Delivery Timing Card
                item {
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
                                Text("Delivery Timing & Schedule", fontSize = 15.sp, fontWeight = FontWeight.Bold)
                                StatusBadge(status = todayDelivery?.status ?: "Scheduled")
                            }

                            Spacer(modifier = Modifier.height(14.dp))

                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Column(
                                    modifier = Modifier
                                        .weight(1f)
                                        .background(Color(0xFFF8FAFC), RoundedCornerShape(10.dp))
                                        .padding(10.dp)
                                ) {
                                    Text("Regular Window", fontSize = 10.sp, color = Color(0xFF64748B), fontWeight = FontWeight.SemiBold)
                                    Text(customer.regularTimeSlot, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF0284C7))
                                }
                                Column(
                                    modifier = Modifier
                                        .weight(1f)
                                        .background(Color(0xFFF8FAFC), RoundedCornerShape(10.dp))
                                        .padding(10.dp)
                                ) {
                                    Text("Expected Today", fontSize = 10.sp, color = Color(0xFF64748B), fontWeight = FontWeight.SemiBold)
                                    Text(todayDelivery?.expectedTime ?: "06:15 AM", fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF0F172A))
                                }
                            }

                            Spacer(modifier = Modifier.height(10.dp))

                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Column(
                                    modifier = Modifier
                                        .weight(1f)
                                        .background(Color(0xFFF8FAFC), RoundedCornerShape(10.dp))
                                        .padding(10.dp)
                                ) {
                                    Text("Delivery Days", fontSize = 10.sp, color = Color(0xFF64748B), fontWeight = FontWeight.SemiBold)
                                    Text(customer.deliveryDays, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF0F172A))
                                }
                                Column(
                                    modifier = Modifier
                                        .weight(1f)
                                        .background(Color(0xFFF8FAFC), RoundedCornerShape(10.dp))
                                        .padding(10.dp)
                                ) {
                                    Text("Today's Milk Qty", fontSize = 10.sp, color = Color(0xFF64748B), fontWeight = FontWeight.SemiBold)
                                    Text("${todayDelivery?.quantityLitres ?: customer.dailyQuantityLitres} Litres Pure", fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF0F172A))
                                }
                            }
                        }
                    }
                }

                // Delivery Person Details Card (or Placeholder if unassigned)
                item {
                    if (assignedPerson != null) {
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("delivery_person_card"),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                            border = CardDefaults.outlinedCardBorder()
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text("Assigned Delivery Person", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                                Spacer(modifier = Modifier.height(10.dp))

                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Box(
                                            modifier = Modifier
                                                .size(46.dp)
                                                .clip(CircleShape)
                                                .background(DairyBlueContainer),
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Icon(
                                                Icons.Default.Person,
                                                contentDescription = "Delivery Person Profile",
                                                tint = DairyBluePrimary,
                                                modifier = Modifier.size(24.dp)
                                            )
                                        }
                                        Spacer(modifier = Modifier.width(12.dp))
                                        Column {
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Text(assignedPerson.name, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                                Spacer(modifier = Modifier.width(4.dp))
                                                Text("• ${assignedPerson.employeeId}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            }
                                            Text(assignedPerson.assignedRoute, fontSize = 11.sp, color = DairyBluePrimary)
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFEAB308), modifier = Modifier.size(12.dp))
                                                Text(" ${assignedPerson.rating} • Status: ${assignedPerson.status}", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            }
                                        }
                                    }

                                    Button(
                                        onClick = {
                                            val intent = Intent(Intent.ACTION_DIAL).apply {
                                                data = Uri.parse("tel:${assignedPerson.mobile}")
                                            }
                                            context.startActivity(intent)
                                        },
                                        colors = ButtonDefaults.buttonColors(containerColor = DairyGreenSecondary),
                                        shape = RoundedCornerShape(10.dp),
                                        modifier = Modifier.testTag("delivery_screen_call_agent_button")
                                    ) {
                                        Icon(Icons.Default.Call, contentDescription = null, modifier = Modifier.size(14.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text("Call", fontSize = 12.sp)
                                    }
                                }
                            }
                        }
                    } else {
                        // Material 3 Placeholder for Delivery Person Information
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .testTag("delivery_person_placeholder_card"),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)),
                            border = CardDefaults.outlinedCardBorder()
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(46.dp)
                                        .clip(CircleShape)
                                        .background(MaterialTheme.colorScheme.outlineVariant),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Icon(
                                        Icons.Default.Person,
                                        contentDescription = "Delivery Person Placeholder",
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(24.dp)
                                    )
                                }
                                Spacer(modifier = Modifier.width(14.dp))
                                Column {
                                    Text(
                                        text = "Delivery Person Information",
                                        fontSize = 14.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                    Text(
                                        text = "Route assignment in progress for morning batch",
                                        fontSize = 11.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Spacer(modifier = Modifier.height(2.dp))
                                    Text(
                                        text = "Employee ID, contact & GPS location will appear upon dispatch",
                                        fontSize = 10.sp,
                                        color = DairyBluePrimary
                                    )
                                }
                            }
                        }
                    }
                }

                // OpenStreetMap Route & Delivery Person Tracker
                item {
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
                                Column {
                                    Text("Delivery Location on Map", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                                    Text("OpenStreetMap route visualization", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                                Box(
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(6.dp))
                                        .background(Color(0xFFE0E7FF))
                                        .padding(horizontal = 8.dp, vertical = 3.dp)
                                ) {
                                    Text("Live GPS", fontSize = 10.sp, color = DairyBluePrimary, fontWeight = FontWeight.Bold)
                                }
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            LeafletMapView(
                                latitude = customer.latitude,
                                longitude = customer.longitude,
                                deliveryPersonLat = assignedPerson?.currentLatitude,
                                deliveryPersonLng = assignedPerson?.currentLongitude,
                                deliveryPersonName = assignedPerson?.name,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(220.dp)
                            )
                        }
                    }
                }

                // Delivery Status Progression Timeline
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        border = CardDefaults.outlinedCardBorder()
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text("Delivery Progress Timeline", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                            Text("Live status progression from farm chiller to doorstep", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Spacer(modifier = Modifier.height(14.dp))

                            DeliveryTimelineView(
                                currentStatus = todayDelivery?.status ?: "Scheduled",
                                expectedTime = todayDelivery?.expectedTime ?: "06:15 AM",
                                actualDeliveredTime = todayDelivery?.actualDeliveredTime
                            )
                        }
                    }
                }
            }
        } else {
            // TAB 2: Cancellation Permission & Cutoff Section
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)
            ) {
                // Cutoff Notice Card
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(14.dp),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF3C7)),
                        border = CardDefaults.outlinedCardBorder()
                    ) {
                        Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.Top) {
                            Icon(Icons.Default.Warning, contentDescription = null, tint = Color(0xFFD97706), modifier = Modifier.size(22.dp))
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text("Delivery Cancellation Policy & Cutoff", fontWeight = FontWeight.Bold, fontSize = 13.sp, color = Color(0xFF92400E))
                                Text(
                                    text = "To ensure fresh morning milk dispatch without food waste, cancellation requests must be submitted before 10:00 PM the previous evening. Requests submitted after cutoff will be marked as Expired.",
                                    fontSize = 11.sp,
                                    color = Color(0xFF78350F)
                                )
                            }
                        }
                    }
                }

                // Action Bar: Request Cancellation Button
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("Cancellation Requests", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                            Text("Pause milk delivery for travel or extra stock", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }

                        Button(
                            onClick = { showCancellationDialog = true },
                            colors = ButtonDefaults.buttonColors(containerColor = DairyBluePrimary),
                            shape = RoundedCornerShape(10.dp),
                            modifier = Modifier.testTag("request_cancellation_button")
                        ) {
                            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Request Pause", fontSize = 12.sp)
                        }
                    }
                }

                if (cancellationRequests.isEmpty()) {
                    item {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(24.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Icon(Icons.Default.EventBusy, contentDescription = null, tint = Color(0xFF94A3B8), modifier = Modifier.size(36.dp))
                                Spacer(modifier = Modifier.height(8.dp))
                                Text("No Cancellation Requests", fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                                Text("All scheduled daily deliveries will arrive on time.", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                } else {
                    items(cancellationRequests) { req ->
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                            border = CardDefaults.outlinedCardBorder()
                        ) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column {
                                        Text("${req.dayOfWeek}, ${req.cancelDate}", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                        Text("Time Window: ${req.startTime} to ${req.endTime}", fontSize = 11.sp, color = DairyBluePrimary)
                                    }
                                    StatusBadge(status = req.status)
                                }

                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = "Reason: ${req.reason}",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurface
                                )

                                req.reviewNotes?.let { notes ->
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text(
                                        text = "Admin Note: $notes",
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        fontWeight = FontWeight.Medium
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showCancellationDialog) {
        var cancelDate by remember { mutableStateOf("2026-09-29") }
        var dayOfWeek by remember { mutableStateOf("Tuesday") }
        var selectedShift by remember { mutableStateOf("MORNING") } // "MORNING", "EVENING", "BOTH"
        var startTime by remember { mutableStateOf("05:30 AM") }
        var endTime by remember { mutableStateOf("08:00 AM") }
        var reason by remember { mutableStateOf("Traveling / Out of town") }

        AlertDialog(
            onDismissRequest = { showCancellationDialog = false },
            title = { Text("Request Delivery Pause", fontWeight = FontWeight.Bold) },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = "Select pause date, delivery shift (Morning/Evening), and reason.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(12.dp))

                    // 1. Date Selector Chips
                    Text("Select Pause Date", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        listOf(
                            Triple("Tomorrow", "2026-09-28", "Monday"),
                            Triple("Tue Sep 29", "2026-09-29", "Tuesday"),
                            Triple("Wed Sep 30", "2026-09-30", "Wednesday")
                        ).forEach { (label, dateVal, dayVal) ->
                            val isSelected = cancelDate == dateVal
                            Surface(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(8.dp))
                                    .clickable {
                                        cancelDate = dateVal
                                        dayOfWeek = dayVal
                                    },
                                color = if (isSelected) DairyGreenPrimary else Color(0xFFF1F5F9)
                            ) {
                                Box(modifier = Modifier.padding(vertical = 8.dp, horizontal = 4.dp), contentAlignment = Alignment.Center) {
                                    Text(
                                        text = label,
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (isSelected) Color.White else Color(0xFF334155)
                                    )
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    // 2. Shift Plan Selector Chips (Morning / Evening / Both)
                    Text("Select Delivery Shift Plan", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        listOf(
                            Triple("🌅 Morning", "MORNING", "05:30 AM - 08:00 AM"),
                            Triple("🌆 Evening", "EVENING", "05:30 PM - 08:00 PM"),
                            Triple("☀️ Both Shifts", "BOTH", "05:30 AM - 08:00 PM")
                        ).forEach { (label, shiftKey, timeRange) ->
                            val isSelected = selectedShift == shiftKey
                            Surface(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(8.dp))
                                    .clickable {
                                        selectedShift = shiftKey
                                        val parts = timeRange.split(" - ")
                                        startTime = parts[0]
                                        endTime = parts[1]
                                    },
                                color = if (isSelected) DairyGreenPrimary else Color(0xFFF1F5F9)
                            ) {
                                Column(
                                    modifier = Modifier.padding(vertical = 8.dp, horizontal = 4.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Text(
                                        text = label,
                                        fontSize = 11.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = if (isSelected) Color.White else Color(0xFF334155)
                                    )
                                    Text(
                                        text = if (shiftKey == "MORNING") "5:30 - 8:00 AM" else if (shiftKey == "EVENING") "5:30 - 8:00 PM" else "Full Day",
                                        fontSize = 9.sp,
                                        color = if (isSelected) Color.White.copy(alpha = 0.9f) else Color(0xFF64748B)
                                    )
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    OutlinedTextField(
                        value = cancelDate,
                        onValueChange = { cancelDate = it },
                        label = { Text("Selected Date (YYYY-MM-DD)") },
                        modifier = Modifier.fillMaxWidth().testTag("cancel_date_input")
                    )

                    Spacer(modifier = Modifier.height(8.dp))

                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(
                            value = startTime,
                            onValueChange = { startTime = it },
                            label = { Text("Start Time") },
                            modifier = Modifier.weight(1f)
                        )
                        OutlinedTextField(
                            value = endTime,
                            onValueChange = { endTime = it },
                            label = { Text("End Time") },
                            modifier = Modifier.weight(1f)
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedTextField(
                        value = reason,
                        onValueChange = { reason = it },
                        label = { Text("Reason for Cancellation") },
                        placeholder = { Text("e.g. Vacation, Sufficient milk in fridge") },
                        modifier = Modifier.fillMaxWidth().testTag("cancel_reason_input")
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val shiftDetail = if (selectedShift == "MORNING") "(Morning Shift)" else if (selectedShift == "EVENING") "(Evening Shift)" else "(Full Day)"
                        onSubmitCancellation(cancelDate, dayOfWeek, startTime, endTime, "$reason $shiftDetail")
                        showCancellationDialog = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = DairyGreenPrimary),
                    modifier = Modifier.testTag("submit_cancel_request_button")
                ) {
                    Text("Submit Request")
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { showCancellationDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
