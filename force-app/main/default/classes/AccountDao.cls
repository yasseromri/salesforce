public with sharing class AccountDao {
    public Account getById(Id id) {
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new System.SecurityException('You do not have permission to access Account records.');
        }
        return [SELECT Id, Name FROM Account WHERE Id = :id];
    }

    public List<Account> getAll() {
        if (!Schema.sObjectType.Account.isAccessible()) {
            throw new System.SecurityException('You do not have permission to access Account records.');
        }
        return [SELECT Id, Name FROM Account];
    }

    public void save(Account account) {
        if (!Schema.sObjectType.Account.isCreateable()) {
            throw new System.SecurityException('You do not have permission to create Account records.');
        }
        insert account;
    }

    public void updateEntity(Account account) {
        if (!Schema.sObjectType.Account.isUpdateable()) {
            // Throw an exception or handle the lack of permissions gracefully
            throw new System.SecurityException('You do not have permission to delete Account records.');
        }
        update account;
    }

    public void deleteEntity(Account account) {
        // Check if the current user has delete access to the Account object
        if (!Schema.sObjectType.Account.isDeletable()) {
            // Throw an exception or handle the lack of permissions gracefully
            throw new System.SecurityException('You do not have permission to delete Account records.');
        }
    
        // Perform the delete operation if the user has the necessary permissions
        delete account;
    }
}