package com.example.ui.screens

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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Logout
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Security
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.platform.LocalContext
import com.example.data.model.AuditLogEntity
import com.example.data.model.CustomerEntity
import com.example.ui.components.LeafletMapView
import com.example.ui.theme.DairyBlueContainer
import com.example.ui.theme.DairyBluePrimary

@Composable
fun ProfileScreen(
    customer: CustomerEntity,
    auditLogs: List<AuditLogEntity>,
    onUpdateProfile: (name: String, mobile: String, address: String, locName: String, lat: Double, lng: Double) -> Unit,
    onChangePassword: (oldPass: String, newPass: String) -> Unit,
    onLogout: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var isEditing by remember { mutableStateOf(false) }
    var editName by remember(customer) { mutableStateOf(customer.fullName) }
    var editMobile by remember(customer) { mutableStateOf(customer.mobileNumber) }
    var editAddress by remember(customer) { mutableStateOf(customer.address) }
    var editLocName by remember(customer) { mutableStateOf(customer.locationName) }
    var editLat by remember(customer) { mutableDoubleStateOf(customer.latitude) }
    var editLng by remember(customer) { mutableDoubleStateOf(customer.longitude) }

    var showPasswordModal by remember { mutableStateOf(false) }
    var showResetPasswordModal by remember { mutableStateOf(false) }
    var showSupportQueryModal by remember { mutableStateOf(false) }
    var showMapModal by remember { mutableStateOf(false) }
    var showAdminIdLockNotice by remember { mutableStateOf(false) }
    var updateSuccessMessage by remember { mutableStateOf<String?>(null) }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Customer Header Card
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
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(50.dp)
                                    .clip(CircleShape)
                                    .background(DairyBlueContainer),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.Person, contentDescription = null, tint = DairyBluePrimary, modifier = Modifier.size(28.dp))
                            }
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(customer.fullName, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Lock, contentDescription = null, tint = Color(0xFF64748B), modifier = Modifier.size(12.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text(
                                        text = "ID: ${customer.customerIdNo} (System Locked)",
                                        fontSize = 11.sp,
                                        color = Color(0xFF64748B),
                                        modifier = Modifier.clickable { showAdminIdLockNotice = true }
                                    )
                                }
                            }
                        }

                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(6.dp))
                                .background(Color(0xFFDCFCE7))
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Text(customer.accountStatus, fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color(0xFF16A34A))
                        }
                    }

                    if (updateSuccessMessage != null) {
                        Spacer(modifier = Modifier.height(10.dp))
                        Text(
                            text = updateSuccessMessage!!,
                            color = Color(0xFF16A34A),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            }
        }

        // Customer Profile Details Card
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
                        Text("Profile & Delivery Details", fontSize = 15.sp, fontWeight = FontWeight.Bold)

                        if (!isEditing) {
                            IconButton(
                                onClick = { isEditing = true },
                                modifier = Modifier.testTag("edit_profile_button")
                            ) {
                                Icon(Icons.Default.Edit, contentDescription = "Edit Profile", tint = DairyBluePrimary)
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    if (isEditing) {
                        OutlinedTextField(
                            value = editName,
                            onValueChange = { editName = it },
                            label = { Text("Full Name") },
                            leadingIcon = { Icon(Icons.Default.Person, contentDescription = null) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = editMobile,
                            onValueChange = { editMobile = it },
                            label = { Text("Mobile Number") },
                            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                            leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null) },
                            modifier = Modifier.fillMaxWidth()
                        )
                        Spacer(modifier = Modifier.height(10.dp))

                        OutlinedTextField(
                            value = editAddress,
                            onValueChange = { editAddress = it },
                            label = { Text("Complete Address") },
                            leadingIcon = { Icon(Icons.Default.Home, contentDescription = null) },
                            maxLines = 3,
                            modifier = Modifier.fillMaxWidth()
                        )
                        Spacer(modifier = Modifier.height(10.dp))

                        // Delivery Location with map adjustment
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text("Delivery Pin Location", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                                Text("Lat: ${"%.4f".format(editLat)}, Lng: ${"%.4f".format(editLng)}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            OutlinedButton(onClick = { showMapModal = true }) {
                                Icon(Icons.Default.Map, contentDescription = null, modifier = Modifier.size(16.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("Adjust Pin", fontSize = 11.sp)
                            }
                        }

                        Spacer(modifier = Modifier.height(14.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            OutlinedButton(
                                onClick = {
                                    isEditing = false
                                    editName = customer.fullName
                                    editMobile = customer.mobileNumber
                                    editAddress = customer.address
                                    editLat = customer.latitude
                                    editLng = customer.longitude
                                },
                                modifier = Modifier.weight(1f)
                            ) {
                                Text("Cancel")
                            }

                            Button(
                                onClick = {
                                    onUpdateProfile(editName, editMobile, editAddress, editLocName, editLat, editLng)
                                    isEditing = false
                                    updateSuccessMessage = "Profile and delivery coordinates updated!"
                                },
                                colors = ButtonDefaults.buttonColors(containerColor = DairyBluePrimary),
                                modifier = Modifier.weight(1f).testTag("save_profile_button")
                            ) {
                                Text("Save Changes")
                            }
                        }
                    } else {
                        // View mode
                        DetailRow(label = "Full Name", value = customer.fullName)
                        DetailRow(label = "Mobile Number", value = customer.mobileNumber)
                        DetailRow(label = "Complete Address", value = customer.address)
                        DetailRow(label = "Customer ID No.", value = "${customer.customerIdNo} (Locked)")
                        DetailRow(label = "Coordinates", value = "Lat ${"%.4f".format(customer.latitude)}, Lng ${"%.4f".format(customer.longitude)}")
                        DetailRow(label = "Delivery Slot", value = customer.regularTimeSlot)
                        DetailRow(label = "Active Days", value = customer.deliveryDays)
                    }
                }
            }
        }

        // Map View of current delivery location & Share via Map
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = CardDefaults.outlinedCardBorder()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Stored Delivery Location Pin", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                    Text("Exact doorstep location registered for morning drops", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(10.dp))

                    LeafletMapView(
                        latitude = customer.latitude,
                        longitude = customer.longitude,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(160.dp)
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Button(
                            onClick = {
                                val mapUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=${customer.latitude},${customer.longitude}")
                                val intent = Intent(Intent.ACTION_VIEW, mapUri)
                                context.startActivity(intent)
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = DairyBluePrimary),
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.Map, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Open Google Maps", fontSize = 11.sp)
                        }

                        OutlinedButton(
                            onClick = {
                                val shareText = "Amutham Milk Delivery Address:\n${customer.fullName} (${customer.customerIdNo})\n${customer.address}, ${customer.locationName}\nGoogle Maps: https://maps.google.com/?q=${customer.latitude},${customer.longitude}"
                                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, shareText)
                                }
                                context.startActivity(Intent.createChooser(shareIntent, "Share Location via Map"))
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.LocationOn, contentDescription = null, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Share Location", fontSize = 11.sp)
                        }
                    }
                }
            }
        }

        // Security & Password Change / Reset
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
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Security, contentDescription = null, tint = DairyBluePrimary, modifier = Modifier.size(22.dp))
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text("Account Security", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Text("Password reset & security settings", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }

                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            OutlinedButton(
                                onClick = { showPasswordModal = true },
                                modifier = Modifier.testTag("change_password_button")
                            ) {
                                Text("Change Password", fontSize = 11.sp)
                            }

                            Button(
                                onClick = { showResetPasswordModal = true },
                                colors = ButtonDefaults.buttonColors(containerColor = DairyBluePrimary)
                            ) {
                                Text("Reset Password", fontSize = 11.sp)
                            }
                        }
                    }
                }
            }
        }

        // Contact Support Team Card
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = CardDefaults.outlinedCardBorder()
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Phone, contentDescription = null, tint = DairyBluePrimary, modifier = Modifier.size(22.dp))
                        Spacer(modifier = Modifier.width(10.dp))
                        Column {
                            Text("Contact Support Team", fontWeight = FontWeight.Bold, fontSize = 15.sp)
                            Text("Customer Care Help Desk (6:00 AM - 9:00 PM)", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        OutlinedButton(
                            onClick = {
                                val callIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:+917331152332"))
                                context.startActivity(callIntent)
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.Phone, contentDescription = null, modifier = Modifier.size(14.dp))
                            Spacer(modifier = Modifier.width(4.dp))
                            Text("Call Helpline", fontSize = 11.sp)
                        }

                        Button(
                            onClick = {
                                val waIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/917331152332?text=Hello%20Support,%20I%20need%20help%20with%20my%20account%20(${customer.customerIdNo})"))
                                context.startActivity(waIntent)
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF25D366)),
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("WhatsApp", fontSize = 11.sp, color = Color.White)
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedButton(
                        onClick = { showSupportQueryModal = true },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Submit Support Request / Callback", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }

        // Section: Audit Logs
        item {
            Text("Activity & Change Audit Logs", fontSize = 15.sp, fontWeight = FontWeight.Bold)
        }

        items(auditLogs) { log ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(10.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = CardDefaults.outlinedCardBorder()
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(log.action, fontWeight = FontWeight.SemiBold, fontSize = 12.sp, color = DairyBluePrimary)
                        Text(
                            java.text.SimpleDateFormat("MMM dd, HH:mm", java.util.Locale.getDefault()).format(java.util.Date(log.timestamp)),
                            fontSize = 10.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(log.details, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurface)
                }
            }
        }

        // Logout Button
        item {
            Button(
                onClick = onLogout,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFDC2626)),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .testTag("logout_button")
            ) {
                Icon(Icons.Default.Logout, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(modifier = Modifier.width(8.dp))
                Text("Logout from Account", fontWeight = FontWeight.Bold)
            }
        }
    }

    // Modal: Change Password
    if (showPasswordModal) {
        var oldPassword by remember { mutableStateOf("") }
        var newPassword by remember { mutableStateOf("") }
        var confirmNewPassword by remember { mutableStateOf("") }
        var passError by remember { mutableStateOf<String?>(null) }

        AlertDialog(
            onDismissRequest = { showPasswordModal = false },
            title = { Text("Change Password", fontWeight = FontWeight.Bold) },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    if (passError != null) {
                        Text(passError!!, color = Color(0xFFDC2626), fontSize = 12.sp)
                        Spacer(modifier = Modifier.height(6.dp))
                    }

                    OutlinedTextField(
                        value = oldPassword,
                        onValueChange = { oldPassword = it; passError = null },
                        label = { Text("Current Password") },
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedTextField(
                        value = newPassword,
                        onValueChange = { newPassword = it; passError = null },
                        label = { Text("New Password (min 6 chars)") },
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedTextField(
                        value = confirmNewPassword,
                        onValueChange = { confirmNewPassword = it; passError = null },
                        label = { Text("Confirm New Password") },
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (newPassword.length < 6) {
                            passError = "Password must be at least 6 characters."
                            return@Button
                        }
                        if (newPassword != confirmNewPassword) {
                            passError = "New passwords do not match."
                            return@Button
                        }
                        onChangePassword(oldPassword, newPassword)
                        showPasswordModal = false
                        updateSuccessMessage = "Password changed successfully."
                    }
                ) {
                    Text("Update Password")
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { showPasswordModal = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Modal: Adjust Delivery Pin
    if (showMapModal) {
        AlertDialog(
            onDismissRequest = { showMapModal = false },
            title = { Text("Adjust Delivery Pin", fontWeight = FontWeight.Bold) },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text("Click or drag marker to your updated morning drop-off spot:", fontSize = 12.sp)
                    Spacer(modifier = Modifier.height(8.dp))
                    LeafletMapView(
                        latitude = editLat,
                        longitude = editLng,
                        isPickerMode = true,
                        onLocationChanged = { lat, lng ->
                            editLat = lat
                            editLng = lng
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(260.dp)
                    )
                }
            },
            confirmButton = {
                Button(onClick = { showMapModal = false }) {
                    Text("Set Coordinates")
                }
            }
        )
    }

    // Modal: Reset Password
    if (showResetPasswordModal) {
        var targetId by remember { mutableStateOf(customer.mobileNumber) }
        var resetPass by remember { mutableStateOf("") }
        var confirmResetPass by remember { mutableStateOf("") }
        var resetError by remember { mutableStateOf<String?>(null) }

        AlertDialog(
            onDismissRequest = { showResetPasswordModal = false },
            title = { Text("Reset Password", fontWeight = FontWeight.Bold) },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text("Verify mobile number / Customer ID and set new password:", fontSize = 12.sp)
                    Spacer(modifier = Modifier.height(8.dp))

                    if (resetError != null) {
                        Text(resetError!!, color = Color(0xFFDC2626), fontSize = 12.sp)
                        Spacer(modifier = Modifier.height(6.dp))
                    }

                    OutlinedTextField(
                        value = targetId,
                        onValueChange = { targetId = it; resetError = null },
                        label = { Text("Mobile / Customer ID") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedTextField(
                        value = resetPass,
                        onValueChange = { resetPass = it; resetError = null },
                        label = { Text("New Password") },
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedTextField(
                        value = confirmResetPass,
                        onValueChange = { confirmResetPass = it; resetError = null },
                        label = { Text("Confirm New Password") },
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (resetPass.length < 6) {
                            resetError = "Password must be at least 6 characters."
                            return@Button
                        }
                        if (resetPass != confirmResetPass) {
                            resetError = "Passwords do not match."
                            return@Button
                        }
                        showResetPasswordModal = false
                        updateSuccessMessage = "Password reset initiated successfully."
                    }
                ) {
                    Text("Reset Password")
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { showResetPasswordModal = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Modal: Support Query / Callback Request
    if (showSupportQueryModal) {
        var queryText by remember { mutableStateOf("") }

        AlertDialog(
            onDismissRequest = { showSupportQueryModal = false },
            title = { Text("Submit Support Ticket", fontWeight = FontWeight.Bold) },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text("Describe your request below. Our helpline team will call you back on ${customer.mobileNumber}:", fontSize = 12.sp)
                    Spacer(modifier = Modifier.height(8.dp))

                    OutlinedTextField(
                        value = queryText,
                        onValueChange = { queryText = it },
                        label = { Text("Issue or Query Details") },
                        modifier = Modifier.fillMaxWidth().height(120.dp),
                        maxLines = 5
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        showSupportQueryModal = false
                        updateSuccessMessage = "Support request submitted! Callback scheduled."
                    }
                ) {
                    Text("Submit Request")
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { showSupportQueryModal = false }) {
                    Text("Cancel")
                }
            }
        )
    }

    // Modal: Admin Authorization Notice for Customer ID
    if (showAdminIdLockNotice) {
        AlertDialog(
            onDismissRequest = { showAdminIdLockNotice = false },
            title = { Text("Customer ID Security Policy", fontWeight = FontWeight.Bold) },
            text = {
                Text(
                    "Customer ID (${customer.customerIdNo}) is permanently bound to route allocation, billing records, and security deposits. In accordance with safety policies, it cannot be modified without dairy supervisor / admin authorization."
                )
            },
            confirmButton = {
                Button(onClick = { showAdminIdLockNotice = false }) {
                    Text("Understood")
                }
            }
        )
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface)
    }
}
