global with sharing class GDPRForgetMeBatch implements Database.Batchable<SObject> {
    private static final String MASK_VALUE = 'XXXXXXX';
    
    global Database.QueryLocator start(Database.BatchableContext batchContext) {
        return Database.getQueryLocator([
            SELECT Id, IndividualId__c, IndividualId__r.ShouldForget FROM Case WHERE IndividualId__r.ShouldForget = TRUE
        ]);
    }

    global void execute(Database.BatchableContext batchContext, List<SObject> caseList) {
        // Retrieve GDPR metadata
        List<GDPR_Field_Cleanup__mdt> metadataList = [SELECT Field_API_Name__c, Anonymization_Type__c FROM GDPR_Field_Cleanup__mdt WHERE Object_Name__c = 'Case'];
        
        // Anonymize fields
        for (SObject obj : caseList) {
            Case c = (Case)obj;
            for (GDPR_Field_Cleanup__mdt meta : metadataList) {
                anonymizeField(c, meta);
            }
        }
        if (!caseList.isEmpty()) {
            update caseList;
        }
    }

    private void anonymizeField(Case c, GDPR_Field_Cleanup__mdt meta) {
        try {
            if (meta.Anonymization_Type__c == 'Mask') {
                c.put(meta.Field_API_Name__c, MASK_VALUE); // Masking
            } else if (meta.Anonymization_Type__c == 'Null') {
                if (c.get(meta.Field_API_Name__c) != null) {
                    c.put(meta.Field_API_Name__c, null); // Nullifying
                }
            }
        } catch (Exception e) {
            System.debug('Error anonymizing field: ' + meta.Field_API_Name__c + ' - ' + e.getMessage());
        }
    }

    global void finish(Database.BatchableContext batchContext) {
        System.debug('GDPR Forget Me Batch Completed.');
    }
}