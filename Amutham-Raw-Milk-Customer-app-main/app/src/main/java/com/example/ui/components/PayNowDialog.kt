package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Money
import androidx.compose.material.icons.filled.QrCode
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.RadioButton
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.model.PaymentEntity
import com.example.ui.theme.DairyBluePrimary
import com.example.ui.theme.DairyGreenSecondary

data class PayOption(
    val id: String,
    val title: String,
    val subtitle: String,
    val icon: ImageVector
)

@Composable
fun PayNowDialog(
    payment: PaymentEntity,
    onDismiss: () -> Unit,
    onConfirmPayment: (method: String, refNumber: String) -> Unit
) {
    var selectedMethod by remember { mutableStateOf("UPI") }
    var isProcessing by remember { mutableStateOf(false) }
    var isSuccess by remember { mutableStateOf(false) }
    var generatedRef by remember { mutableStateOf("") }

    val options = listOf(
        PayOption("UPI", "Instant UPI / QR", "Google Pay, PhonePe, Paytm, BHIM", Icons.Default.QrCode),
        PayOption("Card", "Credit / Debit Card", "Visa, Mastercard, RuPay", Icons.Default.CreditCard),
        PayOption("NetBanking", "Net Banking", "All major national & private banks", Icons.Default.AccountBalance),
        PayOption("Cash", "Cash on Delivery", "Pay directly to morning delivery person", Icons.Default.Money)
    )

    AlertDialog(
        onDismissRequest = { if (!isProcessing) onDismiss() },
        title = {
            if (isSuccess) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = null,
                        tint = DairyGreenSecondary,
                        modifier = Modifier.size(28.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Payment Successful!",
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp
                    )
                }
            } else {
                Column {
                    Text(
                        text = "Pay Milk Bill",
                        fontWeight = FontWeight.Bold,
                        fontSize = 18.sp
                    )
                    Text(
                        text = "Invoice ${payment.invoiceNumber}",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        },
        text = {
            if (isSuccess) {
                Column(modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
                    Text(
                        text = "Amount: ₹${"%.2f".format(payment.amountDue)} paid successfully.",
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "Method: $selectedMethod",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "Transaction Ref: $generatedRef",
                        fontSize = 12.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = DairyBluePrimary
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    Text(
                        text = "Your account balance has been updated immediately. Digital invoice receipt is stored in your payment history.",
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                Column(modifier = Modifier.fillMaxWidth()) {
                    // Bill amount card
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        color = MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text("Total Amount Due", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(payment.billingPeriod, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                            }
                            Text(
                                text = "₹${"%.2f".format(payment.amountDue)}",
                                fontSize = 22.sp,
                                fontWeight = FontWeight.Bold,
                                color = DairyBluePrimary
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(14.dp))
                    Text(
                        text = "Select Payment Mode",
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(8.dp))

                    options.forEach { opt ->
                        val isSelected = selectedMethod == opt.id
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 4.dp)
                                .clip(RoundedCornerShape(10.dp))
                                .border(
                                    width = if (isSelected) 2.dp else 1.dp,
                                    color = if (isSelected) DairyBluePrimary else MaterialTheme.colorScheme.outline.copy(alpha = 0.3f),
                                    shape = RoundedCornerShape(10.dp)
                                )
                                .background(if (isSelected) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.2f) else MaterialTheme.colorScheme.surface)
                                .clickable { selectedMethod = opt.id }
                                .padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            RadioButton(
                                selected = isSelected,
                                onClick = { selectedMethod = opt.id },
                                modifier = Modifier.size(24.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Icon(
                                imageVector = opt.icon,
                                contentDescription = null,
                                tint = if (isSelected) DairyBluePrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(22.dp)
                            )
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text(
                                    text = opt.title,
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.SemiBold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Text(
                                    text = opt.subtitle,
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }

                    if (isProcessing) {
                        Spacer(modifier = Modifier.height(14.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Authorizing secure payment...", fontSize = 12.sp)
                        }
                    }
                }
            }
        },
        confirmButton = {
            if (isSuccess) {
                Button(
                    onClick = onDismiss,
                    modifier = Modifier.testTag("payment_done_button")
                ) {
                    Text("Done")
                }
            } else {
                Button(
                    onClick = {
                        isProcessing = true
                        val ref = "PAY-${(100000..999999).random()}"
                        generatedRef = ref
                        // Complete after brief simulated gateway response
                        onConfirmPayment(selectedMethod, ref)
                        isProcessing = false
                        isSuccess = true
                    },
                    enabled = !isProcessing,
                    colors = ButtonDefaults.buttonColors(containerColor = DairyBluePrimary),
                    modifier = Modifier.testTag("confirm_pay_button")
                ) {
                    Text("Pay ₹${"%.2f".format(payment.amountDue)}")
                }
            }
        },
        dismissButton = {
            if (!isSuccess) {
                OutlinedButton(
                    onClick = onDismiss,
                    enabled = !isProcessing
                ) {
                    Text("Cancel")
                }
            }
        }
    )
}
