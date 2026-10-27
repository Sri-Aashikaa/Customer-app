package com.example.ui.screens

import android.content.Intent
import androidx.compose.foundation.background
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
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Payment
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.Share
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
import com.example.data.model.PaymentEntity
import com.example.ui.components.PayNowDialog
import com.example.ui.components.StatusBadge
import com.example.ui.theme.DairyBlueContainer
import com.example.ui.theme.DairyBluePrimary
import com.example.ui.theme.DairyGreenSecondary

@Composable
fun PaymentScreen(
    payments: List<PaymentEntity>,
    onProcessPayment: (payment: PaymentEntity, method: String, ref: String) -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var selectedPaymentForPay by remember { mutableStateOf<PaymentEntity?>(null) }
    var selectedInvoiceForReceipt by remember { mutableStateOf<PaymentEntity?>(null) }

    val pendingPayment = payments.firstOrNull { it.status != "Paid" }
    val currentDue = pendingPayment?.amountDue ?: 0.0
    val totalPaid = payments.filter { it.status == "Paid" }.sumOf { it.amountPaid }
    val lastPaidPayment = payments.firstOrNull { it.status == "Paid" && it.paidDate != null }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // Outstanding / Due Billing Overview Card
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
                            Text("Current Billing Status", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                text = "₹${"%.2f".format(currentDue)}",
                                fontSize = 28.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (currentDue > 0) Color(0xFFDC2626) else Color(0xFF16A34A)
                            )
                        }

                        StatusBadge(status = pendingPayment?.status ?: "Paid")
                    }

                    Spacer(modifier = Modifier.height(14.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .background(Color(0xFFF8FAFC), RoundedCornerShape(10.dp))
                                .padding(10.dp)
                        ) {
                            Text("Payment Due Date", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(pendingPayment?.dueDate ?: "N/A", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .background(Color(0xFFF8FAFC), RoundedCornerShape(10.dp))
                                .padding(10.dp)
                        ) {
                            Text("Last Payment Date", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(lastPaidPayment?.paidDate ?: "N/A", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .background(Color(0xFFF8FAFC), RoundedCornerShape(10.dp))
                                .padding(10.dp)
                        ) {
                            Text("Total Paid (Lifetime)", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("₹${"%.2f".format(totalPaid)}", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = DairyGreenSecondary)
                        }
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .background(Color(0xFFF8FAFC), RoundedCornerShape(10.dp))
                                .padding(10.dp)
                        ) {
                            Text("Pending Balance", fontSize = 10.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("₹${"%.2f".format(currentDue)}", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color(0xFFDC2626))
                        }
                    }

                    if (pendingPayment != null && currentDue > 0) {
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(
                            onClick = { selectedPaymentForPay = pendingPayment },
                            colors = ButtonDefaults.buttonColors(containerColor = DairyBluePrimary),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(48.dp)
                                .testTag("payment_screen_pay_now_button")
                        ) {
                            Icon(Icons.Default.Payment, contentDescription = null, modifier = Modifier.size(18.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Pay Now • ₹${"%.2f".format(currentDue)}", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }
        }

        // Section: Payment History
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Billing & Payment History", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                Text("${payments.size} Invoices", fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        items(payments) { payment ->
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { selectedInvoiceForReceipt = payment },
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
                                    .background(if (payment.status == "Paid") Color(0xFFDCFCE7) else Color(0xFFFEF3C7)),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(
                                    imageVector = if (payment.status == "Paid") Icons.Default.CheckCircle else Icons.Default.ReceiptLong,
                                    contentDescription = null,
                                    tint = if (payment.status == "Paid") Color(0xFF16A34A) else Color(0xFFD97706),
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                            Spacer(modifier = Modifier.width(10.dp))
                            Column {
                                Text(payment.invoiceNumber, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                Text(payment.billingPeriod, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }

                        StatusBadge(status = payment.status)
                    }

                    Spacer(modifier = Modifier.height(10.dp))
                    HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))
                    Spacer(modifier = Modifier.height(10.dp))

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                text = if (payment.status == "Paid") "Paid via ${payment.paymentMethod}" else "Due by ${payment.dueDate}",
                                fontSize = 11.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            if (payment.transactionRef.isNotBlank()) {
                                Text("Ref: ${payment.transactionRef}", fontSize = 10.sp, color = DairyBluePrimary)
                            }
                        }

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                text = "₹${"%.2f".format(payment.amountDue)}",
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            IconButton(
                                onClick = { selectedInvoiceForReceipt = payment },
                                modifier = Modifier.size(28.dp)
                            ) {
                                Icon(Icons.Default.Share, contentDescription = "Share receipt", tint = DairyBluePrimary, modifier = Modifier.size(16.dp))
                            }
                        }
                    }
                }
            }
        }
    }

    // Pay Dialog
    if (selectedPaymentForPay != null) {
        PayNowDialog(
            payment = selectedPaymentForPay!!,
            onDismiss = { selectedPaymentForPay = null },
            onConfirmPayment = { method, ref ->
                onProcessPayment(selectedPaymentForPay!!, method, ref)
                selectedPaymentForPay = null
            }
        )
    }

    // Receipt View / Share Dialog
    if (selectedInvoiceForReceipt != null) {
        val invoice = selectedInvoiceForReceipt!!
        AlertDialog(
            onDismissRequest = { selectedInvoiceForReceipt = null },
            title = {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.ReceiptLong, contentDescription = null, tint = DairyBluePrimary)
                    Spacer(modifier = Modifier.width(8.dp))
                    Text("Milk Invoice ${invoice.invoiceNumber}", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                }
            },
            text = {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text("Billing Period: ${invoice.billingPeriod}", fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.height(8.dp))
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        color = Color(0xFFF8FAFC),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Column(modifier = Modifier.padding(12.dp)) {
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text("Total Amount:", fontSize = 12.sp)
                                Text("₹${"%.2f".format(invoice.amountDue)}", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            }
                            Spacer(modifier = Modifier.height(4.dp))
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                Text("Status:", fontSize = 12.sp)
                                Text(invoice.status, fontWeight = FontWeight.Bold, color = if (invoice.status == "Paid") Color(0xFF16A34A) else Color(0xFFDC2626), fontSize = 12.sp)
                            }
                            if (invoice.paidDate != null) {
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("Paid Date:", fontSize = 12.sp)
                                    Text(invoice.paidDate, fontSize = 12.sp)
                                }
                            }
                            if (invoice.transactionRef.isNotBlank()) {
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("Reference:", fontSize = 12.sp)
                                    Text(invoice.transactionRef, fontSize = 11.sp, color = DairyBluePrimary)
                                }
                            }
                        }
                    }
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        val shareText = """
                            --- AMUTHAM MILK INVOICE RECEIPT ---
                            Invoice No: ${invoice.invoiceNumber}
                            Billing Period: ${invoice.billingPeriod}
                            Customer: ${invoice.customerIdNo}
                            Amount: ₹${"%.2f".format(invoice.amountDue)}
                            Status: ${invoice.status}
                            Paid Date: ${invoice.paidDate ?: "Pending"}
                            Ref: ${invoice.transactionRef.ifBlank { "N/A" }}
                            --------------------------------
                            Amutham Raw Milk Customer Care: +91 98401 23456
                        """.trimIndent()

                        val sendIntent = Intent().apply {
                            action = Intent.ACTION_SEND
                            putExtra(Intent.EXTRA_TEXT, shareText)
                            type = "text/plain"
                        }
                        val shareIntent = Intent.createChooser(sendIntent, "Share Milk Invoice Receipt")
                        context.startActivity(shareIntent)
                    }
                ) {
                    Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(6.dp))
                    Text("Share / Export")
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { selectedInvoiceForReceipt = null }) {
                    Text("Close")
                }
            }
        )
    }
}
