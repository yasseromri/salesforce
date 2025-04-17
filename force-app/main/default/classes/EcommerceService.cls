public with sharing class EcommerceService implements ICustomerService {
    private static final String AUTH_URL = 'https://login.salesforce.com/services/oauth2/token';
    private static final String ENDPOINT_QUERY = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com/services/data/v63.0/query';
    private static final String ENDPOINT_SOBJECT = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com/services/data/v47.0/sobjects/Account/';

    

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
        String query = 'SELECT+Id+FROM+Account+WHERE+PersonEmail=\'' + EncodingUtil.urlEncode(email, 'UTF-8') + '\'';
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
            String externalId = (String) data.get('Id');
            // Consider renaming existingContacts to existingAccounts for clarity
            List<Account> existingAccounts = [SELECT Id, External_id__c, PersonContactId // Query PersonContactId if needed
                                              FROM Account
                                              WHERE External_id__c = :externalId LIMIT 1];
            Account acc; // Renamed 'con' to 'acc' for clarity (represents Account)
            if (!existingAccounts.isEmpty()) {
                acc = existingAccounts[0];
                // Assuming Person Accounts: Update Person Account fields
                // Note: You cannot directly set LastName/FirstName on existing Person Accounts via Apex DML easily after creation.
                // You might need to update the associated Contact record if those fields need changing.
                // For simplicity here, we'll focus on email/phone which are usually updatable.
                acc.PersonEmail = (String) data.get('PersonEmail'); // Use PersonEmail for Person Accounts
                acc.Phone = (String) data.get('Phone');
                // Add other Account fields as needed

                update acc;
                System.debug('Person Account updated ' + acc);
            } else {
                acc = new Account();
                // Set required fields for Person Account creation (RecordTypeId might be needed depending on org setup)
                // You MUST set LastName for Account creation, even for Person Accounts
                acc.LastName = (String) data.get('LastName');
                acc.FirstName = (String) data.get('FirstName'); // Required for Person Account creation
                acc.PersonEmail = (String) data.get('PersonEmail');
                acc.Phone = (String) data.get('Phone');
                acc.External_id__c = externalId;
                 // Add other Account fields as needed

                insert acc;
                System.debug('Person Account inserted ' + acc);
            }

            // Now update the Case
            List<Case> caseList = [SELECT Id, AccountId, ContactId FROM Case WHERE Id = :caseId LIMIT 1];
            if (!caseList.isEmpty()) {
                Case c = caseList[0];

                // *** FIX: Assign the Account ID to the Case.AccountId field ***
                c.AccountId = acc.Id;

                // Optional: If you also want to link the Contact associated with the Person Account
                // You might need to query the PersonContactId if it wasn't included in the initial query
                 Account updatedAcc = [SELECT Id FROM Account WHERE Id = :acc.Id];
                 if (updatedAcc.PersonContactId != null) {
                    c.ContactId = updatedAcc.PersonContactId;
                 }
                // OR if you queried it earlier:
                // if (acc.PersonContactId != null) {
                //     c.ContactId = acc.PersonContactId;
                // }


                update c;
                System.debug('Updated Case: ' + c);
            } else {
                System.debug('No Case found with Id: ' + caseId);
            }
        } catch (Exception e) {
            // Log the full stack trace for better debugging
            System.debug('Error in upsertAccountAndContact: ' + e.getMessage() + '\nStackTrace: ' + e.getStackTraceString());
            // Consider throwing a custom exception here to handle data processing failures.
        }
    }
}