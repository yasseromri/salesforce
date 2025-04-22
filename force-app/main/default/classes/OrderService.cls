public with sharing class OrderService implements IOrderService {

    
    private static final String AUTH_URL = 'https://login.salesforce.com/services/oauth2/token';
    private static final String EXTERNAL_INSTANCE_URL = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com'; 
    private static final String API_VERSION = 'v63.0'; 
    private static final String ORDER_ENDPOINT = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/sobjects/Order/';
    private static final String ORDER_ITEM_QUERY_ENDPOINT = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/query?q=SELECT+Id,OrderId,Product2Id,Quantity,UnitPrice+FROM+OrderItem+WHERE+OrderId='; // Example Query
    private static final String PRODUCT_ENDPOINT = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/sobjects/Product2/';
    private static final String ACCOUNT_ENDPOINT = EXTERNAL_INSTANCE_URL + '/services/data/' + API_VERSION + '/sobjects/Account/';
    /**
     * @description Fetches order, items, products, ensures contract/account, and upserts locally.
     * @param externalOrderId The ID of the Order in the external system.
     * @param externalAccountId The ID of the related Account in the external system.
     */
    public void syncOrderData(String externalOrderId, String externalAccountId) {
        if (String.isBlank(externalOrderId) || String.isBlank(externalAccountId)) {
            System.debug('External Order ID and External Account ID are required.');
            return; 
        }

        try {
            String accessToken = authenticate();
            if (accessToken == null) {
                System.debug('Authentication failed. Aborting sync for Order: ' + externalOrderId);
                return;
            }

            // 1. Get External Order Header Data
            Map<String, Object> externalOrderData = getExternalRecordById(ORDER_ENDPOINT, externalOrderId, accessToken);
            if (externalOrderData == null) {
                System.debug('Failed to fetch external order details for ID: ' + externalOrderId);
                return;
            }
             // Extract necessary fields like OrderNumber, Status, OrderStartDate etc. from externalOrderData
            List<Map<String, Object>> externalOrderItems = getExternalOrderItems(externalOrderId, accessToken);
            if (externalOrderItems == null || externalOrderItems.isEmpty()) {
                System.debug('No order items found or failed to fetch items for external order ID: ' + externalOrderId);
                return;
            }

            // 3. Get Unique External Product IDs from Items
            Set<String> externalProductIds = new Set<String>();
            for (Map<String, Object> item : externalOrderItems) {
                String prodId = (String) item.get('Product2Id'); 
                if (String.isNotBlank(prodId)) {
                    externalProductIds.add(prodId);
                }
            }

            // 4. Get External Product Details
            Map<String, Map<String, Object>> externalProductDataMap = new Map<String, Map<String, Object>>();
            for (String prodId : externalProductIds) {
                Map<String, Object> productData = getExternalRecordById(PRODUCT_ENDPOINT, prodId, accessToken);
                if (productData != null) {
                    externalProductDataMap.put(prodId, productData);
                } else {
                    System.debug('Warning: Failed to fetch details for external product ID: ' + prodId);
                }
            }

            // --- Now Handle Local Data Upsert ---

            // 5. Ensure Local Account Exists (using External ID)
            Account localAccount = ensureLocalAccount(externalAccountId, accessToken);
            if (localAccount == null || localAccount.Id == null) {
                System.debug('Failed to find or create local Account for external ID: ' + externalAccountId + '. Aborting order sync.');
                return;
            }

            // 6. Ensure Dummy Contract Exists (linked to Account)
            Contract localContract = ensureDummyContract(localAccount.Id, externalOrderId); // Use externalOrderId for uniqueness?
            if (localContract == null || localContract.Id == null) {
                System.debug('Failed to create dummy Contract for Account: ' + localAccount.Id + '. Aborting order sync.');
                return; // Or proceed without contract if acceptable
            }

            // 7. Upsert Products and PricebookEntries Locally
            Map<String, Id> localProductIdMap = upsertProductsAndGetIds(externalProductDataMap);
            Map<String, Id> localPricebookEntryIdMap = ensurePricebookEntries(localProductIdMap);


            // 8. Upsert Order and Order Items Locally
            upsertOrderAndItems(
                externalOrderData,
                externalOrderItems,
                localAccount.Id,
                localContract.Id,
                localProductIdMap,
                localPricebookEntryIdMap
            );

            System.debug('Successfully synced data for external order ID: ' + externalOrderId);

        } catch (Exception e) {
            System.debug('Error during syncOrderData for external Order ID ' + externalOrderId + ': ' + e.getMessage() + '\nStackTrace: ' + e.getStackTraceString());
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

    // --- External Data Fetching Helpers ---

    /**
     * @description Generic method to fetch a single SObject record by ID from the external org.
     */
    private Map<String, Object> getExternalRecordById(String endpointBase, String recordId, String accessToken) {
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
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            System.debug('External record detail fetch failed for endpoint ' + endpointBase + ' Id ' + recordId + '. Status: ' + (res != null ? String.valueOf(res.getStatusCode()) : 'No Response') + ' Body: ' + (res != null ? res.getBody() : 'N/A'));
            return null;
        }
    }

    /**
     * @description Fetches OrderItems related to a specific Order ID from the external org.
     */
    private List<Map<String, Object>> getExternalOrderItems(String externalOrderId, String accessToken) {
        String query = EncodingUtil.urlEncode('\'' + externalOrderId + '\'', 'UTF-8');
        String endpoint = ORDER_ITEM_QUERY_ENDPOINT + query;
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
             System.debug('Order Item query callout failed for Order ID ' + externalOrderId + ': ' + ce.getMessage());
             return null;
        }

        if (res != null && res.getStatusCode() == 200) {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (List<Map<String, Object>>) jsonResponse.get('records'); 
        } else {
            System.debug('External Order Item query failed for Order ID ' + externalOrderId + '. Status: ' + (res != null ? String.valueOf(res.getStatusCode()) : 'No Response') + ' Body: ' + (res != null ? res.getBody() : 'N/A'));
            return null;
        }
    }

    // --- Local Data Handling Helpers ---

    /**
     * @description Finds local account by external ID or fetches from external system and upserts.
     *              Reuses logic similar to ExternAccountService but simplified.
     */
    private Account ensureLocalAccount(String externalAccountId, String accessToken) {
        List<Account> existingAccounts = AccountSelector.selectByExternalId(externalAccountId);
        if (!existingAccounts.isEmpty()) {
            System.debug('Found existing local Account: ' + existingAccounts[0].Id);
            return existingAccounts[0];
        } else {
            System.debug('Local Account not found for external ID: ' + externalAccountId + '. Fetching from external org.');
            Map<String, Object> externalAccountData = getExternalRecordById(ACCOUNT_ENDPOINT, externalAccountId, accessToken);
            if (externalAccountData != null) {
                // Use a dedicated method or class (like ExternAccountService.upsertAccount)
                // For simplicity here, we do a basic insert/update
                return upsertLocalAccount(externalAccountData);
            } else {
                System.debug('Failed to fetch external account data for ID: ' + externalAccountId);
                return null;
            }
        }
    }
    

     /**
     * @description Basic upsert logic for Account based on External_Id__c.
     *              Consider reusing ExternAccountService.upsertAccount for robustness.
     */
    private Account upsertLocalAccount(Map<String, Object> data) {
        String externalId = (String) data.get('Id');
        if (String.isBlank(externalId)) return null;

        Schema.SObjectField externalIdField = Account.SObjectType.getDescribe().fields.getMap().get('External_Id__c');
         if(externalIdField == null){
            System.debug('Error: External_Id__c field missing on Account.');
            return null; 
        }

        List<Account> existing = [SELECT Id FROM Account WHERE External_Id__c = :externalId LIMIT 1];
        Account acc = !existing.isEmpty() ? new Account(Id = existing[0].Id) : new Account();

        // Map essential fields - ADD MORE AS NEEDED
        acc.Name = (String) data.get('Name'); // For Business Accounts
        acc.FirstName = (String) data.get('FirstName'); // For Person Accounts
        acc.LastName = (String) data.get('LastName'); // For Person Accounts (Required)
        acc.PersonEmail = (String) data.get('PersonEmail'); // For Person Accounts
        acc.Phone = (String) data.get('Phone');
        acc.External_Id__c = externalId; // Set on insert

        try {
            Database.UpsertResult result = Database.upsert(acc, externalIdField, false);
            if (result.isSuccess()) {
                System.debug((result.isCreated() ? 'Inserted' : 'Updated') + ' Account: ' + result.getId());
                // Query again to get all fields if needed, especially PersonContactId
                return [SELECT Id, Name, PersonContactId, External_Id__c FROM Account WHERE Id = :result.getId()];
            } else {
                System.debug('Account upsert failed for external ID ' + externalId + ': ' + result.getErrors()[0].getMessage());
                return null;
            }
        } catch (Exception e) {
            System.debug('Exception during Account upsert for external ID ' + externalId + ': ' + e.getMessage());
            return null;
        }
    }


    /**
     * @description Creates a dummy Contract linked to the Account if one doesn't exist.
     *              Uses a simple check based on AccountId and maybe Status/StartDate.
     *              Consider adding External_Id__c to Contract for proper syncing if needed.
     */
    private Contract ensureDummyContract(Id localAccountId, String externalOrderId) {
        // Simple check: Find an active contract created today for this account? Or use External ID?
        // Let's create a basic one linked to the account. Add External_Id__c if you want to sync contracts.
        List<Contract> existingContracts = [
            SELECT Id FROM Contract
            WHERE AccountId = :localAccountId
            AND Status = 'Draft' // Or a specific status for these dummy contracts
            // AND External_Id__c = :externalOrderId // Add this if syncing contracts by Order ID
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!existingContracts.isEmpty()) {
            System.debug('Found existing dummy Contract: ' + existingContracts[0].Id);
            return existingContracts[0];
        } else {
            System.debug('Creating new dummy Contract for Account: ' + localAccountId);
            Contract newContract = new Contract(
                AccountId = localAccountId,
                StartDate = Date.today(),
                Status = 'Draft', // Or 'Activated' if needed immediately
                ContractTerm = 12 // Default term in months
                // External_Id__c = externalOrderId // Set if using external ID
            );
            try {
                insert newContract;
                System.debug('Inserted new dummy Contract: ' + newContract.Id);
                return newContract;
            } catch (Exception e) {
                System.debug('Failed to insert dummy Contract: ' + e.getMessage());
                return null;
            }
        }
    }

    /**
     * @description Upserts Product2 records based on external data and returns a map of
     *              External Product ID -> Local Product2 ID.
     */
    private Map<String, Id> upsertProductsAndGetIds(Map<String, Map<String, Object>> externalProductDataMap) {
        Map<String, Id> localProductIds = new Map<String, Id>();
        List<Product2> productsToUpsert = new List<Product2>();
        Schema.SObjectField externalIdField = Product2.SObjectType.getDescribe().fields.getMap().get('External_Id__c');

        if(externalIdField == null){
            System.debug('Error: External_Id__c field missing on Product2.');
            return localProductIds; // Return empty map
        }

        // Query existing products first
        Set<String> externalIds = externalProductDataMap.keySet();
        Map<String, Id> existingProductMap = new Map<String, Id>();
        for(Product2 p : [SELECT Id, External_Id__c FROM Product2 WHERE External_Id__c IN :externalIds]) {
            existingProductMap.put(p.External_Id__c, p.Id);
            localProductIds.put(p.External_Id__c, p.Id); // Add existing to the final map
        }

        for (String extId : externalProductDataMap.keySet()) {
            Map<String, Object> data = externalProductDataMap.get(extId);
            Product2 prod = new Product2();
            if(existingProductMap.containsKey(extId)) {
                prod.Id = existingProductMap.get(extId); // Prepare for update
            } else {
                 prod.External_Id__c = extId; // Set external ID only on insert
            }

            // Map fields - ADD MORE AS NEEDED
            prod.Name = (String) data.get('Name');
            prod.ProductCode = (String) data.get('ProductCode');
            prod.Description = (String) data.get('Description');
            prod.IsActive = true; // Assume active unless specified otherwise

            productsToUpsert.add(prod);
        }

        if (!productsToUpsert.isEmpty()) {
            List<Database.UpsertResult> results = Database.upsert(productsToUpsert, externalIdField, false);
            for (Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult res = results[i];
                Product2 processedProd = productsToUpsert[i];
String externalId = processedProd.External_Id__c != null ? processedProd.External_Id__c :
                                    new List<String>(externalProductDataMap.keySet())[i]; // Fallback to get extId

                if (res.isSuccess()) {
                    localProductIds.put(externalId, res.getId()); // Add newly created/updated ID
                     System.debug((res.isCreated() ? 'Inserted' : 'Updated') + ' Product2: ' + res.getId() + ' for External ID: ' + externalId);
                } else {
                    System.debug('Product2 upsert failed for external ID ' + externalId + ': ' + res.getErrors()[0].getMessage());
                    // Decide if we should remove from localProductIds map?
                }
            }
        }
        return localProductIds;
    }
//ENA WSILIT HOUNI 
     /**
     * @description Ensures PricebookEntries exist for the given Product IDs in the standard pricebook.
     *              Returns map of External Product ID -> Local PricebookEntry ID.
     */
    private Map<String, Id> ensurePricebookEntries(Map<String, Id> localProductIdMap) {
        Map<String, Id> pbeIdMap = new Map<String, Id>();
        if (localProductIdMap == null || localProductIdMap.isEmpty()) {
            return pbeIdMap;
        }

        Id standardPricebookId = Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        if (standardPricebookId == null) {
            System.debug('Standard Pricebook ID not found. Cannot create PricebookEntries.');
            return pbeIdMap; // Cannot proceed
        }

        Set<Id> productIds = new Set<Id>(localProductIdMap.values());
        Map<Id, Id> productIdToPbeIdMap = new Map<Id, Id>();

        // Find existing PBEs
        for (PricebookEntry pbe : [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND Product2Id IN :productIds]) {
            productIdToPbeIdMap.put(pbe.Product2Id, pbe.Id);
        }

        List<PricebookEntry> pbesToInsert = new List<PricebookEntry>();
        for (String externalProdId : localProductIdMap.keySet()) {
             Id localProdId = localProductIdMap.get(externalProdId);
             if (productIdToPbeIdMap.containsKey(localProdId)) {
                 // PBE already exists, map it back to external ID
                 pbeIdMap.put(externalProdId, productIdToPbeIdMap.get(localProdId));
             } else {
                 // PBE needs to be created
                 PricebookEntry newPbe = new PricebookEntry(
                     Pricebook2Id = standardPricebookId,
                     Product2Id = localProdId,
                     UnitPrice = 1.00, // *** Default Price - GET PRICE FROM EXTERNAL DATA if available ***
                     IsActive = true
                 );
                 pbesToInsert.add(newPbe);
             }
        }

        if (!pbesToInsert.isEmpty()) {
            try {
                Database.SaveResult[] insertResults = Database.insert(pbesToInsert, false); // Allow partial success
                for(Integer i = 0; i < insertResults.size(); i++) {
                    Database.SaveResult sr = insertResults[i];
                    PricebookEntry insertedPbe = pbesToInsert[i];
                    // Find the corresponding external product ID
                    String externalProdId = null;
                    for(String extId : localProductIdMap.keySet()){
                        if(localProductIdMap.get(extId) == insertedPbe.Product2Id){
                            externalProdId = extId;
                            break;
                        }
                    }

                    if(sr.isSuccess() && externalProdId != null) {
                        pbeIdMap.put(externalProdId, sr.getId());
                        System.debug('Inserted PricebookEntry: ' + sr.getId() + ' for Product: ' + insertedPbe.Product2Id);
                    } else {
                         System.debug('Failed to insert PricebookEntry for Product ' + insertedPbe.Product2Id + ': ' + (sr.isSuccess() ? 'Could not map back to External ID' : sr.getErrors()[0].getMessage()));
                    }
                }
            } catch (Exception e) {
                System.debug('Exception inserting PricebookEntries: ' + e.getMessage());
            }
        }

        return pbeIdMap;
    }


    /**
     * @description Upserts the Order header and related OrderItems locally.
     */
    private void upsertOrderAndItems(
        Map<String, Object> externalOrderData,
        List<Map<String, Object>> externalOrderItems,
        Id localAccountId,
        Id localContractId,
        Map<String, Id> localProductIdMap,
        Map<String, Id> localPricebookEntryIdMap
    ) {
        String externalOrderId = (String) externalOrderData.get('Id');
        if (String.isBlank(externalOrderId)) {
            System.debug('External Order ID missing from order data. Cannot upsert.');
            return;
        }

        Schema.SObjectField orderExternalIdField = Order.SObjectType.getDescribe().fields.getMap().get('External_Id__c');
        Schema.SObjectField itemExternalIdField = OrderItem.SObjectType.getDescribe().fields.getMap().get('External_Id__c');

        if(orderExternalIdField == null || itemExternalIdField == null){
            System.debug('Error: External_Id__c field missing on Order or OrderItem.');
            return;
        }

        Id standardPricebookId = Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        if (standardPricebookId == null) {
             System.debug('Standard Pricebook ID not found. Cannot upsert Order/Items.');
             return;
        }

        // 1. Upsert Order Header
        List<Order> existingOrders = [SELECT Id FROM Order WHERE External_Id__c = :externalOrderId LIMIT 1];
        Order orderToUpsert = !existingOrders.isEmpty() ? new Order(Id = existingOrders[0].Id) : new Order();

        orderToUpsert.External_Id__c = externalOrderId; // Set on insert
        orderToUpsert.AccountId = localAccountId;
        orderToUpsert.ContractId = localContractId;
        orderToUpsert.Pricebook2Id = standardPricebookId;
        // Map other Order fields from externalOrderData
        orderToUpsert.Status = (String) externalOrderData.get('Status'); // e.g., 'Draft', 'Activated'
        orderToUpsert.EffectiveDate = Date.valueOf(((String)externalOrderData.get('EffectiveDate')).substring(0,10)); // Assuming YYYY-MM-DD format
/* orderToUpsert.OrderNumber = (String) externalOrderData.get('OrderNumber'); */
        // Add Billing/Shipping Address etc. if available

        Database.UpsertResult orderUpsertResult = Database.upsert(orderToUpsert, orderExternalIdField, false);
        Id localOrderId = null;

        if (orderUpsertResult.isSuccess()) {
            localOrderId = orderUpsertResult.getId();
            System.debug((orderUpsertResult.isCreated() ? 'Inserted' : 'Updated') + ' Order: ' + localOrderId);
        } else {
            System.debug('Order upsert failed for external ID ' + externalOrderId + ': ' + orderUpsertResult.getErrors()[0].getMessage());
            return; // Cannot proceed without a local Order ID
        }

        // 2. Upsert Order Items
        List<OrderItem> itemsToUpsert = new List<OrderItem>();
        Set<String> externalItemIds = new Set<String>();
        for(Map<String, Object> itemData : externalOrderItems) {
             externalItemIds.add((String)itemData.get('Id'));
        }

        Map<String, Id> existingItemMap = new Map<String, Id>();
         if(!externalItemIds.isEmpty()){
             for(OrderItem oi : [SELECT Id, External_Id__c FROM OrderItem WHERE External_Id__c IN :externalItemIds]) {
                 existingItemMap.put(oi.External_Id__c, oi.Id);
             }
         }


        for (Map<String, Object> itemData : externalOrderItems) {
            String externalItemId = (String) itemData.get('Id');
            String externalProductId = (String) itemData.get('Product2Id');

            // Ensure we have the corresponding local PricebookEntry
            if (String.isBlank(externalItemId) || String.isBlank(externalProductId) || !localPricebookEntryIdMap.containsKey(externalProductId)) {
                System.debug('Skipping OrderItem upsert due to missing External Item ID, External Product ID, or local PricebookEntry. External Item ID: ' + externalItemId);
                continue; // Skip this item
            }

            Id localPbeId = localPricebookEntryIdMap.get(externalProductId);
            OrderItem item = new OrderItem();

             if(existingItemMap.containsKey(externalItemId)) {
                 item.Id = existingItemMap.get(externalItemId); // Prepare for update
             } else {
                 item.External_Id__c = externalItemId; // Set external ID only on insert
             }

            item.OrderId = localOrderId;
            item.PricebookEntryId = localPbeId;
            // Map other OrderItem fields
            // Use Decimal.valueOf for numbers coming as strings/objects
            Object quantityObj = itemData.get('Quantity');
            if(quantityObj instanceOf Decimal || quantityObj instanceOf Integer || quantityObj instanceOf Double) {
                 item.Quantity = (Decimal)quantityObj;
            } else if (quantityObj instanceOf String && String.isNotBlank((String)quantityObj)) {
                 item.Quantity = Decimal.valueOf((String)quantityObj);
            } else {
                 item.Quantity = 0; // Default or handle error
            }

            Object unitPriceObj = itemData.get('UnitPrice');
             if(unitPriceObj instanceOf Decimal || unitPriceObj instanceOf Integer || unitPriceObj instanceOf Double) {
                 item.UnitPrice = (Decimal)unitPriceObj;
            } else if (unitPriceObj instanceOf String && String.isNotBlank((String)unitPriceObj)) {
                 item.UnitPrice = Decimal.valueOf((String)unitPriceObj);
            } else {
                 // If UnitPrice is null/invalid, Salesforce might pull from PBE, or you might need to handle it
                 System.debug('UnitPrice missing or invalid for external item ' + externalItemId);
                 // item.UnitPrice = 0; // Set a default?
            }

            // Add Description etc. if available

            itemsToUpsert.add(item);
        }

        if (!itemsToUpsert.isEmpty()) {
            List<Database.UpsertResult> itemUpsertResults = Database.upsert(itemsToUpsert, itemExternalIdField, false);
            for (Integer i = 0; i < itemUpsertResults.size(); i++) {
                Database.UpsertResult res = itemUpsertResults[i];
                OrderItem processedItem = itemsToUpsert[i];
                 String externalId = processedItem.External_Id__c != null ? processedItem.External_Id__c : 'Unknown'; // Try to get external ID for logging

                if (res.isSuccess()) {
                     System.debug((res.isCreated() ? 'Inserted' : 'Updated') + ' OrderItem: ' + res.getId() + ' for External ID: ' + externalId);
                } else {
                    System.debug('OrderItem upsert failed for external ID ' + externalId + ': ' + res.getErrors()[0].getMessage());
                }
            }
        } else {
             System.debug('No valid OrderItems to upsert for Order ' + localOrderId);
        }
    }
}
