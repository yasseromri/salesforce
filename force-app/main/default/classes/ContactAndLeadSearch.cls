public class ContactAndLeadSearch {
    public static List<List<sObject>> searchContactsAndLeads(String name) {

        List<List<sObject>> results = [FIND :name IN Name Fields RETURNING Contact(Id, FirstName, LastName), Lead(Id, FirstName, LastName)];
        return results;
    }
}