@isTest
private class EcommerceServiceTest {

    public class MockHttpResponseGenerator implements HttpCalloutMock {
        private String responseBody;
        private Integer statusCode;

        public MockHttpResponseGenerator() {
            this.responseBody = '{}';
            this.statusCode = 200;
        }

        public MockHttpResponseGenerator(String responseBody) {
            this.responseBody = responseBody;
            this.statusCode = 200;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setBody(responseBody);
            res.setStatusCode(statusCode);
            return res;
        }
    }

@IsTest
    static void testGetAccountAndContact() {
        // Create a test case record and contact
        Contact testContact = new Contact(Email = 'test@example.com');
        insert testContact;
        Case testCase = new Case(
            Subject = 'Test Case',
            AccountId = '001XXXXXXXXXXXXXXX' // Replace with a valid Account Id
        );
        insert testCase;

        // Create a mock response for the eCommerce API call
        String mockResponse = '{"totalSize": 1, "done": true, "records": [{"Id": "003XXXXXXXXXXXXXXX"}]}'; // Replace with valid response data

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        EcommerceService service = new EcommerceService();
        service.getAccountAndContact(testCase.Id, testCase.ContactEmail);
        Test.stopTest();

        // Verify that the account and contact fields on the case record are updated
        List<Case> updatedCases = [SELECT AccountId, ContactId FROM Case WHERE Id = :testCase.Id];
        Case updatedCase = updatedCases[0];
        System.assertNotEquals(null, updatedCase.AccountId);
        System.assertNotEquals(null, updatedCase.ContactId);
    }

@IsTest
    static void testAuthenticate() {
        // Create a mock response for the eCommerce API call
        String mockResponse = '{"access_token": "test_access_token"}';

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        EcommerceService service = new EcommerceService();
        String accessToken = service.authenticate();
        Test.stopTest();

        // Verify that the access token is correct
        System.assertEquals('test_access_token', accessToken);
    }

@IsTest
    static void testCallEcommerceApi() {
        // Create a test case record
        Contact testContact = new Contact(Email = 'test@example.com');
        insert testContact;
        Case testCase = new Case(
            Subject = 'Test Case'
        );
        insert testCase;

        // Create a mock response for the eCommerce API call
        String mockResponse = '{"totalSize": 1, "done": true, "records": [{"Id": "003XXXXXXXXXXXXXXX"}]}'; // Replace with valid response data

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        EcommerceService service = new EcommerceService();
        service.callEcommerceApi(testCase.Id, testCase.ContactEmail, 'test_access_token');
        Test.stopTest();

        // Verify that the contact field on the case record is updated
        List<Case> updatedCases = [SELECT ContactId FROM Case WHERE Id = :testCase.Id];
        System.assertNotEquals(null, updatedCases[0].ContactId);
    }

@IsTest
    static void testGetContactDetailsById() {
        // Create a test contact
        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'test@example.com'
        );
        insert testContact;
        
        // Create a test access token
        String testAccessToken = 'test_access_token';

        String mockResponse = '{' +
            '"Id": "' + testContact.Id + '",' +
            '"FirstName": "' + testContact.FirstName + '",' +
            '"LastName": "' + testContact.LastName + '",' +
            '"Email": "' + testContact.Email + '"' +
            '}';

        // Set up the mock HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        // Call the getContactDetailsById method
        EcommerceService service = new EcommerceService();
        Map<String, Object> contactDetails = service.getContactDetailsById(testContact.Id, testAccessToken);
        
        // Verify the results
        System.assertNotEquals(null, contactDetails);
        System.assertEquals(testContact.Id, contactDetails.get('Id'));
    }

@IsTest
    static void testUpsertAccountAndContact() {
        // Create a test case record
        Contact testContact = new Contact(Email = 'test@example.com');
        insert testContact;
        Case testCase = new Case(
            Subject = 'Test Case'
        );
        insert testCase;

        // Create a mock response for the eCommerce API call
        String mockResponse = '{"totalSize": 1, "done": true, "records": [{"Id": "003XXXXXXXXXXXXXXX"}]}'; // Replace with valid response data

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(mockResponse));

        Test.startTest();
        EcommerceService service = new EcommerceService();
        service.upsertAccountAndContact(testCase.Id, new Map<String, Object>{
            'Id' => '003XXXXXXXXXXXXXXX',
            'FirstName' => 'John',
            'LastName' => 'Doe',
            'Email' => 'test@example.com',
            'Phone' => '123-456-7890'
        });
        Test.stopTest();

        // Verify that the account and contact fields on the case record are updated
        List<Case> updatedCases = [SELECT AccountId, ContactId FROM Case WHERE Id = :testCase.Id];
        Case updatedCase = updatedCases[0];
        System.assertNotEquals(null, updatedCase.AccountId);
        System.assertNotEquals(null, updatedCase.ContactId);
    }
}