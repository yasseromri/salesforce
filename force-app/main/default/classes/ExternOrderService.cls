public class ExternOrderService {
  private static final String AUTH_URL = 'https://login.salesforce.com/services/oauth2/token';
    private static final String QUERY_ENDPOINT = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com/services/data/v63.0/query';
    private static final String ORDER_ENDPOINT = 'https://pwcsandbox53-dev-ed.develop.my.salesforce.com/services/data/v63.0/sobjects/Order/';

    public void syncOrderOrderNumber(String externalOrderId) {
        try {
            String accessToken = authenticate();
            if (accessToken != null) {
                String orderId = queryOrderIdByExternalId(externalOrderId, accessToken);
                if (orderId != null) {
                    Map<String, Object> orderData = getOrderDetails(orderId, accessToken);
                    if (orderData != null) {
                        upsertOrder(orderData);
                    } else {
                        System.debug('No order data found for Id: ' + orderId);
                    }
                } else {
                    System.debug('No external order found for External_Id__c = ' + externalOrderId);
                }
            }
        } catch (Exception e) {
            System.debug('Error in syncOrderByExternalId: ' + e.getMessage());
        }
    }

    public String authenticate() {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(AUTH_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        req.setBody(
            'grant_type=password' +
            '&client_id=' + EncodingUtil.urlEncode(System.Label.OAuth_Client_ID, 'UTF-8') +
            '&client_secret=' + EncodingUtil.urlEncode(System.Label.OAuth_Client_Secret, 'UTF-8') +
            '&username=' + EncodingUtil.urlEncode(System.Label.OAuth_Username, 'UTF-8') +
            '&password=' + EncodingUtil.urlEncode(System.Label.OAuth_Password, 'UTF-8')
        );

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('access_token');
        }

        System.debug('OAuth failed: ' + res.getBody());
        return null;
    }

    public String queryOrderIdByExternalId(String externalId, String accessToken) {
        String soql = 'SELECT+Id+FROM+Order+WHERE+OrderNumber=\'' + EncodingUtil.urlEncode(externalId, 'UTF-8') + '\'';
        String endpoint = QUERY_ENDPOINT + '?q=' + soql;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) json.get('records');
            if (!records.isEmpty()) {
                Map<String, Object> firstRecord = (Map<String, Object>) records[0];
                return (String) firstRecord.get('Id');
            }
        }

        System.debug('Order query failed: ' + res.getBody());
        return null;
    }

    public Map<String, Object> getOrderDetails(String orderId, String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ORDER_ENDPOINT + orderId);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        }

        System.debug('Order detail fetch failed: ' + res.getBody());
        return null;
    }

    public void upsertOrder(Map<String, Object> data) {
        try {
            String extId = (String) data.get('External_Id__c');
            List<Order> existing = [SELECT Id FROM Order WHERE External_Id__c = :extId LIMIT 1];
            Order ord;

            if (!existing.isEmpty()) {
                ord = existing[0];
                ord.Status = (String) data.get('Status');
                ord.EffectiveDate = Date.valueOf((String) data.get('EffectiveDate'));
                update ord;
                System.debug('Updated existing Order: ' + ord);
            } else {
                ord = new Order();
                ord.External_Id__c = extId;
                //to make it dynamic
                ord.ContractId  = '800Qy00000ejWZNIA2';
                ord.AccountId = '001Qy00000m2HjZIAU';
                ord.Status = (String) data.get('Status');
                
                ord.EffectiveDate = Date.valueOf((String) data.get('EffectiveDate'));
                // Add required fields like AccountId here if needed
                insert ord;
                System.debug('Inserted new Order: ' + ord);
            }
        } catch (Exception e) {
            System.debug('Error in upsertOrder: ' + e.getMessage());
        }
    }
}