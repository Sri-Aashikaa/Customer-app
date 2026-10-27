package com.example.ui.screens

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AssignmentReturn
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Receipt
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.TakeoutDining
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.model.DepositDetailEntity
import com.example.data.model.DepositTransactionEntity
import com.example.ui.theme.DairyBlueContainer
import com.example.ui.theme.DairyBluePrimary
import com.example.ui.theme.DairyGreenContainer
import com.example.ui.theme.DairyGreenSecondary

@Composable
fun DepositScreen(
    depositDetail: DepositDetailEntity?,
    transactions: List<DepositTransactionEntity>,
    onRequestEquipmentChange: (itemType: String, qty: Int, amount: Double) -> Unit,
    modifier: Modifier = Modifier
) {
    var showEquipDialog by remember { mutableStateOf(false) }
    var isAddingEquipment by remember { mutableStateOf(true) }

    val bottles = depositDetail?.bottleQty ?: 4
    val bottleUnitRate = depositDetail?.bottleDepositPerUnit ?: 50.0
    val bottleTotal = bottles * bottleUnitRate

    val iceBoxes = depositDetail?.iceBoxQty ?: 1
    val boxUnitRate = depositDetail?.iceBoxDepositPerUnit ?: 500.0
    val boxTotal = iceBoxes * boxUnitRate

    val grandTotal = depositDetail?.totalDepositPaid ?: (bottleTotal + boxTotal)

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Grand Total Security Deposit Card
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = CardDefaults.outlinedCardBorder()
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
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
                                    .background(DairyGreenContainer),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.Shield, contentDescription = null, tint = DairyGreenSecondary, modifier = Modifier.size(22.dp))
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text("Total Deposit Paid", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(
                                    text = "₹${"%.2f".format(grandTotal)}",
                                    fontSize = 26.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = DairyGreenSecondary
                                )
                            }
                        }

                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color(0xFFDCFCE7))
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                        ) {
                            Text(
                                text = depositDetail?.refundStatus ?: "Active & Secured",
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                color = Color(0xFF16A34A)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))
                    Spacer(modifier = Modifier.height(12.dp))

                    Text(
                        text = "100% refundable when equipment (glass bottles and insulated chiller boxes) are handed back to the dairy.",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }

        // Section: Breakdown of Deposit Amounts
        item {
            Text("Deposit Breakdown", fontSize = 15.sp, fontWeight = FontWeight.Bold)
        }

        // Card 1: Milk Glass Bottles
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = CardDefaults.outlinedCardBorder()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(DairyBlueContainer),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.TakeoutDining, contentDescription = null, tint = DairyBluePrimary, modifier = Modifier.size(20.dp))
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text("Milk Glass Bottles (1 Litre)", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Text("Hygiene sealed European glassware", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }

                        Text(
                            text = "₹${"%.2f".format(bottleTotal)}",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                            color = DairyBluePrimary
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color(0xFFF8FAFC), RoundedCornerShape(8.dp))
                            .padding(10.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text("Bottle Quantity", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("$bottles Units in circulation", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text("Deposit Rate", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("₹${"%.2f".format(bottleUnitRate)} / unit", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        }

        // Card 2: Insulated Ice Box
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(14.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                border = CardDefaults.outlinedCardBorder()
            ) {
                Column(modifier = Modifier.padding(14.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .size(36.dp)
                                    .clip(CircleShape)
                                    .background(DairyBlueContainer),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Default.Inventory2, contentDescription = null, tint = DairyBluePrimary, modifier = Modifier.size(20.dp))
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text("Insulated Chilled Ice Box", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Text("Porch thermal storage unit", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }

                        Text(
                            text = "₹${"%.2f".format(boxTotal)}",
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp,
                            color = DairyBluePrimary
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color(0xFFF8FAFC), RoundedCornerShape(8.dp))
                            .padding(10.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column {
                            Text("Ice Box Quantity", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("$iceBoxes Unit with customer", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            Text("Deposit Rate", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("₹${"%.2f".format(boxUnitRate)} / unit", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
            }
        }

        // Quick Actions: Request Extra / Return Equipment
        item {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = {
                        isAddingEquipment = true
                        showEquipDialog = true
                    },
                    modifier = Modifier.weight(1f).testTag("request_extra_bottle_button")
                ) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Add Bottle / Box", fontSize = 11.sp)
                }

                OutlinedButton(
                    onClick = {
                        isAddingEquipment = false
                        showEquipDialog = true
                    },
                    modifier = Modifier.weight(1f).testTag("return_bottle_button")
                ) {
                    Icon(Icons.Default.AssignmentReturn, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("Return & Refund", fontSize = 11.sp)
                }
            }
        }

        // Deposit History / Transactions
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Deposit History & Receipts", fontSize = 15.sp, fontWeight = FontWeight.Bold)
                Text("${transactions.size} records", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        items(transactions) { txn ->
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
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
                        Text(txn.transactionType, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Text("${txn.itemType} • ${txn.date}", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Text("Receipt: ${txn.receiptId}", fontSize = 10.sp, color = DairyBluePrimary)
                    }

                    Text(
                        text = if (txn.amountChange >= 0) "+₹${"%.2f".format(txn.amountChange)}" else "-₹${"%.2f".format(-txn.amountChange)}",
                        fontWeight = FontWeight.Bold,
                        fontSize = 14.sp,
                        color = if (txn.amountChange >= 0) DairyGreenSecondary else Color(0xFFDC2626)
                    )
                }
            }
        }
    }

    if (showEquipDialog) {
        var selectedItem by remember { mutableStateOf("Glass Bottle (1L)") }
        val unitPrice = if (selectedItem.contains("Bottle")) 50.0 else 500.0

        AlertDialog(
            onDismissRequest = { showEquipDialog = false },
            title = {
                Text(if (isAddingEquipment) "Request Additional Equipment" else "Return Equipment & Claim Deposit", fontWeight = FontWeight.Bold)
            },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = if (isAddingEquipment) {
                            "Select equipment to add to your daily cycle. Additional refundable deposit will be reflected in your statement."
                        } else {
                            "Select item to return to delivery driver. Deposit balance will be adjusted/refunded immediately."
                        },
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(modifier = Modifier.height(12.dp))

                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(
                            onClick = { selectedItem = "Glass Bottle (1L)" },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (selectedItem.contains("Bottle")) DairyBluePrimary else MaterialTheme.colorScheme.surfaceVariant,
                                contentColor = if (selectedItem.contains("Bottle")) Color.White else MaterialTheme.colorScheme.onSurface
                            ),
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Bottle (₹50)", fontSize = 11.sp)
                        }

                        Button(
                            onClick = { selectedItem = "Chilled Ice Box" },
                            colors = ButtonDefaults.buttonColors(
                                containerColor = if (selectedItem.contains("Ice Box")) DairyBluePrimary else MaterialTheme.colorScheme.surfaceVariant,
                                contentColor = if (selectedItem.contains("Ice Box")) Color.White else MaterialTheme.colorScheme.onSurface
                            ),
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Ice Box (₹500)", fontSize = 11.sp)
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = "Refundable Deposit Adjustment: ${if (isAddingEquipment) "+₹" else "-₹"}${unitPrice.toInt()}",
                        fontWeight = FontWeight.Bold,
                        fontSize = 13.sp,
                        color = DairyGreenSecondary
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val qty = if (isAddingEquipment) 1 else -1
                        val amt = if (isAddingEquipment) unitPrice else -unitPrice
                        onRequestEquipmentChange(selectedItem, qty, amt)
                        showEquipDialog = false
                    }
                ) {
                    Text("Confirm")
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { showEquipDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
