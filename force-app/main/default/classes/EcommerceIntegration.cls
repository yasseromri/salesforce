public with sharing class EcommerceIntegration {
    @future(callout = true)
    public static void getAccountAndContact(Id caseId, String email) {
        EcommerceInterface service = EcommerceServiceFactory.getService();
        service.getAccountAndContact(caseId, email);
    }
}