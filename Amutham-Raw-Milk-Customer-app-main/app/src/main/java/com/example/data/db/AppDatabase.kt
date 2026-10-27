package com.example.data.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import com.example.data.dao.AuditLogDao
import com.example.data.dao.CancellationDao
import com.example.data.dao.CustomerDao
import com.example.data.dao.DeliveryPersonDao
import com.example.data.dao.DeliveryScheduleDao
import com.example.data.dao.DepositDao
import com.example.data.dao.PaymentDao
import com.example.data.model.AuditLogEntity
import com.example.data.model.CancellationRequestEntity
import com.example.data.model.CustomerEntity
import com.example.data.model.DeliveryPersonEntity
import com.example.data.model.DeliveryScheduleEntity
import com.example.data.model.DepositDetailEntity
import com.example.data.model.DepositTransactionEntity
import com.example.data.model.PaymentEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.security.MessageDigest

@Database(
    entities = [
        CustomerEntity::class,
        DeliveryScheduleEntity::class,
        DeliveryPersonEntity::class,
        DepositDetailEntity::class,
        DepositTransactionEntity::class,
        CancellationRequestEntity::class,
        PaymentEntity::class,
        AuditLogEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun customerDao(): CustomerDao
    abstract fun deliveryDao(): DeliveryScheduleDao
    abstract fun deliveryPersonDao(): DeliveryPersonDao
    abstract fun depositDao(): DepositDao
    abstract fun cancellationDao(): CancellationDao
    abstract fun paymentDao(): PaymentDao
    abstract fun auditLogDao(): AuditLogDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getDatabase(context: Context, scope: CoroutineScope): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "milk_delivery_db"
                )
                    .addCallback(DatabaseCallback(scope))
                    .build()
                INSTANCE = instance
                instance
            }
        }

        fun hashPassword(password: String): String {
            val bytes = MessageDigest.getInstance("SHA-256").digest(password.toByteArray())
            return bytes.joinToString("") { "%02x".format(it) }
        }

        private class DatabaseCallback(
            private val scope: CoroutineScope
        ) : RoomDatabase.Callback() {
            override fun onCreate(db: SupportSQLiteDatabase) {
                super.onCreate(db)
                INSTANCE?.let { database ->
                    scope.launch(Dispatchers.IO) {
                        populateInitialData(database)
                    }
                }
            }
        }

        suspend fun populateInitialData(db: AppDatabase) {
            val passHash = hashPassword("password123")

            // Seed Customers
            val cust1 = CustomerEntity(
                id = 1,
                customerIdNo = "CUST-1001",
                fullName = "David Miller",
                mobileNumber = "+1 (555) 234-8901",
                address = "452 Meadowbrook Lane, Apt 3B, Greenfield",
                locationName = "Greenfield North Meadowbrook",
                latitude = 37.7749,
                longitude = -122.4194,
                passwordHash = passHash,
                accountStatus = "Active",
                bottleDepositQty = 4,
                iceBoxDepositQty = 1,
                regularTimeSlot = "05:30 AM - 07:00 AM",
                deliveryDays = "Everyday (Mon - Sun)",
                dailyQuantityLitres = 1.5,
                milkType = "Pure Cow Milk (A2 Glass Bottle)"
            )
            val cust2 = CustomerEntity(
                id = 2,
                customerIdNo = "CUST-1002",
                fullName = "Sarah Jenkins",
                mobileNumber = "+1 (555) 987-6543",
                address = "128 Highland Crest Road, Greenfield",
                locationName = "Highland Crest, Greenfield",
                latitude = 37.7833,
                longitude = -122.4167,
                passwordHash = passHash,
                accountStatus = "Active",
                bottleDepositQty = 2,
                iceBoxDepositQty = 1,
                regularTimeSlot = "06:00 AM - 07:30 AM",
                deliveryDays = "Mon, Wed, Fri, Sun",
                dailyQuantityLitres = 1.0,
                milkType = "Standard Fresh Farm Milk"
            )
            db.customerDao().insertCustomer(cust1)
            db.customerDao().insertCustomer(cust2)

            // Seed Delivery Person
            val deliveryPerson = DeliveryPersonEntity(
                id = 1,
                employeeId = "EMP-408",
                name = "Rajesh Kumar",
                mobile = "+1 (555) 345-6789",
                assignedRoute = "Route #4 - Greenfield North Sector",
                status = "On Route",
                rating = 4.92,
                currentLatitude = 37.7770,
                currentLongitude = -122.4185
            )
            db.deliveryPersonDao().insert(deliveryPerson)

            // Seed Deposits
            val deposit = DepositDetailEntity(
                id = 1,
                customerIdNo = "CUST-1001",
                bottleQty = 4,
                bottleDepositPerUnit = 50.0,
                iceBoxQty = 1,
                iceBoxDepositPerUnit = 500.0,
                totalDepositPaid = 700.0,
                refundStatus = "Active - 100% Refundable on Equipment Return",
                lastUpdated = "2026-09-20"
            )
            db.depositDao().insertDeposit(deposit)

            db.depositDao().insertTransactions(
                listOf(
                    DepositTransactionEntity(
                        id = 1,
                        customerIdNo = "CUST-1001",
                        date = "2026-09-01",
                        itemType = "Glass Bottle (1L)",
                        changeQty = 4,
                        amountChange = 200.0,
                        transactionType = "Initial Bottle Security Deposit",
                        receiptId = "DEP-BOT-101"
                    ),
                    DepositTransactionEntity(
                        id = 2,
                        customerIdNo = "CUST-1001",
                        date = "2026-09-01",
                        itemType = "Insulated Chilled Ice Box",
                        changeQty = 1,
                        amountChange = 500.0,
                        transactionType = "Equipment Deposit",
                        receiptId = "DEP-BOX-204"
                    )
                )
            )

            // Seed Deliveries
            val deliveries = listOf(
                DeliveryScheduleEntity(
                    id = 1,
                    customerIdNo = "CUST-1001",
                    deliveryDate = "2026-09-26",
                    dayOfWeek = "Saturday",
                    expectedTime = "06:15 AM",
                    quantityLitres = 1.5,
                    milkType = "Pure Cow Milk (A2)",
                    status = "Out for Delivery",
                    deliveryPersonId = "EMP-408",
                    deliveryNotes = "Place inside insulated porch ice box. Ring bell once.",
                    delayMessage = "Delivery agent is 1 stop away (~8 mins away)"
                ),
                DeliveryScheduleEntity(
                    id = 2,
                    customerIdNo = "CUST-1001",
                    deliveryDate = "2026-09-27",
                    dayOfWeek = "Sunday",
                    expectedTime = "06:15 AM",
                    quantityLitres = 1.5,
                    milkType = "Pure Cow Milk (A2)",
                    status = "Scheduled",
                    deliveryPersonId = "EMP-408"
                ),
                DeliveryScheduleEntity(
                    id = 3,
                    customerIdNo = "CUST-1001",
                    deliveryDate = "2026-09-25",
                    dayOfWeek = "Friday",
                    expectedTime = "06:15 AM",
                    actualDeliveredTime = "06:10 AM",
                    quantityLitres = 1.5,
                    milkType = "Pure Cow Milk (A2)",
                    status = "Delivered",
                    deliveryPersonId = "EMP-408",
                    deliveryNotes = "Delivered cleanly. 2 empty bottles collected."
                ),
                DeliveryScheduleEntity(
                    id = 4,
                    customerIdNo = "CUST-1001",
                    deliveryDate = "2026-09-24",
                    dayOfWeek = "Thursday",
                    expectedTime = "06:15 AM",
                    actualDeliveredTime = "06:05 AM",
                    quantityLitres = 1.5,
                    milkType = "Pure Cow Milk (A2)",
                    status = "Delivered",
                    deliveryPersonId = "EMP-408"
                ),
                DeliveryScheduleEntity(
                    id = 5,
                    customerIdNo = "CUST-1001",
                    deliveryDate = "2026-09-23",
                    dayOfWeek = "Wednesday",
                    expectedTime = "06:15 AM",
                    quantityLitres = 1.5,
                    milkType = "Pure Cow Milk (A2)",
                    status = "Cancelled",
                    deliveryPersonId = "EMP-408",
                    deliveryNotes = "Customer travel request approved"
                ),
                DeliveryScheduleEntity(
                    id = 6,
                    customerIdNo = "CUST-1001",
                    deliveryDate = "2026-09-22",
                    dayOfWeek = "Tuesday",
                    expectedTime = "06:15 AM",
                    actualDeliveredTime = "06:18 AM",
                    quantityLitres = 1.5,
                    milkType = "Pure Cow Milk (A2)",
                    status = "Delivered",
                    deliveryPersonId = "EMP-408"
                ),
                DeliveryScheduleEntity(
                    id = 7,
                    customerIdNo = "CUST-1001",
                    deliveryDate = "2026-09-21",
                    dayOfWeek = "Monday",
                    expectedTime = "06:15 AM",
                    actualDeliveredTime = "06:12 AM",
                    quantityLitres = 1.5,
                    milkType = "Pure Cow Milk (A2)",
                    status = "Delivered",
                    deliveryPersonId = "EMP-408"
                )
            )
            db.deliveryDao().insertAll(deliveries)

            // Seed Cancellation Requests
            db.cancellationDao().insertRequest(
                CancellationRequestEntity(
                    id = 1,
                    customerIdNo = "CUST-1001",
                    cancelDate = "2026-09-23",
                    dayOfWeek = "Wednesday",
                    startTime = "05:30 AM",
                    endTime = "08:00 AM",
                    reason = "Out of town for family visit",
                    status = "Approved",
                    reviewNotes = "Approved automatically before 10 PM cutoff"
                )
            )
            db.cancellationDao().insertRequest(
                CancellationRequestEntity(
                    id = 2,
                    customerIdNo = "CUST-1001",
                    cancelDate = "2026-09-29",
                    dayOfWeek = "Tuesday",
                    startTime = "05:30 AM",
                    endTime = "08:00 AM",
                    reason = "Sufficient milk remaining in refrigerator",
                    status = "Pending",
                    reviewNotes = "Awaiting route manager confirmation"
                )
            )
            db.cancellationDao().insertRequest(
                CancellationRequestEntity(
                    id = 3,
                    customerIdNo = "CUST-1001",
                    cancelDate = "2026-09-15",
                    dayOfWeek = "Tuesday",
                    startTime = "05:30 AM",
                    endTime = "08:00 AM",
                    reason = "Late travel notification",
                    status = "Expired",
                    reviewNotes = "Cutoff expired before delivery window"
                )
            )

            // Seed Payments
            db.paymentDao().insertAll(
                listOf(
                    PaymentEntity(
                        id = 1,
                        customerIdNo = "CUST-1001",
                        invoiceNumber = "INV-2026-09",
                        billingPeriod = "September 1 - 30, 2026",
                        dueDate = "2026-10-05",
                        amountDue = 45.00,
                        amountPaid = 0.00,
                        paymentMethod = "Pending Online Payment",
                        status = "Pending",
                        transactionRef = ""
                    ),
                    PaymentEntity(
                        id = 2,
                        customerIdNo = "CUST-1001",
                        invoiceNumber = "INV-2026-08",
                        billingPeriod = "August 1 - 31, 2026",
                        dueDate = "2026-09-05",
                        paidDate = "2026-09-02",
                        amountDue = 46.50,
                        amountPaid = 46.50,
                        paymentMethod = "UPI (GPay / PhonePe)",
                        status = "Paid",
                        transactionRef = "UPI-892348123"
                    ),
                    PaymentEntity(
                        id = 3,
                        customerIdNo = "CUST-1001",
                        invoiceNumber = "INV-2026-07",
                        billingPeriod = "July 1 - 31, 2026",
                        dueDate = "2026-08-05",
                        paidDate = "2026-08-01",
                        amountDue = 45.00,
                        amountPaid = 45.00,
                        paymentMethod = "Debit / Credit Card",
                        status = "Paid",
                        transactionRef = "CARD-74619284"
                    )
                )
            )

            // Seed Audit Logs
            db.auditLogDao().insertLog(
                AuditLogEntity(
                    customerIdNo = "CUST-1001",
                    action = "Account Registered",
                    details = "Customer registered with ID CUST-1001 and delivery location pinned."
                )
            )
            db.auditLogDao().insertLog(
                AuditLogEntity(
                    customerIdNo = "CUST-1001",
                    action = "Deposit Recorded",
                    details = "Deposits recorded: 4 Bottles (₹200) + 1 Ice Box (₹500). Total: ₹700."
                )
            )
        }
    }
}
