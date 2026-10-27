package com.example.data.model

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "customers")
data class CustomerEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val customerIdNo: String, // e.g. "CUST-1001"
    val fullName: String,
    val mobileNumber: String,
    val address: String,
    val locationName: String,
    val latitude: Double,
    val longitude: Double,
    val passwordHash: String,
    val accountStatus: String = "Active", // "Active", "Verified", "Paused"
    val bottleDepositQty: Int = 4,
    val iceBoxDepositQty: Int = 1,
    val regularTimeSlot: String = "05:30 AM - 07:00 AM",
    val deliveryDays: String = "Everyday (Mon - Sun)",
    val dailyQuantityLitres: Double = 1.5,
    val milkType: String = "Pure Cow Milk (A2)",
    val createdAt: Long = System.currentTimeMillis()
)

@Entity(tableName = "deliveries")
data class DeliveryScheduleEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val customerIdNo: String,
    val deliveryDate: String, // YYYY-MM-DD
    val dayOfWeek: String,
    val expectedTime: String,
    val actualDeliveredTime: String? = null,
    val quantityLitres: Double,
    val milkType: String,
    val status: String, // "Scheduled", "Preparing", "Assigned to Delivery Person", "Out for Delivery", "Near Customer", "Delivered", "Delivery Failed", "Cancelled"
    val deliveryPersonId: String,
    val deliveryNotes: String? = null,
    val delayMessage: String? = null,
    val timestamp: Long = System.currentTimeMillis()
)

@Entity(tableName = "delivery_persons")
data class DeliveryPersonEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val employeeId: String, // e.g. "EMP-408"
    val name: String,
    val mobile: String,
    val assignedRoute: String,
    val status: String = "On Route", // "Active", "On Route", "Off Duty"
    val rating: Double = 4.9,
    val currentLatitude: Double,
    val currentLongitude: Double
)

@Entity(tableName = "deposits")
data class DepositDetailEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val customerIdNo: String,
    val bottleQty: Int = 4,
    val bottleDepositPerUnit: Double = 50.0,
    val iceBoxQty: Int = 1,
    val iceBoxDepositPerUnit: Double = 500.0,
    val totalDepositPaid: Double = 700.0,
    val refundStatus: String = "Active & Secured",
    val lastUpdated: String = "2026-09-20"
)

@Entity(tableName = "deposit_transactions")
data class DepositTransactionEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val customerIdNo: String,
    val date: String,
    val itemType: String, // "Glass Bottle (1L)", "Chilled Ice Box"
    val changeQty: Int,
    val amountChange: Double,
    val transactionType: String, // "Initial Deposit", "Additional Bottle", "Bottle Return Refund"
    val receiptId: String
)

@Entity(tableName = "cancellation_requests")
data class CancellationRequestEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val customerIdNo: String,
    val cancelDate: String, // YYYY-MM-DD
    val dayOfWeek: String,
    val startTime: String, // "05:30 AM"
    val endTime: String, // "08:00 AM"
    val reason: String,
    val status: String = "Pending", // "Pending", "Approved", "Rejected", "Expired"
    val requestedTimestamp: Long = System.currentTimeMillis(),
    val reviewNotes: String? = null
)

@Entity(tableName = "payments")
data class PaymentEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val customerIdNo: String,
    val invoiceNumber: String,
    val billingPeriod: String,
    val dueDate: String,
    val paidDate: String? = null,
    val amountDue: Double,
    val amountPaid: Double,
    val paymentMethod: String = "UPI / Card",
    val status: String = "Pending", // "Paid", "Partially Paid", "Pending", "Overdue"
    val transactionRef: String = ""
)

@Entity(tableName = "audit_logs")
data class AuditLogEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val customerIdNo: String,
    val action: String,
    val details: String,
    val timestamp: Long = System.currentTimeMillis()
)
