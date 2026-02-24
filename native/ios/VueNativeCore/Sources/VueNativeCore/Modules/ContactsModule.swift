#if canImport(UIKit)
import UIKit
import Contacts

/// Native module for Contacts framework access.
///
/// Methods:
///   - requestAccess() — request contacts access
///   - getContacts(query?) — fetch contacts, optionally filtered by name
///   - getContact(id) — fetch a single contact by identifier
///   - createContact(data) — create a new contact
///   - deleteContact(id) — delete a contact
final class ContactsModule: NativeModule {
    var moduleName: String { "Contacts" }

    private let contactStore = CNContactStore()
    private let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
        CNContactNoteKey as CNKeyDescriptor,
    ]

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "requestAccess":
            if #available(iOS 18.0, *) {
                contactStore.requestAccess(for: .contacts) { granted, error in
                    if let error = error {
                        callback(nil, error.localizedDescription)
                    } else {
                        callback(["granted": granted], nil)
                    }
                }
            } else {
                contactStore.requestAccess(for: .contacts) { granted, error in
                    if let error = error {
                        callback(nil, error.localizedDescription)
                    } else {
                        callback(["granted": granted], nil)
                    }
                }
            }

        case "getContacts":
            let query = args.first as? String
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { callback(nil, "Module deallocated"); return }
                do {
                    var contacts: [CNContact] = []
                    let request = CNContactFetchRequest(keysToFetch: self.keysToFetch)
                    if let query = query, !query.isEmpty {
                        request.predicate = CNContact.predicateForContacts(matchingName: query)
                    }
                    try self.contactStore.enumerateContacts(with: request) { contact, _ in
                        contacts.append(contact)
                    }
                    let result = contacts.map { self.contactToDict($0) }
                    callback(result, nil)
                } catch {
                    callback(nil, error.localizedDescription)
                }
            }

        case "getContact":
            guard let contactId = args.first as? String else {
                callback(nil, "ContactsModule: missing contactId"); return
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { callback(nil, "Module deallocated"); return }
                do {
                    let contact = try self.contactStore.unifiedContact(withIdentifier: contactId, keysToFetch: self.keysToFetch)
                    callback(self.contactToDict(contact), nil)
                } catch {
                    callback(nil, error.localizedDescription)
                }
            }

        case "createContact":
            guard let data = args.first as? [String: Any] else {
                callback(nil, "ContactsModule: missing contact data"); return
            }
            do {
                let contact = CNMutableContact()
                if let givenName = data["givenName"] as? String { contact.givenName = givenName }
                if let familyName = data["familyName"] as? String { contact.familyName = familyName }
                if let middleName = data["middleName"] as? String { contact.middleName = middleName }
                if let organizationName = data["organizationName"] as? String { contact.organizationName = organizationName }
                if let jobTitle = data["jobTitle"] as? String { contact.jobTitle = jobTitle }
                if let note = data["note"] as? String { contact.note = note }

                if let emails = data["emailAddresses"] as? [[String: String]] {
                    contact.emailAddresses = emails.compactMap { entry in
                        guard let value = entry["value"] else { return nil }
                        let label = entry["label"] ?? ""
                        return CNLabeledValue(label: label, value: value as NSString)
                    }
                }

                if let phones = data["phoneNumbers"] as? [[String: String]] {
                    contact.phoneNumbers = phones.compactMap { entry in
                        guard let value = entry["value"] else { return nil }
                        let label = entry["label"] ?? ""
                        return CNLabeledValue(label: label, value: CNPhoneNumber(stringValue: value))
                    }
                }

                let saveRequest = CNSaveRequest()
                saveRequest.add(contact, toContainerWithIdentifier: nil)
                try contactStore.execute(saveRequest)
                callback(["id": contact.identifier], nil)
            } catch {
                callback(nil, error.localizedDescription)
            }

        case "deleteContact":
            guard let contactId = args.first as? String else {
                callback(nil, "ContactsModule: missing contactId"); return
            }
            do {
                let contact = try contactStore.unifiedContact(withIdentifier: contactId, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
                let mutable = contact.mutableCopy() as! CNMutableContact
                let saveRequest = CNSaveRequest()
                saveRequest.delete(mutable)
                try contactStore.execute(saveRequest)
                callback(nil, nil)
            } catch {
                callback(nil, error.localizedDescription)
            }

        default:
            callback(nil, "ContactsModule: Unknown method '\(method)'")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }

    // MARK: - Helpers

    private func contactToDict(_ contact: CNContact) -> [String: Any] {
        var dict: [String: Any] = [
            "id": contact.identifier,
            "givenName": contact.givenName,
            "familyName": contact.familyName,
            "middleName": contact.middleName,
            "organizationName": contact.organizationName,
            "jobTitle": contact.jobTitle,
            "hasImage": contact.imageDataAvailable,
        ]

        if !contact.emailAddresses.isEmpty {
            dict["emailAddresses"] = contact.emailAddresses.map { labeled in
                ["label": labeled.label ?? "", "value": labeled.value as String]
            }
        }

        if !contact.phoneNumbers.isEmpty {
            dict["phoneNumbers"] = contact.phoneNumbers.map { labeled in
                ["label": labeled.label ?? "", "value": labeled.value.stringValue]
            }
        }

        return dict
    }
}
#endif
