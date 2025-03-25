@isTest
private class AccountDaoTest {

    private static User createMinAccessUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name='Minimum Access - Salesforce'];
        User u = new User(
            Alias = 'minuser',
            Email='minuser@testorg.com',
            EmailEncodingKey='UTF-8',
            LastName='Testing',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName='minuser@testorg.com'
        );
        return u;
    }
    private static AccountDao accountDao = new AccountDao();

@IsTest static void testGetById() {
        Account account = new Account(Name='Test Account');
        insert account;
        Test.startTest();
        Account result = accountDao.getById(account.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(account.Id, result.Id);
        System.assertEquals(account.Name, result.Name);
    }

@IsTest static void testGetAll() {
        List<Account> accounts = accountDao.getAll();
        System.assertEquals(0, accounts.size());
    }

@IsTest static void testSavePermissionDenied() {
        User minAccessUser = createMinAccessUser();
        Account account = new Account(Name='Test Account');
        insert minAccessUser;
        Test.startTest();
        System.runAs(minAccessUser) {
            try {
                accountDao.save(account);
                System.assert(false, 'Expected exception was not thrown');
            } catch (System.SecurityException e) {
                System.assertEquals('You do not have permission to create Account records.', e.getMessage());
            }
        }
        Test.stopTest();
    }

@IsTest static void testUpdateEntity() {
    Account account = new Account(Name='Test Account');
    insert account;
    Test.startTest();
    account.Name = 'Updated Name';
    accountDao.updateEntity(account);
    Account updatedAccount = [SELECT Name FROM Account WHERE Id = :account.Id];
    Test.stopTest();
    System.assertEquals('Updated Name', updatedAccount.Name);
}

@IsTest
    static void testDeleteEntity() {
        Account account = new Account(Name='Test Account');
        insert account;
        Test.startTest();
        accountDao.deleteEntity(account);
        Test.stopTest();
        List<Account> accounts = [SELECT Id FROM Account WHERE Id = :account.Id];
        System.assertEquals(0, accounts.size());
    }

@IsTest
    static void testSave() {
        Account account = new Account(Name='Test Account');
        Test.startTest();
        accountDao.save(account);
        Test.stopTest();
        List<Account> accounts = [SELECT Id FROM Account WHERE Id = :account.Id];
        System.assertEquals(1, accounts.size());
    }
}
