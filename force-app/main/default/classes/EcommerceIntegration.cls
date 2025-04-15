public with sharing class EcommerceIntegration {
    @future(callout = true)
    public static void getAccountAndContact(Id caseId, String email) {
        String provider = System.Label.Integration_Mode; // Used to match Provider__c in custom setting

        List<EcommerceInterface> services = new List<EcommerceInterface>();
        if (services.isEmpty()) {
            System.debug('No services found for provider: ' + provider);
            return;
        }

        for (EcommerceInterface service : services) {
            try {
                
                service.getAccountAndContact(caseId, email);
            } catch (Exception e) {
                System.debug('Error invoking service: ' + e.getMessage());
              
            }
        }
    }
}