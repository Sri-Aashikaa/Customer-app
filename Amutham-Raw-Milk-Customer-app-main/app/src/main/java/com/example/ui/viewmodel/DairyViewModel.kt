package com.example.ui.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.data.db.AppDatabase
import com.example.data.model.AuditLogEntity
import com.example.data.model.CancellationRequestEntity
import com.example.data.model.CustomerEntity
import com.example.data.model.DeliveryPersonEntity
import com.example.data.model.DeliveryScheduleEntity
import com.example.data.model.DepositDetailEntity
import com.example.data.model.DepositTransactionEntity
import com.example.data.model.PaymentEntity
import com.example.data.repository.DairyRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

enum class NavigationTab {
    DASHBOARD,
    DELIVERY,
    PAYMENT,
    DEPOSIT,
    PROFILE,
    REPORTS
}

@OptIn(ExperimentalCoroutinesApi::class)
class DairyViewModel(application: Application) : AndroidViewModel(application) {

    private val database = AppDatabase.getDatabase(application, viewModelScope)
    val repository = DairyRepository(database)

    private val _currentTab = MutableStateFlow(NavigationTab.DASHBOARD)
    val currentTab: StateFlow<NavigationTab> = _currentTab.asStateFlow()

    private val _authError = MutableStateFlow<String?>(null)
    val authError: StateFlow<String?> = _authError.asStateFlow()

    init {
        // Ensure initial seed data is populated
        viewModelScope.launch(Dispatchers.IO) {
            val count = database.customerDao().countCustomers()
            if (count == 0) {
                AppDatabase.populateInitialData(database)
            }
        }
    }

    val currentCustomer: StateFlow<CustomerEntity?> = repository.currentCustomer
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    private val todayDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

    val todayDelivery: StateFlow<DeliveryScheduleEntity?> = repository.currentCustomerId
        .flatMapLatest { id ->
            if (id != null) repository.getTodayDelivery(id, todayDateStr) else flowOf(null)
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    val deliveries: StateFlow<List<DeliveryScheduleEntity>> = repository.currentCustomerId
        .flatMapLatest { id ->
            if (id != null) repository.getDeliveries(id) else flowOf(emptyList())
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val assignedPerson: StateFlow<DeliveryPersonEntity?> = todayDelivery
        .flatMapLatest { delivery ->
            val empId = delivery?.deliveryPersonId ?: "DP-001"
            repository.getDeliveryPerson(empId)
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    val depositDetail: StateFlow<DepositDetailEntity?> = repository.currentCustomerId
        .flatMapLatest { id ->
            if (id != null) repository.getDepositDetail(id) else flowOf(null)
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)

    val depositTransactions: StateFlow<List<DepositTransactionEntity>> = repository.currentCustomerId
        .flatMapLatest { id ->
            if (id != null) repository.getDepositTransactions(id) else flowOf(emptyList())
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val cancellationRequests: StateFlow<List<CancellationRequestEntity>> = repository.currentCustomerId
        .flatMapLatest { id ->
            if (id != null) repository.getCancellationRequests(id) else flowOf(emptyList())
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val payments: StateFlow<List<PaymentEntity>> = repository.currentCustomerId
        .flatMapLatest { id ->
            if (id != null) repository.getPayments(id) else flowOf(emptyList())
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val auditLogs: StateFlow<List<AuditLogEntity>> = repository.currentCustomerId
        .flatMapLatest { id ->
            if (id != null) repository.getAuditLogs(id) else flowOf(emptyList())
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun selectTab(tab: NavigationTab) {
        _currentTab.value = tab
    }

    fun clearAuthError() {
        _authError.value = null
    }

    fun login(customerId: String, pass: String) {
        viewModelScope.launch {
            val result = repository.login(customerId, pass)
            result.onSuccess {
                _authError.value = null
                _currentTab.value = NavigationTab.DASHBOARD
            }.onFailure { err ->
                _authError.value = err.message ?: "Login failed"
            }
        }
    }

    fun register(
        name: String,
        mobile: String,
        address: String,
        locName: String,
        lat: Double,
        lng: Double,
        desiredId: String?,
        pass: String
    ) {
        viewModelScope.launch {
            val result = repository.register(name, mobile, address, locName, lat, lng, desiredId, pass)
            result.onSuccess {
                _authError.value = null
                _currentTab.value = NavigationTab.DASHBOARD
            }.onFailure { err ->
                _authError.value = err.message ?: "Registration failed"
            }
        }
    }

    fun logout() {
        repository.logout()
        _currentTab.value = NavigationTab.DASHBOARD
    }

    fun processPayment(payment: PaymentEntity, method: String, ref: String) {
        viewModelScope.launch {
            repository.processPayment(payment, method, ref)
        }
    }

    fun submitCancellation(date: String, day: String, start: String, end: String, reason: String) {
        viewModelScope.launch {
            val customerId = currentCustomer.value?.customerIdNo ?: "CUST-1001"
            repository.submitCancellationRequest(customerId, date, day, start, end, reason)
        }
    }

    fun updateProfile(name: String, mobile: String, address: String, locName: String, lat: Double, lng: Double) {
        viewModelScope.launch {
            val customerId = currentCustomer.value?.customerIdNo ?: return@launch
            repository.updateProfile(customerId, name, mobile, address, locName, lat, lng)
        }
    }

    fun changePassword(oldPass: String, newPass: String) {
        viewModelScope.launch {
            val customerId = currentCustomer.value?.customerIdNo ?: return@launch
            repository.changePassword(customerId, oldPass, newPass)
        }
    }

    fun requestEquipmentChange(itemType: String, qty: Int, amt: Double) {
        viewModelScope.launch {
            val customerId = currentCustomer.value?.customerIdNo ?: return@launch
            repository.requestDepositEquipment(customerId, itemType, qty, amt)
        }
    }

    fun advanceDeliveryStatus(deliveryId: Long, nextStatus: String) {
        viewModelScope.launch {
            repository.advanceDeliveryStatus(deliveryId, nextStatus)
        }
    }
}
