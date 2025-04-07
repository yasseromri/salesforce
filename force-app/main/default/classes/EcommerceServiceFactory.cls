public class EcommerceServiceFactory {
public static EcommerceInterface getService() {
        String mode = System.Label.Integration_Mode; // e.g., "Salesforce" or "MuleSoft"
        
        if (mode == 'Salesforce') {
            return new EcommerceService();
        } else {
            return new EcommerceService(); // Default to direct Salesforce REST
        }
    }
}