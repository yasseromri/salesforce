public with sharing class ContactDao implements Dao {
    public Contact getById(Id id) {
        if (!Schema.sObjectType.Contact.isAccessible()) {
            throw new System.SecurityException('You do not have permission to access Contact records.');
        }
        return [SELECT Id, LastName, FirstName, Email, Phone, AccountId, External_id__c FROM Contact WHERE Id = :id];
    }

    public List<Contact> getAll() {
        if (!Schema.sObjectType.Contact.isAccessible()) {
            throw new System.SecurityException('You do not have permission to access Contact records.');
        }
        return [SELECT Id, LastName, FirstName, Email, Phone, AccountId, External_id__c FROM Contact];
    }

    public void save(Contact contact) {
        if (!Schema.sObjectType.Contact.isCreateable()) {
            throw new System.SecurityException('You do not have permission to create Contact records.');
        }
        insert contact;
    }

    public void updateEntity(Contact contact) {
        if (!Schema.sObjectType.Contact.isUpdateable()) {
            // Throw an exception or handle the lack of permissions gracefully
            throw new System.SecurityException('You do not have permission to update Contact records.');
        }
        update contact;
    }

    public void deleteEntity(Contact contact) {
        // Check if the current user has delete access to the Contact object
        if (!Schema.sObjectType.Contact.isDeletable()) {
            // Throw an exception or handle the lack of permissions gracefully
            throw new System.SecurityException('You do not have permission to delete Contact records.');
        }
        delete contact;
    }



}