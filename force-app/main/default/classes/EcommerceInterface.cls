public interface EcommerceInterface {
    void getAccountAndContact(Id caseId, String email);
    String authenticate();
    void callEcommerceApi(Id caseId, String email, String accessToken);
    Map<String, Object> getContactDetailsById(String contactId, String accessToken);
    void upsertAccountAndContact(Id caseId, Map<String, Object> data);
}