public class AccountUtility {
    public static void viewAnnualRevenue() {
        // Create a list to store the query results
        List<Account> accountsList = [SELECT Name, AnnualRevenue FROM Account];
        
        // Iterate through the query results
        for (Account acct : accountsList) {
            // Concatenate the account name and annual revenue
            String acctRev = acct.Name + ' : ' + acct.AnnualRevenue;
            
            // Print the concatenated string to the debug log
            System.debug(acctRev);
        }
    }
}