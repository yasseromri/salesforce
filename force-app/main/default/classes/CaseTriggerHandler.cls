public class CaseTriggerHandler extends TriggerHandler {
    
    public override void afterInsert() {
        List<Case> newCases = (List<Case>) Trigger.new;

        // Process each new case directly
        for (Case c : newCases) {
            // Check if the required email field is populated and not just whitespace
            if (String.isNotBlank(c.SuppliedEmail)) {
                // Call the future method to handle the integration logic asynchronously.
                // Pass the specific Case ID and its email.
                // This assumes EcommerceIntegration.getAccountAndContact is designed
                // to handle one case at a time via a future call.
                EcommerceIntegration.getAccountAndContact(c.Id, c.SuppliedEmail);
            }
            // Optional: Add an else block here if you need to log or handle cases
            // that *don't* have a SuppliedEmail.
            // else {
            //     System.debug('Case ' + c.Id + ' does not have a SuppliedEmail, skipping integration call.');
            // }
        }
    }
}