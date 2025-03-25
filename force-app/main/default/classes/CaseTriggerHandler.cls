public class CaseTriggerHandler extends TriggerHandler {
    
    public override void afterInsert() {
        List<Case> newCases = (List<Case>) Trigger.new;

        // Ensure list is not empty before processing
        if (newCases.isEmpty()) {
            return;
        }

        // Collect email addresses to avoid unnecessary API calls
        List<String> emailList = new List<String>();
        for (Case c : newCases) {
            if (c.SuppliedEmail != null) {
                emailList.add(c.SuppliedEmail);
            }
        }
        
        // Process the email list in batches
        if (!emailList.isEmpty()) {
            for (Integer i = 0; i < newCases.size(); i++) {
                Case c = newCases[i];
                if (c.SuppliedEmail != null) {
                    // Call EcommerceIntegration with the correct Case ID and Email
                    EcommerceIntegration.getAccountAndContact(c.Id, c.SuppliedEmail);
                }
            }
        }
    }
}