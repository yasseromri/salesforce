public interface IOrderService {
     /**
     * @description Fetches order details, related items, and products from an external system
     *              based on an external order ID, creates necessary related records (like a dummy contract),
     *              and upserts the data into the local Salesforce org.
     * @param externalOrderId The ID of the Order in the external system.
     * @param externalAccountId The ID of the related Account in the external system (used to link locally).
     */
    void syncOrderData(String externalOrderId, String externalAccountId);

    // We can potentially add more specific methods if needed later
    // String authenticate(); // Authentication might be kept internal or exposed if needed elsewhere
    // Map<String, Object> getExternalOrder(String externalOrderId, String accessToken);
    // List<Map<String, Object>> getExternalOrderItems(String externalOrderId, String accessToken);
    // Map<String, Object> getExternalProduct(String externalProductId, String accessToken);

}