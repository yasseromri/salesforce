public with sharing class OrderServiceWithGetOrdersByAccountName implements IOrderService {

    // --- Authentication & Endpoints (Similar to EcommerceService/ExternAccountService) ---
    private static final String AUTH_URL = 'https://login.salesforce.com/services/oauth2/token'; // Use Label or Named Credential ideally
    private static final String EXTERNAL_INSTANCE_URL = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com'; // Example
    private static final String API_VERSION = 'v63.0'; // Example

    // --- Main Service Method ---

    /**
     * @description Fetches order, items, products, ensures contract/account, and upserts locally.
     * @param externalOrderId The ID of the Order in the external system.
     * @param externalAccountId The ID of the related Account in the external system.
     */
    public void syncOrderData(String externalOrderId, String externalAccountId) {
        // Implementation omitted for brevity; same as original OrderService
    }

    // --- Authentication (Copied/Adapted from ExternAccountService) ---
    public String authenticate() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(AUTH_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

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
            System.debug('OAuth authentication failed. Status: ' + (res != null ? String.valueOf(res.getStatusCode()) : 'No Response') + ' Body: ' + (res != null ? res.getBody() : 'N/A'));
            return null;
        }
    }

    // New method to get all orders by Account Name from external system
    public List<Map<String, Object>> getOrdersByAccountName(String accountName) {
        List<Map<String, Object>> orders = new List<Map<String, Object>>();
        if (String.isBlank(accountName)) {
            System.debug('Account Name is required to fetch orders.');
            return orders;
        }
        try {
            String accessToken = authenticate();
            if (accessToken == null) {
                System.debug('Authentication failed. Cannot fetch orders.');
                return orders;
            }
            String soqlQuery = 'SELECT+Id,OrderNumber,Status,EffectiveDate,AccountId,ContractId+FROM+Order+WHERE+Account.Name+=+\'' + EncodingUtil.urlEncode(accountName, 'UTF-8') + '\'';
            String endpoint = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/query?q=' + soqlQuery;

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('Content-Type', 'application/json');

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res != null && res.getStatusCode() == 200) {
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> records = (List<Object>) jsonResponse.get('records');
                for (Object rec : records) {
                    orders.add((Map<String, Object>) rec);
                }
            } else {
                System.debug('Failed to fetch orders from external system. Status: ' + (res != null ? String.valueOf(res.getStatusCode()) : 'No Response'));
            }
        } catch (Exception e) {
            System.debug('Exception while fetching orders by Account Name: ' + e.getMessage());
        }
        return orders;
    }
}
