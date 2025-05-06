public with sharing class omri {
    
    private static final String AUTH_URL ='https://login.salesforce.com/services/oauth2/token';
    private static final String EXTERNAL_INSTANCE_URL = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com';
    private static final String API_VERSION = 'v63.0';
    private static final String ACCOUNT_ENDPOINT = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/sobjects/Account/';
    private static final String CONTACT_ENDPOINT = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/sobjects/Contact/';
    private static final String PRODUCT_ENDPOINT = EXTERNAL_INSTANCE_URL + '/services/data/v62.0/sobjects/Product2/';

    public enum RefundStatus {
        NoRefund,
        Refund,
        HalfRefund,
        Exchange
    }

    public Boolean refund_status(String externalOrderId, String refundStatus) {
        if (String.isBlank(externalOrderId)) {
            System.debug('refund_status: externalOrderId is blank.');
            return false;
        }
        if (String.isBlank(refundStatus)) {
            System.debug('refund_status: refundStatus is blank.');
            return false;
        }

        // Use the input refundStatus string directly, unless overridden by date logic.
        String statusToSend = refundStatus;
        
        String accessToken = authenticate();
        if (accessToken == null) {
            System.debug('refund_status: Authentication failed.');
            return false;
        }

        String orderJson = getExternalRecordJsonById(EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/sobjects/Order/', externalOrderId, accessToken);
        if (String.isBlank(orderJson)) {
            System.debug('refund_status: Failed to fetch order JSON for Id: ' + externalOrderId);
            return false;
        }

        Map<String, Object> orderData;
        try {
            orderData = (Map<String, Object>) JSON.deserializeUntyped(orderJson);
        } catch (Exception e) {
            System.debug('refund_status: Failed to deserialize order JSON: ' + e.getMessage());
            return false;
        }

        if (!orderData.containsKey('EffectiveDate') || orderData.get('EffectiveDate') == null) {
            System.debug('refund_status: Order JSON missing EffectiveDate.');
            return false;
        }

        String effectiveDateStr = (String) orderData.get('EffectiveDate');
        Date effectiveDate;
        try {
            effectiveDate = Date.valueOf(effectiveDateStr);
        } catch (Exception e) {
            System.debug('refund_status: Failed to parse EffectiveDate: ' + effectiveDateStr);
            return false;
        }

        Date twoMonthsAgo = Date.today().addMonths(-2);
        if (effectiveDate <= twoMonthsAgo) {
            statusToSend = omri.RefundStatus.NoRefund.name(); // Override to "NoRefund"
        }

        // Prepare PATCH request to update Refund_Status__c field
        Map<String, Object> updateFields = new Map<String, Object>();
        updateFields.put('Refund_Status__c', statusToSend);

        String patchEndpoint = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/sobjects/Order/' + externalOrderId;
        HttpRequest req = new HttpRequest();
        req.setEndpoint(patchEndpoint);
        req.setMethod('PATCH');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(updateFields));

        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
        } catch (System.CalloutException ce) {
            System.debug('refund_status: Callout failed: ' + ce.getMessage());
            return false;
        }

        if (res.getStatusCode() == 204) {
            System.debug('refund_status: Successfully updated Refund_Status__c to ' + statusToSend + ' for order ' + externalOrderId);
            return true;
        } else {
            System.debug('refund_status: Failed to update Refund_Status__c. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
            return false;
        }
    }

    public void getOrdersByEmailFromExternal(String email) {
        if (String.isBlank(email)) {
            System.debug('Email parameter is blank. Aborting getOrdersByEmailFromExternal.');
            return;
        }
        String accessToken = authenticate();
        if (accessToken == null) {
            System.debug('Authentication failed. Aborting getOrdersByEmailFromExternal.');
            return;
        }
        String soql = 'SELECT Id, AccountId FROM Order WHERE Account.PersonEmail = \''
            + String.escapeSingleQuotes(email) + '\'';
        String encodedQuery = EncodingUtil.urlEncode(soql, 'UTF-8');
        String queryEndpoint = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/query?q=' + encodedQuery;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(queryEndpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
        } catch (System.CalloutException ce) {
            System.debug('Callout failed in getOrdersByEmailFromExternal: ' + ce.getMessage());
            return;
        }

        if (res.getStatusCode() == 200) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) jsonResponse.get('records');
            if (records == null || records.isEmpty()) {
                System.debug('No orders found in external org for email: ' + email);
                return;
            }
            for (Object rec : records) {
                Map<String, Object> orderRecord = (Map<String, Object>) rec;
                String externalOrderId = (String) orderRecord.get('Id');
                String externalAccountId = (String) orderRecord.get('AccountId');
                if (externalOrderId != null && externalAccountId != null) {
                    System.debug('Order ID: ' + externalOrderId + ', Account ID: ' + externalAccountId);
                    // Fetch and print order details without saving locally
                    printExternalOrderDetails(externalOrderId, accessToken);
                    // Fetch and log account data
                    String accountJson = getExternalRecordJsonById(ACCOUNT_ENDPOINT, externalAccountId, accessToken);
                    System.debug('Account Data JSON for AccountId ' + externalAccountId + ': ' + accountJson);
                    // Fetch and log contact data related to account (assuming contact Id is available)
                    // For demonstration, fetch contacts by querying external org with AccountId
                    String contactQuery = 'SELECT Id FROM Contact WHERE AccountId = \'' + String.escapeSingleQuotes(externalAccountId) + '\' LIMIT 1';
                    String encodedContactQuery = EncodingUtil.urlEncode(contactQuery, 'UTF-8');
                    String contactQueryEndpoint = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/query?q=' + encodedContactQuery;
                    HttpRequest contactReq = new HttpRequest();
                    contactReq.setEndpoint(contactQueryEndpoint);
                    contactReq.setMethod('GET');
                    contactReq.setHeader('Authorization', 'Bearer ' + accessToken);
                    contactReq.setHeader('Content-Type', 'application/json');
                    Http contactHttp = new Http();
                    try {
                        HttpResponse contactRes = contactHttp.send(contactReq);
                        if (contactRes.getStatusCode() == 200) {
                            Map<String, Object> contactResponse = (Map<String, Object>) JSON.deserializeUntyped(contactRes.getBody());
                            List<Object> contactRecords = (List<Object>) contactResponse.get('records');
                            if (contactRecords != null && !contactRecords.isEmpty()) {
                                Map<String, Object> contactRecord = (Map<String, Object>) contactRecords[0];
                                String contactId = (String) contactRecord.get('Id');
                                String contactJson = getExternalRecordJsonById(CONTACT_ENDPOINT, contactId, accessToken);
                                System.debug('Contact Data JSON for ContactId ' + contactId + ': ' + contactJson);
                            } else {
                                System.debug('No contacts found for AccountId ' + externalAccountId);
                            }
                        } else {
                            System.debug('Failed to query contacts for AccountId ' + externalAccountId + '. Status: ' + contactRes.getStatusCode());
                        }
                    } catch (Exception e) {
                        System.debug('Exception while fetching contact data: ' + e.getMessage());
                    }
                } else {
                    System.debug('Skipping order with missing externalOrderId or externalAccountId.');
                }
            }
        } else {
            System.debug('Failed to query external orders. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
        }
    }

    private void printExternalOrderDetails(String externalOrderId, String accessToken) {
        String orderJson = getExternalRecordJsonById(EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/sobjects/Order/', externalOrderId, accessToken);
        System.debug('Order Details JSON: ' + orderJson);

        String orderItemsJson = getExternalOrderItemsJson(externalOrderId, accessToken);
        System.debug('Order Items JSON: ' + orderItemsJson);

        if (String.isNotBlank(orderItemsJson)) {
            try {
                List<Object> orderItems = (List<Object>) JSON.deserializeUntyped(orderItemsJson);
                for (Object item : orderItems) {
                    System.debug('Order Item: ' + JSON.serialize(item));
                    // Fetch and log product details for each product in order items
                    Map<String, Object> itemMap = (Map<String, Object>) item;
                    if(itemMap.containsKey('Product2Id') && itemMap.get('Product2Id') != null){
                        String productId = (String) itemMap.get('Product2Id');
                        String productJson = getExternalRecordJsonById(PRODUCT_ENDPOINT, productId, accessToken);
                        System.debug('Product Details JSON for Product2Id ' + productId + ': ' + productJson);
                    }
                }
            } catch (Exception e) {
                System.debug('Failed to deserialize order items JSON: ' + e.getMessage());
            }
        }
    }

    public Map<Id, Boolean> updateExternalOrderItems(List<OrderItem> localItemsToUpdate) {
        System.debug('Starting updateExternalOrderItems with ' + (localItemsToUpdate != null ? localItemsToUpdate.size() : 0) + ' items.');
        Map<Id, Boolean> resultsMap = new Map<Id, Boolean>();
        if (localItemsToUpdate == null || localItemsToUpdate.isEmpty()) {
            System.debug('updateExternalOrderItems: No items provided to update.');
            return resultsMap; // Return empty map
        }
        String accessToken = authenticate();
        if (String.isBlank(accessToken)) {
            System.debug('updateExternalOrderItems: Authentication failed or access token is blank.');
            // Mark all as failed
            for(OrderItem item : localItemsToUpdate) {
                resultsMap.put(item.Id, false);
            }
            return resultsMap;
        }
    
        List<OrderItemUpdateDTO> recordsPayload = new List<OrderItemUpdateDTO>();
        Map<String, Id> externalToLocalIdMap = new Map<String, Id>(); // Helper to map results back
    
        for (OrderItem item : localItemsToUpdate) {
            if (String.isNotBlank(item.External_Id__c)) {
                OrderItemUpdateDTO dto = new OrderItemUpdateDTO();
                dto.attributes = new AttributesDTO('OrderItem');
                dto.Id = item.External_Id__c;
                dto.Quantity = item.Quantity;
                dto.UnitPrice = item.UnitPrice;
                recordsPayload.add(dto);
                externalToLocalIdMap.put(item.External_Id__c, item.Id);
                resultsMap.put(item.Id, false); // Default to false, update on success
            } else {
                System.debug('updateExternalOrderItems: Skipping item with blank External_Id__c: ' + item.Id);
                resultsMap.put(item.Id, false); // Mark as failed if External_Id__c is missing
            }
        }
    
        if (recordsPayload.isEmpty()) {
            System.debug('updateExternalOrderItems: No valid items found to update after filtering.');
            return resultsMap; // Return map with all items marked as false (or skipped)
        }
    
        // Construct the request for the Collections API
        String endpoint = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/composite/sobjects';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('PATCH'); // Use PATCH for updates
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
    
        // Set 'allOrNone' to false to allow partial success
        CompositeRequestDTO compositeRequest = new CompositeRequestDTO(false, recordsPayload);
        String requestBody = JSON.serialize(compositeRequest);
        System.debug('updateExternalOrderItems: Request body: ' + requestBody);
        req.setBody(requestBody);
    
        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            System.debug('updateExternalOrderItems: Response status: ' + res.getStatusCode());
            System.debug('updateExternalOrderItems: Response body: ' + res.getBody());
    
            // Status 200 indicates the request was processed (check individual results)
            if (res.getStatusCode() == 200) {
                List<OrderItemUpdateResultDTO> results = (List<OrderItemUpdateResultDTO>) JSON.deserialize(res.getBody(), List<OrderItemUpdateResultDTO>.class);
                for (OrderItemUpdateResultDTO itemResult : results) {
                    String externalId = itemResult.id;
                    Boolean success = itemResult.success;
    
                    if (externalToLocalIdMap.containsKey(externalId)) {
                        Id localId = externalToLocalIdMap.get(externalId);
                        resultsMap.put(localId, success); // Update the map with actual success status
                        if (!success) {
                            System.debug('Failed to update external OrderItem (External ID: ' + externalId + ', Local ID: ' + localId + '). Errors: ' + JSON.serialize(itemResult.errors));
                        } else {
                            System.debug('Successfully updated external OrderItem (External ID: ' + externalId + ', Local ID: ' + localId + ').');
                        }
                    }
                }
            } else {
                // Request itself failed (e.g., 400, 401, 500) - mark all attempted items as failed
                System.debug('Failed to update external OrderItems via Collections API. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
                // The resultsMap already defaults to false for all items included in the payload
            }
        } catch (Exception e) {
            System.debug('Exception during updateExternalOrderItems callout: ' + e.getMessage());
            // The resultsMap already defaults to false for all items included in the payload
        }
    
        return resultsMap;
    }
    
    public class AttributesDTO {
        public String type;
        public AttributesDTO(String type) {
            this.type = type;
        }
    }
    
    public class OrderItemUpdateDTO {
        public AttributesDTO attributes;
        public String Id;
        public Decimal Quantity;
        public Decimal UnitPrice;
    }
    
    public class OrderItemUpdateResultDTO {
        public String id;
        public Boolean success;
        public List<Object> errors;
    }
    
    public class CompositeRequestDTO {
        public Boolean allOrNone;
        public List<OrderItemUpdateDTO> records;
        public CompositeRequestDTO(Boolean allOrNone, List<OrderItemUpdateDTO> records) {
            this.allOrNone = allOrNone;
            this.records = records;
        }
    }

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

    private String getExternalRecordJsonById(String endpointBase, String recordId, String accessToken) {
        if(String.isBlank(recordId) || String.isBlank(accessToken)){
            System.debug('Missing recordId or accessToken for getExternalRecordJsonById call.');
            return null;
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpointBase + recordId);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');
        Http http = new Http();
        HttpResponse res = null;
        try {
            res = http.send(req);
        } catch (System.CalloutException ce) {
            System.debug('Get Record Details callout failed for endpoint ' + endpointBase + ' Id ' + recordId + ': ' + ce.getMessage());
            return null;
        }
        if (res != null && res.getStatusCode() == 200) {
            return res.getBody();
        } else {
            System.debug('External record detail fetch failed for endpoint ' + endpointBase + ' Id ' + recordId + '. Status: ' + (res != null ? String.valueOf(res.getStatusCode()) : 'No Response') + ' Body: ' + (res != null ? res.getBody() : 'N/A'));
            return null;
        }
    }

    private String getExternalOrderItemsJson(String externalOrderId, String accessToken) {
        if(String.isBlank(externalOrderId) || String.isBlank(accessToken)){
            System.debug('Missing externalOrderId or accessToken for getExternalOrderItemsJson call.');
            return null;
        }
        String query = 'SELECT Id, OrderId, Product2Id, Quantity, UnitPrice FROM OrderItem WHERE OrderId = \'' + String.escapeSingleQuotes(externalOrderId) + '\'';
        String encodedQuery = EncodingUtil.urlEncode(query, 'UTF-8');
        String queryEndpoint = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/query?q=' + encodedQuery;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(queryEndpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
        } catch (System.CalloutException ce) {
            System.debug('Callout failed in getExternalOrderItemsJson: ' + ce.getMessage());
            return null;
        }

        if (res.getStatusCode() == 200) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) jsonResponse.get('records');
            if (records == null || records.isEmpty()) {
                System.debug('No order items found in external org for order ID: ' + externalOrderId);
                return null;
            }
            return JSON.serialize(records);
        } else {
            System.debug('Failed to query external order items. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
            return null;
        }
    }

    private Account ensureLocalAccount(String externalAccountId, String accessToken) {
        if(String.isBlank(externalAccountId)){
            System.debug('External Account ID is blank in ensureLocalAccount.');
            return null;
        }
        System.debug('Fetching external account data for ID: ' + externalAccountId);
        if(String.isBlank(accessToken)){
            System.debug('Access token is missing, cannot fetch external account.');
            return null;
        }
        String accountJson = getExternalRecordJsonById(ACCOUNT_ENDPOINT, externalAccountId, accessToken);
        if(String.isNotBlank(accountJson)){
            System.debug('External Account JSON: ' + accountJson);
            try{
                Map<String, Object> externalAccountData = (Map<String, Object>) JSON.deserializeUntyped(accountJson);
                if (externalAccountData != null) {
                    System.debug('External Account Data: ' + externalAccountData);
                    // Optionally, you can log specific fields here
                    return null; // Not saving locally anymore
                } else {
                    System.debug('Deserialized external account data is null for ID: ' + externalAccountId);
                    return null;
                }
            } catch(Exception e){
                System.debug('Failed to deserialize external account data for ID: ' + externalAccountId + '. Error: ' + e.getMessage());
                return null;
            }
        } else {
            System.debug('Failed to fetch external account data for ID: ' + externalAccountId);
            return null;
        }
    }
}