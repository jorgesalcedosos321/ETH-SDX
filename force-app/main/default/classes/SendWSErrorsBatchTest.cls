@isTest
private class SendWSErrorsBatchTest {

    @testSetup
    static void setupData() {
        // Insert a Transaction__c record with errors
        Transaction__c tx = new Transaction__c(
            Json__c = '{"data":"sample"}',
            Errors__c = 'Error: Sample issue occurred.',
            Has_Errors__c = true,
            Fixed__c = false
        );
        insert tx;
    }

    static testMethod void testBatchExecution() {
        // Optionally mock email logic if needed

        Test.startTest();
        SendWSErrorsBatch batch = new SendWSErrorsBatch();
        Database.executeBatch(batch, 9);
        Test.stopTest();
        
        // Just a sanity check - you can enhance this to assert logs, future state, etc.
        System.assertEquals(1, [SELECT COUNT() FROM Transaction__c WHERE Has_Errors__c = true AND Fixed__c = false]);
    }
}