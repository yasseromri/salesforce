public interface ICustomerService {
    void getAccountAndContact(Id caseId, String email);
    String authenticate();
    void callEcommerceApi(Id caseId, String email, String accessToken);
   
    void upsertAccountAndContact(Id caseId, Map<String, Object> data);
}