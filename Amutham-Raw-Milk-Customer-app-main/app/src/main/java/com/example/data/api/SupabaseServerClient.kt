package com.example.data.api

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

/**
 * Centralized Supabase REST Server Client
 * Connects Native Android App directly to Live Production Supabase Cloud Server Database.
 */
object SupabaseServerClient {
    private const val TAG = "SupabaseServerClient"
    
    var supabaseUrl: String = "https://czmnxrrqcrcqwvdlruif.supabase.co"
    var supabaseAnonKey: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN6bW54cnJxY3JjcXd2ZGxydWlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMTU5NjAsImV4cCI6MjEwNTg5MTk2MH0.-jex033UIYC_PnoLg53pWeKZVY68gIsJFWJiDzO7if0"

    suspend fun fetchFromSupabaseTable(tableName: String): String? = withContext(Dispatchers.IO) {
        try {
            val endpoint = "$supabaseUrl/rest/v1/$tableName?select=*"
            val url = URL(endpoint)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.setRequestProperty("apikey", supabaseAnonKey)
            conn.setRequestProperty("Authorization", "Bearer $supabaseAnonKey")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.connectTimeout = 5000
            conn.readTimeout = 5000

            val responseCode = conn.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = conn.inputStream.bufferedReader().use { it.readText() }
                Log.d(TAG, "Successfully fetched live data from Supabase table $tableName")
                return@withContext response
            } else {
                Log.w(TAG, "Supabase HTTP $responseCode for table $tableName")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Supabase connection error for table $tableName: ${e.localizedMessage}")
        }
        return@withContext null
    }

    suspend fun postToSupabaseTable(tableName: String, jsonPayload: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val endpoint = "$supabaseUrl/rest/v1/$tableName"
            val url = URL(endpoint)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("apikey", supabaseAnonKey)
            conn.setRequestProperty("Authorization", "Bearer $supabaseAnonKey")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Prefer", "return=representation")
            conn.doOutput = true
            conn.connectTimeout = 5000
            conn.readTimeout = 5000

            conn.outputStream.use { os ->
                os.write(jsonPayload.toByteArray(Charsets.UTF_8))
            }

            val responseCode = conn.responseCode
            if (responseCode in 200..299) {
                Log.d(TAG, "Successfully posted live data to Supabase table $tableName")
                return@withContext true
            } else {
                Log.w(TAG, "Supabase POST HTTP $responseCode for table $tableName")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Supabase POST connection error for table $tableName: ${e.localizedMessage}")
        }
        return@withContext false
    }

    suspend fun syncCustomer(customer: com.example.data.model.CustomerEntity): Boolean {
        val json = org.json.JSONObject().apply {
            put("customer_id", customer.customerIdNo)
            put("name", customer.fullName)
            put("mobile", customer.mobileNumber)
            put("phone", customer.mobileNumber)
            put("address", customer.address)
            put("location", customer.locationName)
            put("latitude", customer.latitude)
            put("longitude", customer.longitude)
            put("password", customer.passwordHash)
            put("account_status", customer.accountStatus)
            put("milk_quantity", customer.dailyQuantityLitres)
            put("delivery_timing", customer.regularTimeSlot)
            put("is_active", true)
        }.toString()
        return postToSupabaseTable("customers", json)
    }

    suspend fun syncCancellation(request: com.example.data.model.CancellationRequestEntity): Boolean {
        val json = org.json.JSONObject().apply {
            put("customer_id", request.customerIdNo)
            put("cancel_date", request.cancelDate)
            put("day_of_week", request.dayOfWeek)
            put("start_time", request.startTime)
            put("end_time", request.endTime)
            put("reason", request.reason)
            put("approval_status", request.status)
        }.toString()
        return postToSupabaseTable("cancellation_requests", json)
    }

    suspend fun syncPayment(payment: com.example.data.model.PaymentEntity): Boolean {
        val json = org.json.JSONObject().apply {
            put("invoice_number", payment.invoiceNumber)
            put("customer_id", payment.customerIdNo)
            put("billing_period", payment.billingPeriod)
            put("total_amount", payment.amountDue)
            put("paid_amount", payment.amountPaid)
            put("due_date", payment.dueDate)
            put("payment_method", payment.paymentMethod)
            put("status", payment.status)
            put("transaction_ref", payment.transactionRef)
        }.toString()
        return postToSupabaseTable("payments", json)
    }

    suspend fun syncDeposit(deposit: com.example.data.model.DepositDetailEntity): Boolean {
        val json = org.json.JSONObject().apply {
            put("customer_id", deposit.customerIdNo)
            put("bottle_qty", deposit.bottleQty)
            put("ice_box_qty", deposit.iceBoxQty)
            put("total_deposit_paid", deposit.totalDepositPaid)
            put("refund_status", deposit.refundStatus)
            put("status", "ACTIVE")
        }.toString()
        return postToSupabaseTable("deposits", json)
    }

    suspend fun syncAuditLog(log: com.example.data.model.AuditLogEntity): Boolean {
        val json = org.json.JSONObject().apply {
            put("id", "AUDIT-${log.id}-${log.timestamp}")
            put("customer_id", log.customerIdNo)
            put("action", log.action)
            put("details", log.details)
            put("timestamp", log.timestamp)
        }.toString()
        return postToSupabaseTable("audit_logs", json)
    }
}

