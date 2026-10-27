package com.example

import com.example.data.db.AppDatabase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ExampleUnitTest {
    @Test
    fun addition_isCorrect() {
        assertEquals(4, 2 + 2)
    }

    @Test
    fun passwordHash_isDeterministicAndSecure() {
        val hash1 = AppDatabase.hashPassword("password123")
        val hash2 = AppDatabase.hashPassword("password123")
        val hashWrong = AppDatabase.hashPassword("wrongpassword")

        assertEquals(hash1, hash2)
        assertNotEquals(hash1, hashWrong)
        assertTrue(hash1.length == 64) // SHA-256 hex string length
    }
}
