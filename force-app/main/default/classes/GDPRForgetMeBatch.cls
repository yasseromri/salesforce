global class GDPRForgetMeBatch implements Database.Batchable<SObject>, Database.Stateful {
    private static final String MASK_VALUE = 'GGG';
    private Map<String, List<GDPR_Field_Cleanup__mdt>> metadataByObject;
    private List<String> objectNames;
    private Integer currentObjectIndex;

    public GDPRForgetMeBatch() {
        metadataByObject = new Map<String, List<GDPR_Field_Cleanup__mdt>>();
        for (GDPR_Field_Cleanup__mdt meta : [
            SELECT Field_API_Name__c, Anonymization_Type__c, Object_Name__c 
            FROM GDPR_Field_Cleanup__mdt
        ]) {
            if (!metadataByObject.containsKey(meta.Object_Name__c)) {
                metadataByObject.put(meta.Object_Name__c, new List<GDPR_Field_Cleanup__mdt>());
            }
            metadataByObject.get(meta.Object_Name__c).add(meta);
        }
        System.debug('Metadata by Object: ' + metadataByObject);

        objectNames = new List<String>(metadataByObject.keySet());
        currentObjectIndex = 0;
    }

    global Database.QueryLocator start(Database.BatchableContext batchContext) {
        if (!objectNames.isEmpty()) {
            String objectName = objectNames[currentObjectIndex];
            String query;

            if (objectName == 'Contact') {
                query = 'SELECT Id, IndividualId FROM Contact WHERE Individual.ShouldForget = TRUE';
            } else {
                query = 'SELECT Id, IndividualId__c, IndividualId__r.ShouldForget FROM ' + objectName + 
                        ' WHERE IndividualId__r.ShouldForget = TRUE';
            }
            System.debug('Query for ' + objectName + ': ' + query);
            return Database.getQueryLocator(query);
        }
        return Database.getQueryLocator('SELECT Id FROM Account WHERE Id = null'); // Dummy query
    }

    global void execute(Database.BatchableContext batchContext, List<SObject> recordList) {
        if (currentObjectIndex >= objectNames.size()) {
            return;
        }

        String objectName = objectNames[currentObjectIndex];
        Map<String, List<SObject>> recordsByObject = new Map<String, List<SObject>>();
        recordsByObject.put(objectName, recordList);

        // Debugging: Check if we're processing the Contact object
        System.debug('Processing Object: ' + objectName);
        List<GDPR_Field_Cleanup__mdt> metadataList = metadataByObject.get(objectName);
        if (metadataList != null) {
            for (SObject record : recordList) {
                for (GDPR_Field_Cleanup__mdt meta : metadataList) {
                    anonymizeField(record, meta);
                }
            }
            update recordList;
        } else {
            System.debug('No metadata found for object: ' + objectName);
        }

        // Move to the next object
        currentObjectIndex++;
    }

    private void anonymizeField(SObject record, GDPR_Field_Cleanup__mdt meta) {
        try {
            if (meta.Anonymization_Type__c == 'Mask') {
                record.put(meta.Field_API_Name__c, MASK_VALUE); // Masking
                System.debug('Masked field: ' + meta.Field_API_Name__c + ' with value: ' + MASK_VALUE);
            } else if (meta.Anonymization_Type__c == 'Null') {                
                    record.put(meta.Field_API_Name__c, ''); // Nullifying
                    System.debug('Nullified field: ' + meta.Field_API_Name__c);
               
            }
        } catch (Exception e) {
            System.debug('Error anonymizing field: ' + meta.Field_API_Name__c + ' - ' + e.getMessage());
        }
    }

    global void finish(Database.BatchableContext batchContext) {
    if (currentObjectIndex + 1 < objectNames.size()) {
        System.debug('Starting batch for next object: ' + objectNames[currentObjectIndex + 1]);
        
        // Start a new batch for the next object
        GDPRForgetMeBatch nextBatch = new GDPRForgetMeBatch();
        nextBatch.currentObjectIndex = this.currentObjectIndex + 1; // Move to the next object
        Database.executeBatch(nextBatch);
    } else {
        System.debug('GDPR Forget Me Batch Completed for all objects.');
    }
}
}