# useContacts

Contacts access composable for reading, creating, and deleting device contacts. Supports searching by name and fetching individual contact details.

## Usage

```vue
<script setup>
import { ref } from 'vue'
import { useContacts } from '@thelacanians/vue-native-runtime'

const { requestAccess, getContacts, hasAccess } = useContacts()
const contacts = ref([])

async function loadContacts() {
  await requestAccess()
  if (hasAccess.value) {
    contacts.value = await getContacts()
  }
}
</script>

<template>
  <VView>
    <VButton :onPress="loadContacts"><VText>Load Contacts</VText></VButton>
    <VView v-for="contact in contacts" :key="contact.id">
      <VText>{{ contact.givenName }} {{ contact.familyName }}</VText>
    </VView>
  </VView>
</template>
```

## API

```ts
useContacts(): {
  requestAccess: () => Promise<boolean>
  getContacts: (query?: string) => Promise<Contact[]>
  getContact: (id: string) => Promise<Contact>
  createContact: (data: CreateContactData) => Promise<{ id: string }>
  deleteContact: (id: string) => Promise<void>
  hasAccess: Ref<boolean>
  error: Ref<string | null>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `requestAccess` | `() => Promise<boolean>` | Request contacts access. Returns `true` if granted. |
| `getContacts` | `(query?: string) => Promise<Contact[]>` | Fetch contacts, optionally filtered by name. |
| `getContact` | `(id: string) => Promise<Contact>` | Fetch a single contact by identifier. |
| `createContact` | `(data) => Promise<{ id: string }>` | Create a new contact. Returns the new contact ID. |
| `deleteContact` | `(id: string) => Promise<void>` | Delete a contact by its ID. |
| `hasAccess` | `Ref<boolean>` | Whether contacts access has been granted. |
| `error` | `Ref<string \| null>` | Last error message, or `null`. |

### Types

```ts
interface Contact {
  id: string
  givenName: string
  familyName: string
  middleName: string
  organizationName: string
  jobTitle: string
  hasImage: boolean
  emailAddresses?: ContactField[]
  phoneNumbers?: ContactField[]
}

interface ContactField {
  label: string    // "home", "work", "mobile", etc.
  value: string
}

interface CreateContactData {
  givenName?: string
  familyName?: string
  middleName?: string
  organizationName?: string
  jobTitle?: string
  note?: string
  emailAddresses?: ContactField[]
  phoneNumbers?: ContactField[]
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `Contacts` framework (`CNContactStore`). Add `NSContactsUsageDescription` to `Info.plist`. |
| Android | Uses `ContactsContract` content provider. Requires `READ_CONTACTS` and `WRITE_CONTACTS` permissions. |

## Example

```vue
<script setup>
import { ref, onMounted } from 'vue'
import { useContacts } from '@thelacanians/vue-native-runtime'

const { requestAccess, getContacts, createContact, deleteContact, hasAccess } = useContacts()
const contacts = ref([])
const searchQuery = ref('')

onMounted(async () => {
  await requestAccess()
  if (hasAccess.value) {
    contacts.value = await getContacts()
  }
})

async function search() {
  contacts.value = await getContacts(searchQuery.value || undefined)
}

async function addContact() {
  const result = await createContact({
    givenName: 'Jane',
    familyName: 'Doe',
    emailAddresses: [{ label: 'work', value: 'jane@example.com' }],
    phoneNumbers: [{ label: 'mobile', value: '+1234567890' }],
  })
  console.log('Created contact:', result.id)
  contacts.value = await getContacts()
}

async function removeContact(id: string) {
  await deleteContact(id)
  contacts.value = contacts.value.filter(c => c.id !== id)
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold', marginBottom: 12 }">
      Contacts
    </VText>

    <VView :style="{ flexDirection: 'row', gap: 8, marginBottom: 16 }">
      <VInput
        :value="searchQuery"
        placeholder="Search contacts..."
        :onChangeText="(text) => searchQuery = text"
        :style="{ flex: 1 }"
      />
      <VButton :onPress="search"><VText>Search</VText></VButton>
    </VView>

    <VButton :onPress="addContact" :style="{ marginBottom: 12 }">
      <VText>Add Sample Contact</VText>
    </VButton>

    <VView v-for="contact in contacts" :key="contact.id" :style="{ marginVertical: 4, padding: 12, backgroundColor: '#f5f5f5', borderRadius: 8 }">
      <VText :style="{ fontWeight: 'bold' }">
        {{ contact.givenName }} {{ contact.familyName }}
      </VText>
      <VText v-if="contact.phoneNumbers?.length" :style="{ color: '#666' }">
        {{ contact.phoneNumbers[0].value }}
      </VText>
      <VText v-if="contact.emailAddresses?.length" :style="{ color: '#666' }">
        {{ contact.emailAddresses[0].value }}
      </VText>
      <VButton :onPress="() => removeContact(contact.id)">
        <VText :style="{ color: 'red', fontSize: 12 }">Delete</VText>
      </VButton>
    </VView>

    <VText v-if="contacts.length === 0">No contacts found</VText>
  </VView>
</template>
```

## Notes

- **Permissions:** Always call `requestAccess()` before any read or write operations. The native module checks permissions before executing queries.
- **Search:** On iOS, the search uses `CNContact.predicateForContacts(matchingName:)` which matches against both first and last name. On Android, it uses a `LIKE` query on the display name.
- **Contact images:** The `hasImage` field indicates whether a contact has a photo. Fetching the actual image data is not currently supported.
- **Structured names:** On Android, contact names are split from the display name. For more reliable results on Android, always provide both `givenName` and `familyName` when creating contacts.
