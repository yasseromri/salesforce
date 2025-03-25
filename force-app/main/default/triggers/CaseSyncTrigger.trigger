trigger CaseSyncTrigger on Case (after insert) {
 List<Case_Sync_Event__e> events = new List<Case_Sync_Event__e>();
    
    for (Case c : Trigger.new) {
        Case_Sync_Event__e event = new Case_Sync_Event__e(
            CaseId_c__c = c.Id,
            Subject_c__c = c.Subject,
           Description_c__c = c.Description,
            Status_c__c = (c.Status == 'Closed')
        );
        events.add(event);
    }
    
    if (!events.isEmpty()) {
        EventBus.publish(events);
    }
}