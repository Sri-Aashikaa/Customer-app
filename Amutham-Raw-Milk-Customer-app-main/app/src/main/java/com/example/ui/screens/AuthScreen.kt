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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Key
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
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
import com.example.ui.components.LeafletMapView
import com.example.ui.theme.DairyBlueLight
import com.example.ui.theme.DairyBluePrimary

@Composable
fun AuthScreen(
    onLogin: (customerId: String, pass: String) -> Unit,
    onRegister: (
        name: String,
        mobile: String,
        address: String,
        locationName: String,
        lat: Double,
        lng: Double,
        desiredId: String?,
        pass: String
    ) -> Unit,
    errorMessage: String? = null,
    onClearError: () -> Unit = {}
) {
    var selectedTab by remember { mutableIntStateOf(0) } // 0: Login, 1: Register

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // App Header Banner
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(DairyBluePrimary)
                .padding(top = 40.dp, bottom = 24.dp, start = 20.dp, end = 20.dp)
        ) {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(42.dp)
                            .clip(CircleShape)
                            .background(Color.White.copy(alpha = 0.2f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.WaterDrop,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(24.dp)
                        )
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = "MilkFlow Dairy",
                            color = Color.White,
                            fontSize = 22.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "Fresh Morning Milk Customer Management",
                            color = Color.White.copy(alpha = 0.85f),
                            fontSize = 12.sp
                        )
                    }
                }
            }
        }

        TabRow(
            selectedTabIndex = selectedTab,
            containerColor = MaterialTheme.colorScheme.surface,
            contentColor = DairyBluePrimary
        ) {
            Tab(
                selected = selectedTab == 0,
                onClick = { selectedTab = 0; onClearError() },
                text = { Text("Customer Login", fontWeight = FontWeight.SemiBold) }
            )
            Tab(
                selected = selectedTab == 1,
                onClick = { selectedTab = 1; onClearError() },
                text = { Text("New Registration", fontWeight = FontWeight.SemiBold) }
            )
        }

        if (errorMessage != null) {
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                colors = CardDefaults.cardColors(containerColor = Color(0xFFFEE2E2)),
                shape = RoundedCornerShape(10.dp)
            ) {
                Text(
                    text = errorMessage,
                    color = Color(0xFF991B1B),
                    fontSize = 13.sp,
                    modifier = Modifier.padding(12.dp)
                )
            }
        }

        if (selectedTab == 0) {
            LoginTabContent(
                onLogin = onLogin
            )
        } else {
            RegisterTabContent(
                onRegister = onRegister
            )
        }
    }
}

@Composable
private fun LoginTabContent(
    onLogin: (customerId: String, pass: String) -> Unit
) {
    var customerId by remember { mutableStateOf("CUST-1001") }
    var password by remember { mutableStateOf("password123") }
    var rememberMe by remember { mutableStateOf(true) }
    var isPasswordVisible by remember { mutableStateOf(false) }
    var showForgotPasswordDialog by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
    ) {
        Text(
            text = "Welcome Back!",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text(
            text = "Enter your Customer ID No. to manage morning deliveries & payments.",
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(20.dp))

        OutlinedTextField(
            value = customerId,
            onValueChange = { customerId = it },
            label = { Text("Customer ID No.") },
            placeholder = { Text("e.g. CUST-1001") },
            leadingIcon = {
                Icon(imageVector = Icons.Default.Badge, contentDescription = null, tint = DairyBluePrimary)
            },
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .testTag("login_customer_id_input")
        )

        Spacer(modifier = Modifier.height(14.dp))

        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Password") },
            leadingIcon = {
                Icon(imageVector = Icons.Default.Lock, contentDescription = null, tint = DairyBluePrimary)
            },
            trailingIcon = {
                IconButton(onClick = { isPasswordVisible = !isPasswordVisible }) {
                    Icon(
                        imageVector = if (isPasswordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                        contentDescription = "Toggle password visibility"
                    )
                }
            },
            visualTransformation = if (isPasswordVisible) VisualTransformation.None else PasswordVisualTransformation(),
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .testTag("login_password_input")
        )

        Spacer(modifier = Modifier.height(10.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.clickable { rememberMe = !rememberMe }
            ) {
                Checkbox(
                    checked = rememberMe,
                    onCheckedChange = { rememberMe = it },
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(6.dp))
                Text(
                    text = "Remember Me",
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }

            TextButton(
                onClick = { showForgotPasswordDialog = true },
                modifier = Modifier.testTag("forgot_password_button")
            ) {
                Text(
                    text = "Forgot Password?",
                    fontSize = 12.sp,
                    color = DairyBluePrimary,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        Button(
            onClick = { onLogin(customerId, password) },
            enabled = customerId.isNotBlank() && password.isNotBlank(),
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp)
                .testTag("login_submit_button"),
            colors = ButtonDefaults.buttonColors(containerColor = DairyBluePrimary),
            shape = RoundedCornerShape(12.dp)
        ) {
            Text("Login to Dashboard", fontSize = 15.sp, fontWeight = FontWeight.Bold)
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Demo quick login pills for effortless testing
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f)),
            border = CardDefaults.outlinedCardBorder()
        ) {
            Column(modifier = Modifier.padding(14.dp)) {
                Text(
                    text = "Quick Demo Accounts (1-Tap Fill):",
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = {
                            customerId = "CUST-1001"
                            password = "password123"
                        },
                        modifier = Modifier.weight(1f).testTag("quick_fill_cust_1")
                    ) {
                        Text("David (CUST-1001)", fontSize = 11.sp)
                    }
                    OutlinedButton(
                        onClick = {
                            customerId = "CUST-1002"
                            password = "password123"
                        },
                        modifier = Modifier.weight(1f).testTag("quick_fill_cust_2")
                    ) {
                        Text("Sarah (CUST-1002)", fontSize = 11.sp)
                    }
                }
            }
        }
    }

    if (showForgotPasswordDialog) {
        var resetCustomerId by remember { mutableStateOf(customerId) }
        var resetDone by remember { mutableStateOf(false) }

        AlertDialog(
            onDismissRequest = { showForgotPasswordDialog = false },
            title = { Text(if (resetDone) "Reset Instructions Sent" else "Reset Account Password") },
            text = {
                if (resetDone) {
                    Text("A temporary password reset link and SMS code have been dispatched to the mobile number linked with $resetCustomerId. Use 'password123' to login.")
                } else {
                    Column {
                        Text(
                            text = "Enter your Customer ID No. or Registered Mobile to receive password reset verification.",
                            fontSize = 13.sp
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        OutlinedTextField(
                            value = resetCustomerId,
                            onValueChange = { resetCustomerId = it },
                            label = { Text("Customer ID / Mobile") },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        if (resetDone) {
                            showForgotPasswordDialog = false
                        } else {
                            resetDone = true
                        }
                    }
                ) {
                    Text(if (resetDone) "Back to Login" else "Send Reset Code")
                }
            },
            dismissButton = {
                if (!resetDone) {
                    OutlinedButton(onClick = { showForgotPasswordDialog = false }) {
                        Text("Cancel")
                    }
                }
            }
        )
    }
}

@Composable
private fun RegisterTabContent(
    onRegister: (
        name: String,
        mobile: String,
        address: String,
        locationName: String,
        lat: Double,
        lng: Double,
        desiredId: String?,
        pass: String
    ) -> Unit
) {
    var fullName by remember { mutableStateOf("") }
    var mobileNumber by remember { mutableStateOf("") }
    var address by remember { mutableStateOf("") }
    var locationName by remember { mutableStateOf("Greenfield North Sector") }
    var latitude by remember { mutableDoubleStateOf(37.7749) }
    var longitude by remember { mutableDoubleStateOf(-122.4194) }
    var desiredId by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var confirmPassword by remember { mutableStateOf("") }
    var isPasswordVisible by remember { mutableStateOf(false) }
    var validationError by remember { mutableStateOf<String?>(null) }
    var showMapDialog by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
    ) {
        Text(
            text = "Create Customer Account",
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text(
            text = "Set up your morning milk delivery spot with precise map pin & address.",
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(16.dp))

        if (validationError != null) {
            Text(
                text = validationError ?: "",
                color = Color(0xFFDC2626),
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.padding(bottom = 8.dp)
            )
        }

        // Full Name
        OutlinedTextField(
            value = fullName,
            onValueChange = { fullName = it; validationError = null },
            label = { Text("Full Name *") },
            placeholder = { Text("e.g. John Doe") },
            leadingIcon = { Icon(Icons.Default.Person, contentDescription = null, tint = DairyBluePrimary) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("reg_name_input")
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Mobile Number
        OutlinedTextField(
            value = mobileNumber,
            onValueChange = { mobileNumber = it; validationError = null },
            label = { Text("Mobile Number *") },
            placeholder = { Text("+1 (555) 000-0000") },
            leadingIcon = { Icon(Icons.Default.Phone, contentDescription = null, tint = DairyBluePrimary) },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("reg_mobile_input")
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Complete Address
        OutlinedTextField(
            value = address,
            onValueChange = { address = it; validationError = null },
            label = { Text("Complete Address *") },
            placeholder = { Text("House/Flat No., Street, Landmark, Greenfield") },
            leadingIcon = { Icon(Icons.Default.Home, contentDescription = null, tint = DairyBluePrimary) },
            maxLines = 3,
            modifier = Modifier.fillMaxWidth().testTag("reg_address_input")
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Delivery Location & Map Coordinates Card
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            border = CardDefaults.outlinedCardBorder()
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.LocationOn,
                            contentDescription = null,
                            tint = DairyBluePrimary,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = "Delivery Location on Map",
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp
                        )
                    }

                    OutlinedButton(
                        onClick = { showMapDialog = true },
                        modifier = Modifier.testTag("open_map_picker_button")
                    ) {
                        Icon(Icons.Default.Map, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Pick On Map", fontSize = 11.sp)
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Interactive Leaflet Map Preview
                LeafletMapView(
                    latitude = latitude,
                    longitude = longitude,
                    isPickerMode = true,
                    onLocationChanged = { lat, lng ->
                        latitude = lat
                        longitude = lng
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(160.dp)
                )

                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("Latitude: ${"%.4f".format(latitude)}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Longitude: ${"%.4f".format(longitude)}", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // Customer ID No. (Auto-generated or custom)
        OutlinedTextField(
            value = desiredId,
            onValueChange = { desiredId = it },
            label = { Text("Customer ID No. (Optional / Auto-generated)") },
            placeholder = { Text("Leave blank for auto CUST-XXXX") },
            leadingIcon = { Icon(Icons.Default.Badge, contentDescription = null, tint = DairyBluePrimary) },
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("reg_customer_id_input")
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Password
        OutlinedTextField(
            value = password,
            onValueChange = { password = it; validationError = null },
            label = { Text("Password *") },
            leadingIcon = { Icon(Icons.Default.Lock, contentDescription = null, tint = DairyBluePrimary) },
            trailingIcon = {
                IconButton(onClick = { isPasswordVisible = !isPasswordVisible }) {
                    Icon(
                        imageVector = if (isPasswordVisible) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                        contentDescription = "Toggle password"
                    )
                }
            },
            visualTransformation = if (isPasswordVisible) VisualTransformation.None else PasswordVisualTransformation(),
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("reg_password_input")
        )

        Spacer(modifier = Modifier.height(12.dp))

        // Confirm Password
        OutlinedTextField(
            value = confirmPassword,
            onValueChange = { confirmPassword = it; validationError = null },
            label = { Text("Confirm Password *") },
            leadingIcon = { Icon(Icons.Default.Key, contentDescription = null, tint = DairyBluePrimary) },
            visualTransformation = PasswordVisualTransformation(),
            singleLine = true,
            modifier = Modifier.fillMaxWidth().testTag("reg_confirm_password_input")
        )

        Spacer(modifier = Modifier.height(20.dp))

        Button(
            onClick = {
                if (fullName.isBlank()) {
                    validationError = "Please enter your full name."
                    return@Button
                }
                if (mobileNumber.isBlank() || mobileNumber.length < 7) {
                    validationError = "Please enter a valid mobile number."
                    return@Button
                }
                if (address.isBlank()) {
                    validationError = "Please enter your complete address."
                    return@Button
                }
                if (password.length < 6) {
                    validationError = "Password must be at least 6 characters."
                    return@Button
                }
                if (password != confirmPassword) {
                    validationError = "Passwords do not match."
                    return@Button
                }

                onRegister(
                    fullName,
                    mobileNumber,
                    address,
                    locationName,
                    latitude,
                    longitude,
                    desiredId.ifBlank { null },
                    password
                )
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(50.dp)
                .testTag("reg_submit_button"),
            colors = ButtonDefaults.buttonColors(containerColor = DairyBluePrimary),
            shape = RoundedCornerShape(12.dp)
        ) {
            Text("Register Customer & Delivery Spot", fontSize = 15.sp, fontWeight = FontWeight.Bold)
        }
    }

    // Modal dialog with larger map for precise pin setting
    if (showMapDialog) {
        AlertDialog(
            onDismissRequest = { showMapDialog = false },
            title = {
                Text("Pin Delivery Location", fontWeight = FontWeight.Bold)
            },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = "Drag or click on the map to pinpoint your exact gate or porch where milk should be delivered.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    LeafletMapView(
                        latitude = latitude,
                        longitude = longitude,
                        isPickerMode = true,
                        onLocationChanged = { lat, lng ->
                            latitude = lat
                            longitude = lng
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(280.dp)
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = { showMapDialog = false }
                ) {
                    Text("Confirm Pin")
                }
            }
        )
    }
}
