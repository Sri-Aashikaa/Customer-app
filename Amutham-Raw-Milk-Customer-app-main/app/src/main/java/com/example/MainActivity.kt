package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Assessment
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Payment
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.ui.screens.AuthScreen
import com.example.ui.screens.DashboardScreen
import com.example.ui.screens.DeliveryScreen
import com.example.ui.screens.DepositScreen
import com.example.ui.screens.PaymentScreen
import com.example.ui.screens.ProfileScreen
import com.example.ui.screens.ReportsScreen
import com.example.ui.theme.DairyBlueContainer
import com.example.ui.theme.DairyBlueLight
import com.example.ui.theme.DairyBluePrimary
import com.example.ui.theme.MyApplicationTheme
import com.example.ui.viewmodel.DairyViewModel
import com.example.ui.viewmodel.NavigationTab

class MainActivity : ComponentActivity() {
    private val viewModel: DairyViewModel by viewModels()

    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MyApplicationTheme {
                val currentCustomer by viewModel.currentCustomer.collectAsStateWithLifecycle()
                val currentTab by viewModel.currentTab.collectAsStateWithLifecycle()
                val authError by viewModel.authError.collectAsStateWithLifecycle()

                val todayDelivery by viewModel.todayDelivery.collectAsStateWithLifecycle()
                val nextDelivery = viewModel.deliveries.collectAsStateWithLifecycle().value.firstOrNull {
                    it.deliveryDate > (todayDelivery?.deliveryDate ?: "")
                }
                val deliveries by viewModel.deliveries.collectAsStateWithLifecycle()
                val assignedPerson by viewModel.assignedPerson.collectAsStateWithLifecycle()
                val depositDetail by viewModel.depositDetail.collectAsStateWithLifecycle()
                val depositTransactions by viewModel.depositTransactions.collectAsStateWithLifecycle()
                val cancellationRequests by viewModel.cancellationRequests.collectAsStateWithLifecycle()
                val payments by viewModel.payments.collectAsStateWithLifecycle()
                val pendingPayment = payments.firstOrNull { it.status != "Paid" }
                val auditLogs by viewModel.auditLogs.collectAsStateWithLifecycle()

                if (currentCustomer == null) {
                    AuthScreen(
                        onLogin = { id, pass -> viewModel.login(id, pass) },
                        onRegister = { name, mob, addr, loc, lat, lng, desId, pass ->
                            viewModel.register(name, mob, addr, loc, lat, lng, desId, pass)
                        },
                        errorMessage = authError,
                        onClearError = { viewModel.clearAuthError() }
                    )
                } else {
                    // Back handler: pop to Dashboard if in sub-screen
                    if (currentTab != NavigationTab.DASHBOARD) {
                        BackHandler {
                            viewModel.selectTab(NavigationTab.DASHBOARD)
                        }
                    }

                    Scaffold(
                        modifier = Modifier.fillMaxSize(),
                        topBar = {
                            TopAppBar(
                                title = {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Box(
                                            modifier = Modifier
                                                .size(32.dp)
                                                .clip(CircleShape)
                                                .background(DairyBluePrimary),
                                            contentAlignment = Alignment.Center
                                        ) {
                                            Icon(
                                                imageVector = Icons.Default.WaterDrop,
                                                contentDescription = null,
                                                tint = Color.White,
                                                modifier = Modifier.size(18.dp)
                                            )
                                        }
                                        Spacer(modifier = Modifier.width(10.dp))
                                        Column {
                                            Text(
                                                text = "MilkFlow",
                                                fontWeight = FontWeight.Bold,
                                                fontSize = 16.sp
                                            )
                                            Text(
                                                text = "${currentCustomer?.fullName} (${currentCustomer?.customerIdNo})",
                                                fontSize = 11.sp,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant
                                            )
                                        }
                                    }
                                },
                                colors = TopAppBarDefaults.topAppBarColors(
                                    containerColor = MaterialTheme.colorScheme.surface,
                                    titleContentColor = MaterialTheme.colorScheme.onSurface
                                )
                            )
                        },
                        bottomBar = {
                            DairyBottomBar(
                                currentTab = currentTab,
                                onSelectTab = { viewModel.selectTab(it) }
                            )
                        }
                    ) { innerPadding ->
                        Box(modifier = Modifier.padding(innerPadding)) {
                            when (currentTab) {
                                NavigationTab.DASHBOARD -> DashboardScreen(
                                    customer = currentCustomer!!,
                                    todayDelivery = todayDelivery,
                                    nextDelivery = nextDelivery,
                                    assignedPerson = assignedPerson,
                                    depositDetail = depositDetail,
                                    pendingPayment = pendingPayment,
                                    onNavigateToDelivery = { viewModel.selectTab(NavigationTab.DELIVERY) },
                                    onNavigateToPayment = { viewModel.selectTab(NavigationTab.PAYMENT) },
                                    onNavigateToDeposit = { viewModel.selectTab(NavigationTab.DEPOSIT) },
                                    onProcessPayment = { pay, method, ref -> viewModel.processPayment(pay, method, ref) },
                                    onAdvanceDeliveryStatus = { id, status -> viewModel.advanceDeliveryStatus(id, status) }
                                )

                                NavigationTab.DELIVERY -> DeliveryScreen(
                                    customer = currentCustomer!!,
                                    todayDelivery = todayDelivery,
                                    assignedPerson = assignedPerson,
                                    cancellationRequests = cancellationRequests,
                                    onSubmitCancellation = { date, day, start, end, reason ->
                                        viewModel.submitCancellation(date, day, start, end, reason)
                                    }
                                )

                                NavigationTab.PAYMENT -> PaymentScreen(
                                    payments = payments,
                                    onProcessPayment = { pay, method, ref -> viewModel.processPayment(pay, method, ref) }
                                )

                                NavigationTab.DEPOSIT -> DepositScreen(
                                    depositDetail = depositDetail,
                                    transactions = depositTransactions,
                                    onRequestEquipmentChange = { type, qty, amt ->
                                        viewModel.requestEquipmentChange(type, qty, amt)
                                    }
                                )

                                NavigationTab.REPORTS -> ReportsScreen(
                                    deliveries = deliveries,
                                    payments = payments,
                                    cancellations = cancellationRequests,
                                    deposits = depositTransactions
                                )

                                NavigationTab.PROFILE -> ProfileScreen(
                                    customer = currentCustomer!!,
                                    auditLogs = auditLogs,
                                    onUpdateProfile = { name, mob, addr, loc, lat, lng ->
                                        viewModel.updateProfile(name, mob, addr, loc, lat, lng)
                                    },
                                    onChangePassword = { oldPass, newPass ->
                                        viewModel.changePassword(oldPass, newPass)
                                    },
                                    onLogout = { viewModel.logout() }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

data class NavItem(
    val tab: NavigationTab,
    val label: String,
    val icon: ImageVector,
    val testTag: String
)

@Composable
fun DairyBottomBar(
    currentTab: NavigationTab,
    onSelectTab: (NavigationTab) -> Unit
) {
    // Navigation order: Dashboard | Delivery | Payment | Deposit | Profile | Reports
    val items = listOf(
        NavItem(NavigationTab.DASHBOARD, "Dashboard", Icons.Default.Dashboard, "tab_dashboard"),
        NavItem(NavigationTab.DELIVERY, "Delivery", Icons.Default.LocalShipping, "tab_delivery"),
        NavItem(NavigationTab.PAYMENT, "Payment", Icons.Default.Payment, "tab_payment"),
        NavItem(NavigationTab.DEPOSIT, "Deposit", Icons.Default.Inventory2, "tab_deposit"),
        NavItem(NavigationTab.PROFILE, "Profile", Icons.Default.Person, "tab_profile"),
        NavItem(NavigationTab.REPORTS, "Reports", Icons.Default.Assessment, "tab_reports")
    )

    NavigationBar(
        modifier = Modifier.testTag("bottom_navigation_bar"),
        containerColor = MaterialTheme.colorScheme.surface,
        contentColor = DairyBluePrimary,
        tonalElevation = 6.dp
    ) {
        items.forEach { item ->
            val isSelected = currentTab == item.tab
            NavigationBarItem(
                selected = isSelected,
                onClick = { onSelectTab(item.tab) },
                icon = {
                    Icon(
                        imageVector = item.icon,
                        contentDescription = item.label,
                        modifier = Modifier.size(20.dp)
                    )
                },
                label = {
                    Text(
                        text = item.label,
                        fontSize = 9.sp,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                        maxLines = 1
                    )
                },
                alwaysShowLabel = true,
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = DairyBluePrimary,
                    selectedTextColor = DairyBluePrimary,
                    indicatorColor = DairyBlueContainer,
                    unselectedIconColor = Color(0xFF64748B),
                    unselectedTextColor = Color(0xFF64748B)
                ),
                modifier = Modifier.testTag(item.testTag)
            )
        }
    }
}
