public with sharing class EcommerceIntegration {
    public static EcommerceInterface ecommerceService = new EcommerceService();
    @future(callout = true)
    public static void getAccountAndContact(Id caseId, String email) {
        ecommerceService.getAccountAndContact(caseId, email);
    }
   
}