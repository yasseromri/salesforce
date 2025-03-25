trigger contactTrigger on Contact (after insert , after update) {
List <Contact_Sync_Event__e> events = new list <Contact_Sync_Event__e>();
    for (Contact c : Trigger.new){
        Contact_Sync_Event__e event = new Contact_Sync_Event__e(
        FirstName__c = c.FirstName,
        LastName__c = c.LastName,
            Email__c = c.Email,
            External_Id__c = c.id
        );
        events.add(event);
    } 
    EventBus.publish(events);
}