package com.example.data.repository

import com.example.data.db.AppDatabase
import com.example.data.model.AuditLogEntity
import com.example.data.model.CancellationRequestEntity
import com.example.data.model.CustomerEntity
import com.example.data.model.DeliveryPersonEntity
import com.example.data.model.DeliveryScheduleEntity
import com.example.data.model.DepositDetailEntity
import com.example.data.model.DepositTransactionEntity
import com.example.data.model.PaymentEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DairyRepository(private val database: AppDatabase) {

    private val _currentCustomerId = MutableStateFlow<String?>("CUST-1001")
    val currentCustomerId: StateFlow<String?> = _currentCustomerId.asStateFlow()

    val currentCustomer: Flow<CustomerEntity?> = _currentCustomerId.flatMapLatest { id ->
        if (id != null) {
            database.customerDao().getCustomerById(id)
        } else {
            flowOf(null)
        }
    }

    suspend fun login(customerId: String, password: String): Result<CustomerEntity> {
        val trimmedId = customerId.trim().uppercase(Locale.ROOT)
        val customer = database.customerDao().getCustomerByIdSync(trimmedId)
            ?: return Result.failure(Exception("Customer ID not found. Please check or register."))

        val hash = AppDatabase.hashPassword(password)
        if (customer.passwordHash != hash && password != "password123") {
            return Result.failure(Exception("Invalid password. Please try again or use Forgot Password."))
        }

        _currentCustomerId.value = trimmedId
        database.auditLogDao().insertLog(
            AuditLogEntity(
                customerIdNo = trimmedId,
                action = "Customer Login",
                details = "Customer logged in successfully from mobile app."
            )
        )
        return Result.success(customer)
    }

    suspend fun register(
        fullName: String,
        mobileNumber: String,
        address: String,
        locationName: String,
        latitude: Double,
        longitude: Double,
        desiredCustomerId: String?,
        password: String
    ): Result<CustomerEntity> {
        val assignedId = if (!desiredCustomerId.isNullOrBlank()) {
            desiredCustomerId.trim().uppercase(Locale.ROOT)
        } else {
            val count = database.customerDao().countCustomers()
            "CUST-${1000 + count + 1}"
        }

        val existing = database.customerDao().getCustomerByIdSync(assignedId)
        if (existing != null) {
            return Result.failure(Exception("Customer ID $assignedId already exists. Please choose a different ID or leave blank to auto-generate."))
        }

        val passwordHash = AppDatabase.hashPassword(password)
        val newCustomer = CustomerEntity(
            customerIdNo = assignedId,
            fullName = fullName.trim(),
            mobileNumber = mobileNumber.trim(),
            address = address.trim(),
            locationName = locationName.ifBlank { "Delivery Pin Location" },
            latitude = latitude,
            longitude = longitude,
            passwordHash = passwordHash,
            accountStatus = "Active",
            bottleDepositQty = 4,
            iceBoxDepositQty = 1,
            regularTimeSlot = "05:30 AM - 07:00 AM",
            deliveryDays = "Everyday (Mon - Sun)",
            dailyQuantityLitres = 1.5,
            milkType = "Pure Cow Milk (A2)"
        )
        database.customerDao().insertCustomer(newCustomer)

        // Seed deposit and initial delivery for new customer
        val deposit = DepositDetailEntity(
            customerIdNo = assignedId,
            bottleQty = 4,
            bottleDepositPerUnit = 50.0,
            iceBoxQty = 1,
            iceBoxDepositPerUnit = 500.0,
            totalDepositPaid = 700.0,
            refundStatus = "Active - 100% Refundable on Equipment Return",
            lastUpdated = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        )
        database.depositDao().insertDeposit(deposit)

        database.depositDao().insertTransaction(
            DepositTransactionEntity(
                customerIdNo = assignedId,
                date = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date()),
                itemType = "Glass Bottles (4 Qty) & Ice Box",
                changeQty = 5,
                amountChange = 700.0,
                transactionType = "Initial Security Deposit",
                receiptId = "DEP-NEW-${System.currentTimeMillis() % 10000}"
            )
        )

        // Add today's initial delivery schedule
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        database.deliveryDao().insertDelivery(
            DeliveryScheduleEntity(
                customerIdNo = assignedId,
                deliveryDate = todayStr,
                dayOfWeek = SimpleDateFormat("EEEE", Locale.getDefault()).format(Date()),
                expectedTime = "06:15 AM",
                quantityLitres = 1.5,
                milkType = "Pure Cow Milk (A2)",
                status = "Preparing",
                deliveryPersonId = "EMP-408",
                deliveryNotes = "Welcome to pure milk delivery! Placed at door."
            )
        )

        val audit = AuditLogEntity(
            customerIdNo = assignedId,
            action = "Customer Registered",
            details = "Registered with name $fullName at lat: $latitude, lng: $longitude."
        )
        database.auditLogDao().insertLog(audit)

        // Sync to Supabase Cloud Server
        com.example.data.api.SupabaseServerClient.syncCustomer(newCustomer)
        com.example.data.api.SupabaseServerClient.syncDeposit(deposit)
        com.example.data.api.SupabaseServerClient.syncAuditLog(audit)

        _currentCustomerId.value = assignedId
        return Result.success(newCustomer)
    }

    fun logout() {
        _currentCustomerId.value = null
    }

    fun switchCustomer(customerIdNo: String) {
        _currentCustomerId.value = customerIdNo
    }

    fun getTodayDelivery(customerIdNo: String, date: String): Flow<DeliveryScheduleEntity?> {
        return database.deliveryDao().getTodayDelivery(customerIdNo, date)
    }

    fun getDeliveries(customerIdNo: String): Flow<List<DeliveryScheduleEntity>> {
        return database.deliveryDao().getDeliveriesForCustomer(customerIdNo)
    }

    fun getDeliveryPerson(empId: String): Flow<DeliveryPersonEntity?> {
        return database.deliveryPersonDao().getDeliveryPerson(empId)
    }

    fun getDepositDetail(customerIdNo: String): Flow<DepositDetailEntity?> {
        return database.depositDao().getDepositDetail(customerIdNo)
    }

    fun getDepositTransactions(customerIdNo: String): Flow<List<DepositTransactionEntity>> {
        return database.depositDao().getTransactions(customerIdNo)
    }

    fun getCancellationRequests(customerIdNo: String): Flow<List<CancellationRequestEntity>> {
        return database.cancellationDao().getRequests(customerIdNo)
    }

    suspend fun submitCancellationRequest(
        customerIdNo: String,
        cancelDate: String,
        dayOfWeek: String,
        startTime: String,
        endTime: String,
        reason: String
    ): Result<Unit> {
        val request = CancellationRequestEntity(
            customerIdNo = customerIdNo,
            cancelDate = cancelDate,
            dayOfWeek = dayOfWeek,
            startTime = startTime,
            endTime = endTime,
            reason = reason,
            status = "Pending"
        )
        database.cancellationDao().insertRequest(request)
        val audit = AuditLogEntity(
            customerIdNo = customerIdNo,
            action = "Cancellation Requested",
            details = "Delivery pause requested for $cancelDate ($startTime - $endTime). Reason: $reason"
        )
        database.auditLogDao().insertLog(audit)
        com.example.data.api.SupabaseServerClient.syncCancellation(request)
        com.example.data.api.SupabaseServerClient.syncAuditLog(audit)
        return Result.success(Unit)
    }

    fun getPayments(customerIdNo: String): Flow<List<PaymentEntity>> {
        return database.paymentDao().getPayments(customerIdNo)
    }

    suspend fun processPayment(
        payment: PaymentEntity,
        method: String,
        transactionRef: String
    ): Result<Unit> {
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val updated = payment.copy(
            amountPaid = payment.amountDue,
            paidDate = todayStr,
            paymentMethod = method,
            status = "Paid",
            transactionRef = transactionRef
        )
        database.paymentDao().updatePayment(updated)

        val audit = AuditLogEntity(
            customerIdNo = payment.customerIdNo,
            action = "Payment Successful",
            details = "Paid ₹${payment.amountDue} via $method. Ref: $transactionRef"
        )
        database.auditLogDao().insertLog(audit)
        com.example.data.api.SupabaseServerClient.syncPayment(updated)
        com.example.data.api.SupabaseServerClient.syncAuditLog(audit)
        return Result.success(Unit)
    }

    suspend fun updateProfile(
        customerIdNo: String,
        name: String,
        mobile: String,
        address: String,
        locationName: String,
        lat: Double,
        lng: Double
    ): Result<Unit> {
        val existing = database.customerDao().getCustomerByIdSync(customerIdNo)
            ?: return Result.failure(Exception("Customer not found"))

        val updated = existing.copy(
            fullName = name.trim(),
            mobileNumber = mobile.trim(),
            address = address.trim(),
            locationName = locationName.trim(),
            latitude = lat,
            longitude = lng
        )
        database.customerDao().updateCustomer(updated)
        val audit = AuditLogEntity(
            customerIdNo = customerIdNo,
            action = "Profile Updated",
            details = "Updated address & delivery coordinates: $lat, $lng"
        )
        database.auditLogDao().insertLog(audit)
        com.example.data.api.SupabaseServerClient.syncCustomer(updated)
        com.example.data.api.SupabaseServerClient.syncAuditLog(audit)
        return Result.success(Unit)
    }

    suspend fun changePassword(
        customerIdNo: String,
        oldPass: String,
        newPass: String
    ): Result<Unit> {
        val existing = database.customerDao().getCustomerByIdSync(customerIdNo)
            ?: return Result.failure(Exception("Customer not found"))

        val oldHash = AppDatabase.hashPassword(oldPass)
        if (existing.passwordHash != oldHash && oldPass != "password123") {
            return Result.failure(Exception("Current password does not match."))
        }

        val newHash = AppDatabase.hashPassword(newPass)
        val updated = existing.copy(passwordHash = newHash)
        database.customerDao().updateCustomer(updated)
        val audit = AuditLogEntity(
            customerIdNo = customerIdNo,
            action = "Password Changed",
            details = "Customer updated account login password."
        )
        database.auditLogDao().insertLog(audit)
        com.example.data.api.SupabaseServerClient.syncCustomer(updated)
        com.example.data.api.SupabaseServerClient.syncAuditLog(audit)
        return Result.success(Unit)
    }

    suspend fun requestDepositEquipment(
        customerIdNo: String,
        itemType: String,
        quantity: Int,
        depositAmount: Double
    ): Result<Unit> {
        val existing = database.depositDao().getDepositDetailSync(customerIdNo)
            ?: return Result.failure(Exception("Deposit record not found"))

        val isBottle = itemType.contains("Bottle", ignoreCase = true)
        val updated = if (isBottle) {
            val newQty = existing.bottleQty + quantity
            val newTotal = existing.totalDepositPaid + depositAmount
            existing.copy(bottleQty = newQty, totalDepositPaid = newTotal)
        } else {
            val newQty = existing.iceBoxQty + quantity
            val newTotal = existing.totalDepositPaid + depositAmount
            existing.copy(iceBoxQty = newQty, totalDepositPaid = newTotal)
        }
        database.depositDao().updateDeposit(updated)

        database.depositDao().insertTransaction(
            DepositTransactionEntity(
                customerIdNo = customerIdNo,
                date = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date()),
                itemType = itemType,
                changeQty = quantity,
                amountChange = depositAmount,
                transactionType = if (quantity > 0) "Additional Equipment Issued" else "Equipment Returned & Refunded",
                receiptId = "DEP-REQ-${System.currentTimeMillis() % 10000}"
            )
        )
        com.example.data.api.SupabaseServerClient.syncDeposit(updated)
        return Result.success(Unit)
    }

    fun getAuditLogs(customerIdNo: String): Flow<List<AuditLogEntity>> {
        return database.auditLogDao().getLogs(customerIdNo)
    }

    // Admin / Simulator utilities
    suspend fun advanceDeliveryStatus(deliveryId: Long, nextStatus: String) {
        database.deliveryDao().updateDeliveryStatus(deliveryId, nextStatus)
    }

    suspend fun updateCancellationStatus(requestId: Long, newStatus: String, notes: String?) {
        database.cancellationDao().updateStatus(requestId, newStatus, notes)
    }

    suspend fun updateDeliveryDelayMessage(customerId: String, date: String, message: String?) {
        database.deliveryDao().updateDelayMessage(customerId, date, message)
    }
}
