package com.vuenative.core

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.ContactsContract
import androidx.core.content.ContextCompat

class ContactsModule : NativeModule {
    override val moduleName = "Contacts"

    private var context: Context? = null

    override fun initialize(context: Context, bridge: NativeBridge) {
        this.context = context.applicationContext
    }

    override fun invoke(method: String, args: List<Any?>, bridge: NativeBridge, callback: (Any?, String?) -> Unit) {
        val ctx = context ?: run {
            callback(null, "Not initialized")
            return
        }

        when (method) {
            "requestAccess" -> {
                val granted = ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CONTACTS) ==
                    PackageManager.PERMISSION_GRANTED
                callback(mapOf("granted" to granted), null)
            }

            "getContacts" -> {
                val query = args.getOrNull(0)?.toString()

                if (!hasReadPermission(ctx)) {
                    callback(null, "Contacts read permission not granted")
                    return
                }

                try {
                    val contacts = mutableListOf<Map<String, Any?>>()
                    val selection = if (!query.isNullOrEmpty()) {
                        "${ContactsContract.Contacts.DISPLAY_NAME} LIKE ?"
                    } else {
                        null
                    }
                    val selectionArgs = if (!query.isNullOrEmpty()) {
                        arrayOf("%$query%")
                    } else {
                        null
                    }

                    ctx.contentResolver.query(
                        ContactsContract.Contacts.CONTENT_URI,
                        arrayOf(
                            ContactsContract.Contacts._ID,
                            ContactsContract.Contacts.DISPLAY_NAME,
                            ContactsContract.Contacts.HAS_PHONE_NUMBER,
                            ContactsContract.Contacts.PHOTO_URI,
                        ),
                        selection, selectionArgs,
                        "${ContactsContract.Contacts.DISPLAY_NAME} ASC"
                    )?.use { cursor ->
                        while (cursor.moveToNext()) {
                            val contactId = cursor.getString(0)
                            val displayName = cursor.getString(1) ?: ""
                            val hasPhone = cursor.getInt(2) > 0

                            val contact = mutableMapOf<String, Any?>(
                                "id" to contactId,
                                "givenName" to displayName.split(" ").firstOrNull().orEmpty(),
                                "familyName" to displayName.split(" ").drop(1).joinToString(" "),
                                "middleName" to "",
                                "organizationName" to "",
                                "jobTitle" to "",
                                "hasImage" to (cursor.getString(3) != null),
                            )

                            // Fetch phone numbers
                            if (hasPhone) {
                                contact["phoneNumbers"] = getPhoneNumbers(ctx, contactId)
                            }

                            // Fetch emails
                            contact["emailAddresses"] = getEmails(ctx, contactId)

                            contacts.add(contact)
                        }
                    }
                    callback(contacts, null)
                } catch (e: Exception) {
                    callback(null, e.message)
                }
            }

            "getContact" -> {
                val contactId = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "Missing contactId")
                    return
                }

                if (!hasReadPermission(ctx)) {
                    callback(null, "Contacts read permission not granted")
                    return
                }

                try {
                    ctx.contentResolver.query(
                        ContactsContract.Contacts.CONTENT_URI,
                        arrayOf(
                            ContactsContract.Contacts._ID,
                            ContactsContract.Contacts.DISPLAY_NAME,
                            ContactsContract.Contacts.HAS_PHONE_NUMBER,
                            ContactsContract.Contacts.PHOTO_URI,
                        ),
                        "${ContactsContract.Contacts._ID} = ?",
                        arrayOf(contactId), null
                    )?.use { cursor ->
                        if (cursor.moveToFirst()) {
                            val displayName = cursor.getString(1) ?: ""
                            val hasPhone = cursor.getInt(2) > 0
                            val contact = mutableMapOf<String, Any?>(
                                "id" to contactId,
                                "givenName" to displayName.split(" ").firstOrNull().orEmpty(),
                                "familyName" to displayName.split(" ").drop(1).joinToString(" "),
                                "middleName" to "",
                                "organizationName" to "",
                                "jobTitle" to "",
                                "hasImage" to (cursor.getString(3) != null),
                            )
                            if (hasPhone) {
                                contact["phoneNumbers"] = getPhoneNumbers(ctx, contactId)
                            }
                            contact["emailAddresses"] = getEmails(ctx, contactId)
                            callback(contact, null)
                        } else {
                            callback(null, "Contact not found: $contactId")
                        }
                    } ?: callback(null, "Contact not found: $contactId")
                } catch (e: Exception) {
                    callback(null, e.message)
                }
            }

            "createContact" -> {
                @Suppress("UNCHECKED_CAST")
                val data = args.getOrNull(0) as? Map<String, Any?> ?: run {
                    callback(null, "Missing contact data")
                    return
                }

                if (!hasWritePermission(ctx)) {
                    callback(null, "Contacts write permission not granted")
                    return
                }

                try {
                    val ops = mutableListOf<android.content.ContentProviderOperation>()

                    // Insert raw contact
                    ops.add(
                        android.content.ContentProviderOperation.newInsert(ContactsContract.RawContacts.CONTENT_URI)
                            .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
                            .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null)
                            .build()
                    )

                    // Name
                    val givenName = data["givenName"]?.toString() ?: ""
                    val familyName = data["familyName"]?.toString() ?: ""
                    ops.add(
                        android.content.ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                            .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                            .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE)
                            .withValue(ContactsContract.CommonDataKinds.StructuredName.GIVEN_NAME, givenName)
                            .withValue(ContactsContract.CommonDataKinds.StructuredName.FAMILY_NAME, familyName)
                            .build()
                    )

                    // Phone numbers
                    @Suppress("UNCHECKED_CAST")
                    val phones = data["phoneNumbers"] as? List<Map<String, String>>
                    phones?.forEach { phone ->
                        ops.add(
                            android.content.ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                                .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                                .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE)
                                .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, phone["value"])
                                .withValue(ContactsContract.CommonDataKinds.Phone.TYPE, ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE)
                                .build()
                        )
                    }

                    // Emails
                    @Suppress("UNCHECKED_CAST")
                    val emails = data["emailAddresses"] as? List<Map<String, String>>
                    emails?.forEach { email ->
                        ops.add(
                            android.content.ContentProviderOperation.newInsert(ContactsContract.Data.CONTENT_URI)
                                .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                                .withValue(ContactsContract.Data.MIMETYPE, ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE)
                                .withValue(ContactsContract.CommonDataKinds.Email.DATA, email["value"])
                                .withValue(ContactsContract.CommonDataKinds.Email.TYPE, ContactsContract.CommonDataKinds.Email.TYPE_HOME)
                                .build()
                        )
                    }

                    val results = ctx.contentResolver.applyBatch(ContactsContract.AUTHORITY, ArrayList(ops))
                    val rawContactUri = results.firstOrNull()?.uri
                    val rawContactId = rawContactUri?.lastPathSegment ?: ""
                    callback(mapOf("id" to rawContactId), null)
                } catch (e: Exception) {
                    callback(null, e.message)
                }
            }

            "deleteContact" -> {
                val contactId = args.getOrNull(0)?.toString() ?: run {
                    callback(null, "Missing contactId")
                    return
                }

                if (!hasWritePermission(ctx)) {
                    callback(null, "Contacts write permission not granted")
                    return
                }

                try {
                    val uri = ContactsContract.Contacts.CONTENT_URI.buildUpon().appendPath(contactId).build()
                    ctx.contentResolver.delete(uri, null, null)
                    callback(null, null)
                } catch (e: Exception) {
                    callback(null, e.message)
                }
            }

            else -> callback(null, "Unknown method: $method")
        }
    }

    private fun hasReadPermission(ctx: Context): Boolean =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED

    private fun hasWritePermission(ctx: Context): Boolean =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.WRITE_CONTACTS) == PackageManager.PERMISSION_GRANTED

    private fun getPhoneNumbers(ctx: Context, contactId: String): List<Map<String, String>> {
        val phones = mutableListOf<Map<String, String>>()
        ctx.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.NUMBER,
                ContactsContract.CommonDataKinds.Phone.TYPE,
            ),
            "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
            arrayOf(contactId), null
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                phones.add(mapOf(
                    "value" to (cursor.getString(0) ?: ""),
                    "label" to getPhoneLabel(cursor.getInt(1)),
                ))
            }
        }
        return phones
    }

    private fun getEmails(ctx: Context, contactId: String): List<Map<String, String>> {
        val emails = mutableListOf<Map<String, String>>()
        ctx.contentResolver.query(
            ContactsContract.CommonDataKinds.Email.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Email.DATA,
                ContactsContract.CommonDataKinds.Email.TYPE,
            ),
            "${ContactsContract.CommonDataKinds.Email.CONTACT_ID} = ?",
            arrayOf(contactId), null
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                emails.add(mapOf(
                    "value" to (cursor.getString(0) ?: ""),
                    "label" to getEmailLabel(cursor.getInt(1)),
                ))
            }
        }
        return emails
    }

    private fun getPhoneLabel(type: Int): String = when (type) {
        ContactsContract.CommonDataKinds.Phone.TYPE_HOME -> "home"
        ContactsContract.CommonDataKinds.Phone.TYPE_WORK -> "work"
        ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE -> "mobile"
        else -> "other"
    }

    private fun getEmailLabel(type: Int): String = when (type) {
        ContactsContract.CommonDataKinds.Email.TYPE_HOME -> "home"
        ContactsContract.CommonDataKinds.Email.TYPE_WORK -> "work"
        else -> "other"
    }
}
