package com.vuenative.core

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import androidx.credentials.*
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential

/**
 * Native module for social authentication (Google Sign In on Android).
 *
 * Methods:
 *   - signInWithGoogle(clientId: String) -- present Google Sign In via Credential Manager
 *   - signInWithApple() -- not natively supported; returns error with web flow suggestion
 *   - signOut(provider: String) -- clear cached credentials
 *   - getCurrentUser(provider: String) -- check for existing session
 */
class SocialAuthModule : NativeModule {
    override val moduleName = "SocialAuth"
    private var context: Context? = null
    private var bridge: NativeBridge? = null
    private var prefs: SharedPreferences? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context
        this.bridge = bridge
        this.prefs = context.getSharedPreferences("vn_social_auth", Context.MODE_PRIVATE)
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        when (method) {
            "signInWithApple" -> {
                // Apple Sign In on Android requires web-based flow
                callback(null, "signInWithApple: not available on Android. Use a web-based Apple OAuth flow instead.")
            }
            "signInWithGoogle" -> {
                val clientId = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "signInWithGoogle: expected clientId string")
                    return
                }
                handleGoogleSignIn(clientId, callback)
            }
            "signOut" -> {
                val provider = args.getOrNull(0)?.toString() ?: "google"
                handleSignOut(provider, callback)
            }
            "getCurrentUser" -> {
                val provider = args.getOrNull(0)?.toString() ?: "google"
                handleGetCurrentUser(provider, callback)
            }
            else -> callback(null, "SocialAuthModule: unknown method '$method'")
        }
    }

    // ── Google Sign In via Credential Manager ───────────────────────────────

    private fun handleGoogleSignIn(clientId: String, callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run { callback(null, "SocialAuth: no context"); return }
        val activity = ctx as? Activity

        if (activity == null) {
            callback(null, "signInWithGoogle: no activity available (context is not an Activity)")
            return
        }

        val credentialManager = CredentialManager.create(ctx)

        val googleIdOption = GetGoogleIdOption.Builder()
            .setFilterByAuthorizedAccounts(false)
            .setServerClientId(clientId)
            .build()

        val request = GetCredentialRequest.Builder()
            .addCredentialOption(googleIdOption)
            .build()

        mainHandler.post {
            kotlinx.coroutines.GlobalScope.launch(kotlinx.coroutines.Dispatchers.Main) {
                try {
                    val result = credentialManager.getCredential(activity, request)
                    val credential = result.credential

                    when (credential) {
                        is CustomCredential -> {
                            if (credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                                val googleCredential = GoogleIdTokenCredential.createFrom(credential.data)
                                val userInfo = mapOf(
                                    "userId" to googleCredential.id,
                                    "email" to googleCredential.id,
                                    "fullName" to (googleCredential.displayName ?: ""),
                                    "identityToken" to googleCredential.idToken,
                                )

                                prefs?.edit()
                                    ?.putString("google_userId", googleCredential.id)
                                    ?.putString("google_email", googleCredential.id)
                                    ?.putString("google_name", googleCredential.displayName ?: "")
                                    ?.apply()

                                callback(userInfo, null)
                            } else {
                                callback(null, "signInWithGoogle: unexpected credential type")
                            }
                        }
                        else -> callback(null, "signInWithGoogle: unexpected credential type")
                    }
                } catch (e: GetCredentialCancellationException) {
                    callback(null, "signInWithGoogle: user cancelled")
                } catch (e: Exception) {
                    callback(null, "signInWithGoogle: ${e.message}")
                }
            }
        }
    }

    // ── Sign Out ────────────────────────────────────────────────────────────

    private fun handleSignOut(provider: String, callback: (Any?, String?) -> Unit) {
        when (provider) {
            "google" -> {
                prefs?.edit()?.clear()?.apply()
            }
            "apple" -> {
                // No-op on Android
            }
        }
        callback(null, null)
    }

    // ── Get Current User ────────────────────────────────────────────────────

    private fun handleGetCurrentUser(provider: String, callback: (Any?, String?) -> Unit) {
        when (provider) {
            "google" -> {
                val userId = prefs?.getString("google_userId", null)
                if (userId != null) {
                    val result = mapOf(
                        "userId" to userId,
                        "email" to (prefs?.getString("google_email", "") ?: ""),
                        "fullName" to (prefs?.getString("google_name", "") ?: ""),
                    )
                    callback(result, null)
                } else {
                    callback(null, null)
                }
            }
            "apple" -> {
                // Apple Sign In not natively supported on Android
                callback(null, null)
            }
            else -> callback(null, null)
        }
    }
}
