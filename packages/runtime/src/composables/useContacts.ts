import { ref } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

export interface ContactField {
  label: string
  value: string
}

export interface Contact {
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

export interface CreateContactData {
  givenName?: string
  familyName?: string
  middleName?: string
  organizationName?: string
  jobTitle?: string
  note?: string
  emailAddresses?: ContactField[]
  phoneNumbers?: ContactField[]
}

// ─── useContacts composable ───────────────────────────────────────────────

/**
 * Contacts access composable for reading and writing device contacts.
 *
 * @example
 * const { requestAccess, getContacts, createContact } = useContacts()
 *
 * await requestAccess()
 * const contacts = await getContacts('John')
 */
export function useContacts() {
  const hasAccess = ref(false)
  const error = ref<string | null>(null)

  async function requestAccess(): Promise<boolean> {
    try {
      const result: { granted: boolean } = await NativeBridge.invokeNativeModule('Contacts', 'requestAccess')
      hasAccess.value = result.granted
      return result.granted
    } catch (e: any) {
      error.value = e?.message || String(e)
      return false
    }
  }

  async function getContacts(query?: string): Promise<Contact[]> {
    return NativeBridge.invokeNativeModule('Contacts', 'getContacts', [query])
  }

  async function getContact(id: string): Promise<Contact> {
    return NativeBridge.invokeNativeModule('Contacts', 'getContact', [id])
  }

  async function createContact(data: CreateContactData): Promise<{ id: string }> {
    return NativeBridge.invokeNativeModule('Contacts', 'createContact', [data])
  }

  async function deleteContact(id: string): Promise<void> {
    return NativeBridge.invokeNativeModule('Contacts', 'deleteContact', [id])
  }

  return { requestAccess, getContacts, getContact, createContact, deleteContact, hasAccess, error }
}
