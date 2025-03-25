public with sharing class EcommerceService implements EcommerceInterface {
    private static final String AUTH_URL = 'https://login.salesforce.com/services/oauth2/token';
    private static final String ENDPOINT_QUERY = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com/services/data/v63.0/query';
    private static final String ENDPOINT_SOBJECT = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com/services/data/v47.0/sobjects/Contact/';

    private static AccountDao accountDao = new AccountDao();
    private static ContactDao contactDao = new ContactDao();

    public void getAccountAndContact(Id caseId, String email) {
        try {
            String accessToken = authenticate();
            if (accessToken != null) {
                callEcommerceApi(caseId, email, accessToken);
            }
        } catch (Exception e) {
            System.debug('Error in getAccountAndContact: ' + e.getMessage());
            // Consider adding more robust error handling here, such as logging to a custom object or sending an email alert.
        }
    }

    public String authenticate() {
        String clientId = System.Label.OAuth_Client_ID;
        String clientSecret = System.Label.OAuth_Client_Secret;
        String username = System.Label.OAuth_Username;
        String password = System.Label.OAuth_Password;

        HttpRequest authRequest = new HttpRequest();
        authRequest.setEndpoint(AUTH_URL);
        authRequest.setMethod('POST');
        authRequest.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        authRequest.setBody(
            'grant_type=password' +
            '&client_id=' + clientId +
            '&client_secret=' + clientSecret +
            '&username=' + username +
            '&password=' + password
        );

        Http http = new Http();
        HttpResponse authResponse = http.send(authRequest);

        if (authResponse.getStatusCode() == 200) {
            Map<String, Object> authResult = (Map<String, Object>) JSON.deserializeUntyped(authResponse.getBody());
            return (String) authResult.get('access_token');
        } else {
            System.debug('Authentication failed: ' + authResponse.getBody());
            // Consider throwing a custom exception here to handle authentication failures more gracefully.
            return null;
        }
    }

    public void callEcommerceApi(Id caseId, String email, String accessToken) {
        String query = 'SELECT+Id+FROM+Contact+WHERE+Email=\'' + EncodingUtil.urlEncode(email, 'UTF-8') + '\'';
        String endpoint = ENDPOINT_QUERY + '?q=' + query;

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse response = http.send(request);

        if (response.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            List<Object> records = (List<Object>) result.get('records');
            if (!records.isEmpty()) {
                for (Object o : records) {
                    Map<String, Object> record = (Map<String, Object>) o;
                    String contactId = (String) record.get('Id');
                    if (contactId != null) {
                        Map<String, Object> contactDetails = getContactDetailsById(contactId, accessToken);
                        if (contactDetails != null) {
                            upsertAccountAndContact(caseId, contactDetails);
                        } else {
                            System.debug('No records found for contact: ' + contactId);
                        }
                    }
                }
            } else {
                System.debug('No records found for email: ' + email);
            }
        } else {
            System.debug('API call failed: ' + response.getBody());
            // Consider throwing a custom exception here to handle API call failures.
        }
    }

    public Map<String, Object> getContactDetailsById(String contactId, String accessToken) {
        String endpoint = ENDPOINT_SOBJECT + contactId;
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('Authorization', 'Bearer ' + accessToken);
        request.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse response = http.send(request);

        if (response.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        } else {
            System.debug('API call failed for get contact by Id: ' + response.getBody());
            // Consider throwing a custom exception here to handle API call failures.
            return null;
        }
    }

    public void upsertAccountAndContact(Id caseId, Map<String, Object> data) {
        try {
            Account acc = new Account();
            String contactName = (String) data.get('Name');
            acc.Name = contactName != null ? 'Account for ' + contactName : 'Account for (no name)';
            accountDao.save(acc);

            String externalId = (String) data.get('Id');
            List<Contact> existingContacts = [SELECT Id, External_id__c FROM Contact WHERE External_id__c = :externalId LIMIT 1];
            Contact con;
            if (!existingContacts.isEmpty()) {
                con = existingContacts[0];
                con.LastName = (String) data.get('LastName');
                con.FirstName = (String) data.get('FirstName');
                con.Email = (String) data.get('Email');
                con.Phone = (String) data.get('Phone');
                con.AccountId = acc.Id;
                contactDao.updateEntity(con);
                System.debug('Contact updated ' + con);
            } else {
                con = new Contact();
                con.LastName = (String) data.get('LastName');
                con.FirstName = (String) data.get('FirstName');
                con.Email = (String) data.get('Email');
                con.Phone = (String) data.get('Phone');
                con.AccountId = acc.Id;
                con.External_id__c = externalId;
                contactDao.save(con);
                System.debug('Contact inserted ' + con);
            }

            List<Case> caseList = [SELECT Id, AccountId, ContactId FROM Case WHERE Id = :caseId LIMIT 1];
            if (!caseList.isEmpty()) {
                Case c = caseList[0];
                c.AccountId = acc.Id;
                c.ContactId = con.Id;
                update c;
                System.debug('Updated Case: ' + c);
            } else {
                System.debug('No Case found with Id: ' + caseId);
            }
        } catch (Exception e) {
            System.debug('Error in upsertAccountAndContact: ' + e.getMessage());
            // Consider throwing a custom exception here to handle data processing failures.
        }
    }
}