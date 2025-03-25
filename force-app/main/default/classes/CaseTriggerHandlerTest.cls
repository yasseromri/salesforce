@isTest
private class CaseTriggerHandlerTest {


@IsTest
    static void testAfterInsertWithEmptyList() {
        // Create an empty list of cases
        List<Case> cases = new List<Case>();

        // Set the trigger context to after insert
        Test.startTest();
        Trigger.new = cases;
        CaseTriggerHandler handler = new CaseTriggerHandler();
        handler.afterInsert();
        Test.stopTest();

        // Verify that the EcommerceIntegration class was not called
        System.assertEquals(false, EcommerceIntegrationCalled);
    }
}