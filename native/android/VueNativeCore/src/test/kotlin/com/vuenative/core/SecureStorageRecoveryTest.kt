package com.vuenative.core

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.security.GeneralSecurityException
import javax.crypto.AEADBadTagException

/**
 * Regression tests for the Auto Backup restore case: the Keystore master key does
 * not migrate, so opening the encrypted store throws. The recovery deletes the
 * undecryptable file and retries exactly once. `EncryptedSharedPreferences` needs
 * a real Keystore, which Robolectric does not provide, so the create step is
 * passed in as a lambda.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SecureStorageRecoveryTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    @Test
    fun aHealthyStoreIsOpenedWithoutDeletingAnything() {
        val healthy = context.getSharedPreferences("recovery_healthy", Context.MODE_PRIVATE)
        var creates = 0
        var deletes = 0

        val opened = SecureStorageModule.openWithRecovery(
            create = { creates += 1; healthy },
            deleteStore = { deletes += 1 },
        )

        assertSame(healthy, opened)
        assertEquals(1, creates)
        assertEquals(0, deletes)
    }

    @Test
    fun anUndecryptableStoreIsDeletedAndCreatedExactlyOnce() {
        val recreated = context.getSharedPreferences("recovery_recreated", Context.MODE_PRIVATE)
        var creates = 0
        var deletes = 0

        val opened = SecureStorageModule.openWithRecovery(
            create = {
                creates += 1
                if (creates == 1) throw AEADBadTagException("keyset was encrypted with another master key")
                recreated
            },
            deleteStore = { deletes += 1 },
        )

        assertSame(recreated, opened)
        assertEquals("the failed store must be deleted once", 1, deletes)
        assertEquals("create must run once more after the delete", 2, creates)
    }

    @Test
    fun aStoreThatFailsAgainAfterRecoveryPropagatesTheFailure() {
        var creates = 0
        var deletes = 0

        val failure = assertThrows(GeneralSecurityException::class.java) {
            SecureStorageModule.openWithRecovery(
                create = {
                    creates += 1
                    throw GeneralSecurityException("keystore unavailable")
                },
                deleteStore = { deletes += 1 },
            )
        }

        assertEquals("keystore unavailable", failure.message)
        assertEquals("recovery must not loop", 2, creates)
        assertEquals(1, deletes)
    }

    @Test
    fun aNonCryptoFailureIsRethrownWithoutDeletingTheStore() {
        var creates = 0
        var deletes = 0

        assertThrows(IllegalStateException::class.java) {
            SecureStorageModule.openWithRecovery(
                create = {
                    creates += 1
                    throw IllegalStateException("keystore temporarily unavailable")
                },
                deleteStore = { deletes += 1 },
            )
        }

        assertEquals("a transient failure must not trigger a retry", 1, creates)
        assertEquals("a transient failure must never delete the store", 0, deletes)
    }
}
