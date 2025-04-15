public class ExternAccountService {

    // Re-use authentication URL
    private static final String AUTH_URL = 'https://login.salesforce.com/services/oauth2/token';
    // Re-use query endpoint URL
    private static final String QUERY_ENDPOINT = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com/services/data/v63.0/query';
    // Define the Account SObject endpoint URL for the external org
    private static final String ACCOUNT_ENDPOINT = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com/services/data/v63.0/sobjects/Account/';

    /**
     * Main method to synchronize an Account based on its AccountNumber in the external org.
     * @param externalAccountNumber The AccountNumber of the account in the external org.
     */
    public void syncAccountByAccountNumber(String externalAccountNumber) {
        if (String.isBlank(externalAccountNumber)) {
            System.debug('External Account Number cannot be blank.');
            return;
        }
        try {
            String accessToken = authenticate();
            if (accessToken != null) {
                // 1. Query the external org to find the Account Id based on AccountNumber
                String accountId = queryAccountIdByname(externalAccountNumber, accessToken);
                if (accountId != null) {
                    // 2. Get the full details of the external Account using its Id
                    Map<String, Object> accountData = getAccountDetails(accountId, accessToken);
                    if (accountData != null) {
                        // 3. Upsert the Account data into the local org
                        upsertAccount(accountData);
                    } else {
                        System.debug('No account data found for external Id: ' + accountId);
                    }
                } else {
                    System.debug('No external account found for AccountNumber = ' + externalAccountNumber);
                }
            }
        } catch (Exception e) {
            System.debug('Error in syncAccountByAccountNumber: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            // Consider more robust error logging/handling here
        }
    }

    /**
     * Authenticates with the external Salesforce org using OAuth Password Flow.
     * Retrieves credentials from Custom Labels.
     * @return Access Token string or null if authentication fails.
     */
    public String authenticate() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(AUTH_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        // Ensure Custom Labels are configured: OAuth_Client_ID, OAuth_Client_Secret, OAuth_Username, OAuth_Password
        try {
             req.setBody(
                'grant_type=password' +
                '&client_id=' + EncodingUtil.urlEncode(System.Label.OAuth_Client_ID, 'UTF-8') +
                '&client_secret=' + EncodingUtil.urlEncode(System.Label.OAuth_Client_Secret, 'UTF-8') +
                '&username=' + EncodingUtil.urlEncode(System.Label.OAuth_Username, 'UTF-8') +
                '&password=' + EncodingUtil.urlEncode(System.Label.OAuth_Password, 'UTF-8')
            );
        } catch (Exception e) {
             System.debug('OAuth Custom Label Error: ' + e.getMessage() + '. Please ensure OAuth labels are configured.');
             return null;
        }


        Http http = new Http();
        HttpResponse res = null;
        try {
            res = http.send(req);
        } catch (System.CalloutException ce) {
            System.debug('Authentication callout failed: ' + ce.getMessage());
            return null;
        }


        if (res != null && res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('access_token');
        } else {
            System.debug('OAuth authentication failed. No Response');
            return null;
        }
    }

    /**
     * Queries the external Salesforce org to find an Account's Id based on its AccountNumber.
     * @param accountNumber The AccountNumber to search for.
     * @param accessToken The OAuth access token for the external org.
     * @return The Salesforce Id of the found Account in the external org, or null if not found or error occurs.
     */
    public String queryAccountIdByname(String name, String accessToken) {
        // Construct the SOQL query, ensuring the accountNumber is properly encoded for the URL
        String soql = 'SELECT+Id+FROM+Account+WHERE+Name=\'' + EncodingUtil.urlEncode(name, 'UTF-8') + '\'+LIMIT+1';
        String endpoint = QUERY_ENDPOINT + '?q=' + soql;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res = null;

        try {
             res = http.send(req);
        } catch (System.CalloutException ce) {
             System.debug('Account query callout failed: ' + ce.getMessage());
             return null;
        }


        if (res != null && res.getStatusCode() == 200) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) jsonResponse.get('records');
            if (records != null && !records.isEmpty()) {
                Map<String, Object> firstRecord = (Map<String, Object>) records[0];
                return (String) firstRecord.get('Id');
            } else {
                 System.debug('No Account found in external org with name: ' + name);
                 return null;
            }
        } else {
            System.debug('External Account query failed. Status Code: ');
            return null;
        }
    }

    /**
     * Retrieves the full details of an Account from the external org using its Salesforce Id.
     * @param accountId The Salesforce Id of the Account in the external org.
     * @param accessToken The OAuth access token.
     * @return A Map representing the Account data, or null if fetch fails.
     */
    public Map<String, Object> getAccountDetails(String accountId, String accessToken) {
        HttpRequest req = new HttpRequest();
        // Use the specific Account SObject endpoint
        req.setEndpoint(ACCOUNT_ENDPOINT + accountId);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res = null;
        try {
             res = http.send(req);
        } catch (System.CalloutException ce) {
             System.debug('Get Account Details callout failed for Id ' + accountId + ': ' + ce.getMessage());
             return null;
        }


        if (res != null && res.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            System.debug('External Account detail fetch failed for Id ' + accountId + '. Status Code: ' );
            return null;
        }
    }

    /**
     * Upserts an Account record in the local Salesforce org based on data fetched from the external org.
     * Assumes a local custom field 'External_Account_Id__c' (Text) exists to store the external Account's Id.
     * @param data A Map containing the Account data fetched from the external org.
     */
    public void upsertAccount(Map<String, Object> data) {
        // Extract the external Account's Salesforce Id. This will be used as the external Id key.
        String externalAccountId = (String) data.get('Id');

        if (String.isBlank(externalAccountId)) {
            System.debug('External Account data is missing the Id field. Cannot upsert.');
            return;
        }

        // *** IMPORTANT: Ensure you have a custom field (e.g., External_Account_Id__c, Text(18), External ID, Unique)
        // on your local Account object to store the externalAccountId ***
        Schema.SObjectField externalIdField = Account.SObjectType.getDescribe().fields.getMap().get('External_Id__c');
        if(externalIdField == null){
            System.debug('Error: The custom field External_Account_Id__c does not exist on the local Account object. Cannot perform upsert.');
            // Optionally throw an exception here
            // throw new SyncException('Required field External_Account_Id__c is missing on Account.');
            return;
        }

        try {
            // Query for an existing local Account using the external Id field
            List<Account> existingAccounts = [SELECT Id FROM Account WHERE External_Id__c = :externalAccountId LIMIT 1];

            Account accToUpsert = new Account();

            if (!existingAccounts.isEmpty()) {
                // Record exists, prepare for update
                accToUpsert.Id = existingAccounts[0].Id;
                System.debug('Found existing local Account to update with Id: ' + accToUpsert.Id);
            } else {
                // Record does not exist, prepare for insert
                // Set the external Id field ONLY on insert
                 accToUpsert.put(externalIdField, externalAccountId);
                 System.debug('Preparing to insert new local Account linked to external Id: ' + externalAccountId);
            }

            // Map fields from the external data map to the local Account record
            // Add/remove fields as needed based on your requirements
            accToUpsert.Name = (String) data.get('Name');
            accToUpsert.AccountNumber = (String) data.get('AccountNumber'); // Keep local AccountNumber in sync?
            accToUpsert.Phone = (String) data.get('Phone');
            accToUpsert.Website = (String) data.get('Website');
            accToUpsert.BillingStreet = (String) data.get('BillingStreet');
            accToUpsert.BillingCity = (String) data.get('BillingCity');
            accToUpsert.BillingState = (String) data.get('BillingState');
            accToUpsert.BillingPostalCode = (String) data.get('BillingPostalCode');
            accToUpsert.BillingCountry = (String) data.get('BillingCountry');
            // Add other fields like Shipping Address, Type, Industry etc. as needed

            // Perform the DML operation (Insert or Update)
            Database.UpsertResult upsertResult = Database.upsert(accToUpsert, externalIdField, false); // Use the custom external ID field

            if (upsertResult.isSuccess()) {
                 if(upsertResult.isCreated()){
                      System.debug('Successfully inserted new Account with Id: ' + upsertResult.getId());
                 } else {
                      System.debug('Successfully updated existing Account with Id: ' + upsertResult.getId());
                 }
            } else {
                System.debug('Upsert failed for external Account Id: ' + externalAccountId);
                for (Database.Error err : upsertResult.getErrors()) {
                    System.debug('Error: ' + err.getStatusCode() + ': ' + err.getMessage() + ' Fields: ' + String.join(err.getFields(), ', '));
                }
            }

        } catch (Exception e) {
            System.debug('Error during upsertAccount for external Id ' + externalAccountId + ': ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
            // Consider more robust error logging/handling
        }
    }
}