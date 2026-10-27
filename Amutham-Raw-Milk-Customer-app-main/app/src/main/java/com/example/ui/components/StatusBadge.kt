package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.ui.theme.StatusAssigned
import com.example.ui.theme.StatusCancelled
import com.example.ui.theme.StatusDelivered
import com.example.ui.theme.StatusFailed
import com.example.ui.theme.StatusNearCustomer
import com.example.ui.theme.StatusOutForDelivery
import com.example.ui.theme.StatusPreparing
import com.example.ui.theme.StatusScheduled

@Composable
fun StatusBadge(
    status: String,
    modifier: Modifier = Modifier
) {
    val (bgColor, textColor, dotColor) = when (status) {
        // Delivery
        "Scheduled" -> Triple(Color(0xFFF1F5F9), Color(0xFF475569), StatusScheduled)
        "Preparing" -> Triple(Color(0xFFFEF3C7), Color(0xFF92400E), StatusPreparing)
        "Assigned to Delivery Person" -> Triple(Color(0xFFDBEAFE), Color(0xFF1E40AF), StatusAssigned)
        "Out for Delivery" -> Triple(Color(0xFFEDE9FE), Color(0xFF5B21B6), StatusOutForDelivery)
        "Near Customer" -> Triple(Color(0xFFFFEDD5), Color(0xFF9A3412), StatusNearCustomer)
        "Delivered" -> Triple(Color(0xFFDCFCE7), Color(0xFF15803D), StatusDelivered)
        "Delivery Failed" -> Triple(Color(0xFFFEE2E2), Color(0xFF991B1B), StatusFailed)
        "Cancelled" -> Triple(Color(0xFFF3F4F6), Color(0xFF6B7280), StatusCancelled)

        // Cancellation
        "Pending" -> Triple(Color(0xFFFEF3C7), Color(0xFF92400E), Color(0xFFD97706))
        "Approved" -> Triple(Color(0xFFDCFCE7), Color(0xFF15803D), Color(0xFF16A34A))
        "Rejected" -> Triple(Color(0xFFFEE2E2), Color(0xFF991B1B), Color(0xFFDC2626))
        "Expired" -> Triple(Color(0xFFF3F4F6), Color(0xFF6B7280), Color(0xFF9CA3AF))

        // Payment
        "Paid" -> Triple(Color(0xFFDCFCE7), Color(0xFF15803D), Color(0xFF16A34A))
        "Partially Paid" -> Triple(Color(0xFFE0E7FF), Color(0xFF3730A3), Color(0xFF4F46E5))
        "Overdue" -> Triple(Color(0xFFFEE2E2), Color(0xFF991B1B), Color(0xFFDC2626))

        // Default
        else -> Triple(Color(0xFFF1F5F9), Color(0xFF334155), Color(0xFF64748B))
    }

    Box(
        modifier = modifier
            .background(bgColor, RoundedCornerShape(50))
            .padding(horizontal = 8.dp, vertical = 4.dp),
        contentAlignment = Alignment.Center
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .background(dotColor, CircleShape)
            )
            Spacer(modifier = Modifier.width(5.dp))
            Text(
                text = status,
                color = textColor,
                fontSize = 11.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}
