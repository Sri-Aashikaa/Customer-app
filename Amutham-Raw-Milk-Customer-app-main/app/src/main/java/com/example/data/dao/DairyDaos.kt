package com.example.data.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.data.model.AuditLogEntity
import com.example.data.model.CancellationRequestEntity
import com.example.data.model.CustomerEntity
import com.example.data.model.DeliveryPersonEntity
import com.example.data.model.DeliveryScheduleEntity
import com.example.data.model.DepositDetailEntity
import com.example.data.model.DepositTransactionEntity
import com.example.data.model.PaymentEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface CustomerDao {
    @Query("SELECT * FROM customers WHERE customerIdNo = :customerIdNo LIMIT 1")
    fun getCustomerById(customerIdNo: String): Flow<CustomerEntity?>

    @Query("SELECT * FROM customers WHERE customerIdNo = :customerIdNo LIMIT 1")
    suspend fun getCustomerByIdSync(customerIdNo: String): CustomerEntity?

    @Query("SELECT * FROM customers WHERE mobileNumber = :mobile LIMIT 1")
    suspend fun getCustomerByMobile(mobile: String): CustomerEntity?

    @Query("SELECT * FROM customers ORDER BY id ASC")
    fun getAllCustomers(): Flow<List<CustomerEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCustomer(customer: CustomerEntity): Long

    @Update
    suspend fun updateCustomer(customer: CustomerEntity)

    @Query("SELECT COUNT(*) FROM customers")
    suspend fun countCustomers(): Int
}

@Dao
interface DeliveryScheduleDao {
    @Query("SELECT * FROM deliveries WHERE customerIdNo = :customerIdNo ORDER BY deliveryDate DESC")
    fun getDeliveriesForCustomer(customerIdNo: String): Flow<List<DeliveryScheduleEntity>>

    @Query("SELECT * FROM deliveries WHERE customerIdNo = :customerIdNo AND deliveryDate = :date LIMIT 1")
    fun getTodayDelivery(customerIdNo: String, date: String): Flow<DeliveryScheduleEntity?>

    @Query("SELECT * FROM deliveries WHERE customerIdNo = :customerIdNo AND deliveryDate >= :date ORDER BY deliveryDate ASC LIMIT 1")
    fun getNextUpcomingDelivery(customerIdNo: String, date: String): Flow<DeliveryScheduleEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDelivery(delivery: DeliveryScheduleEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(deliveries: List<DeliveryScheduleEntity>)

    @Update
    suspend fun updateDelivery(delivery: DeliveryScheduleEntity)

    @Query("UPDATE deliveries SET status = :newStatus WHERE id = :id")
    suspend fun updateDeliveryStatus(id: Long, newStatus: String)

    @Query("UPDATE deliveries SET delayMessage = :delayMessage WHERE customerIdNo = :customerIdNo AND deliveryDate = :date")
    suspend fun updateDelayMessage(customerIdNo: String, date: String, delayMessage: String?)
}

@Dao
interface DeliveryPersonDao {
    @Query("SELECT * FROM delivery_persons WHERE employeeId = :empId LIMIT 1")
    fun getDeliveryPerson(empId: String): Flow<DeliveryPersonEntity?>

    @Query("SELECT * FROM delivery_persons WHERE employeeId = :empId LIMIT 1")
    suspend fun getDeliveryPersonSync(empId: String): DeliveryPersonEntity?

    @Query("SELECT * FROM delivery_persons")
    fun getAllDeliveryPersons(): Flow<List<DeliveryPersonEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(deliveryPerson: DeliveryPersonEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(list: List<DeliveryPersonEntity>)

    @Update
    suspend fun update(deliveryPerson: DeliveryPersonEntity)
}

@Dao
interface DepositDao {
    @Query("SELECT * FROM deposits WHERE customerIdNo = :customerIdNo LIMIT 1")
    fun getDepositDetail(customerIdNo: String): Flow<DepositDetailEntity?>

    @Query("SELECT * FROM deposits WHERE customerIdNo = :customerIdNo LIMIT 1")
    suspend fun getDepositDetailSync(customerIdNo: String): DepositDetailEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertDeposit(deposit: DepositDetailEntity): Long

    @Update
    suspend fun updateDeposit(deposit: DepositDetailEntity)

    @Query("SELECT * FROM deposit_transactions WHERE customerIdNo = :customerIdNo ORDER BY id DESC")
    fun getTransactions(customerIdNo: String): Flow<List<DepositTransactionEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTransaction(transaction: DepositTransactionEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTransactions(transactions: List<DepositTransactionEntity>)
}

@Dao
interface CancellationDao {
    @Query("SELECT * FROM cancellation_requests WHERE customerIdNo = :customerIdNo ORDER BY requestedTimestamp DESC")
    fun getRequests(customerIdNo: String): Flow<List<CancellationRequestEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertRequest(request: CancellationRequestEntity): Long

    @Update
    suspend fun updateRequest(request: CancellationRequestEntity)

    @Query("UPDATE cancellation_requests SET status = :newStatus, reviewNotes = :notes WHERE id = :id")
    suspend fun updateStatus(id: Long, newStatus: String, notes: String?)
}

@Dao
interface PaymentDao {
    @Query("SELECT * FROM payments WHERE customerIdNo = :customerIdNo ORDER BY id DESC")
    fun getPayments(customerIdNo: String): Flow<List<PaymentEntity>>

    @Query("SELECT * FROM payments WHERE customerIdNo = :customerIdNo AND status != 'Paid' ORDER BY id ASC")
    fun getPendingPayments(customerIdNo: String): Flow<List<PaymentEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertPayment(payment: PaymentEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(payments: List<PaymentEntity>)

    @Update
    suspend fun updatePayment(payment: PaymentEntity)
}

@Dao
interface AuditLogDao {
    @Query("SELECT * FROM audit_logs WHERE customerIdNo = :customerIdNo ORDER BY timestamp DESC LIMIT 50")
    fun getLogs(customerIdNo: String): Flow<List<AuditLogEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLog(log: AuditLogEntity): Long
}
