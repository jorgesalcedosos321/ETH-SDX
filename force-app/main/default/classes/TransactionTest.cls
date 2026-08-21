@isTest
public class TransactionTest {
    
    @testSetup
    static void setupData() {
        // Insert test transactions for today
        List<Transaction__c> transactions = new List<Transaction__c>();
        for (Integer i = 0; i < 5; i++) {
            Transaction__c txn = new Transaction__c();
            txn.Json__c = '{"key' + i + '": "value' + i + '"}';
            transactions.add(txn);
        }
        insert transactions;
    }

    @isTest
    static void testInsertTransaction() {
        Test.startTest();
        TransactionService.insertTransaction('{"testKey": "testValue"}');
        Test.stopTest();

        // Verify the record was inserted
        List<Transaction__c> txn = [SELECT Id, Json__c FROM Transaction__c];
        System.assert(txn.size() > 0);
    }

    @isTest
    static void testGetTodaysTransactions() {
        Test.startTest();
        List<Transaction__c> transactions = TransactionService.getTodaysTransactions();
        Test.stopTest();

        // Verify records are returned
        System.assert(transactions.size() > 0, 'No transactions found for today.');
    }

    @isTest
    static void testScheduledJob() {
        Test.startTest();
        // Execute the scheduled job
        TransactionScheduler scheduler = new TransactionScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify transactions were deleted
        List<Transaction__c> remainingTxns = [SELECT Id FROM Transaction__c WHERE CreatedDate = TODAY];
        System.assertEquals(0, remainingTxns.size(), 'Transactions were not deleted after processing.');
    }
}