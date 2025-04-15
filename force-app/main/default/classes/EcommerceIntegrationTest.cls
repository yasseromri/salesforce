@isTest
private class EcommerceIntegrationTest {

    // Mock HTTP response generator
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/services/oauth2/token')) {
                // Mock authentication response
                res.setBody('{"access_token":"mock_access_token"}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/services/data/v63.0/query')) {
                // Mock query response
                res.setBody('{"totalSize":1,"done":true,"records":[{"attributes":{"type":"Contact","url":"/services/data/v63.0/sobjects/Contact/0035e000013u000AAA"},"Id":"0035e000013u000AAA"}]}');
                res.setStatusCode(200);
            } else if (req.getEndpoint().contains('/services/data/v47.0/sobjects/Contact/')) {
                // Mock contact details response
                res.setBody('{"attributes":{"type":"Contact","url":"/services/data/v47.0/sobjects/Contact/0035e000013u000AAA"},"Id":"0035e000013u000AAA","Name":"Test Contact","LastName":"Contact","FirstName":"Test","Email":"test@example.com","Phone":"1234567890"}');
                res.setStatusCode(200);
            } else {
                res.setBody('{}');
                res.setStatusCode(404);
            }
            return res;
        }
    }

    @testSetup
    static void setup() {
        // Create a test account and contact
        Account a = new Account(Name = 'Test Account');
        insert a;

        Contact c1 = new Contact(FirstName = 'Test', LastName = 'Contact', Email = 'test@example.com', AccountId = a.Id);
        insert c1;

        // Create a test case
        Case c = new Case();
        c.Subject = 'Test case';
        c.SuppliedEmail = 'test@example.com';
        insert c;
    }

@IsTest
    static void testGetAccountAndContact() {
        // Create a test case
        Case c = new Case();
        c.Subject = 'Test case';
        c.SuppliedEmail = 'test@example.com';
        insert c;

        // Set up the mock response for the API call
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        // EcommerceIntegration.getAccountAndContact(c.Id, c.SuppliedEmail);
        Test.stopTest();
        Account a = [SELECT Id FROM Account WHERE Name = 'Account for Test Contact' LIMIT 1];
        Contact c1 = [SELECT Id FROM Contact WHERE Email = 'test@example.com' LIMIT 1];

        // Verify that the account and contact were updated
        c = [SELECT AccountId, ContactId FROM Case WHERE Id = :c.Id];
        System.assertEquals(a.Id, c.AccountId);
        System.assertEquals(c1.Id, c.ContactId);
    }
}