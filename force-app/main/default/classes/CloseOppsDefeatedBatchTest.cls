@isTest
private class CloseOppsDefeatedBatchTest {
    
    @testSetup
    static void setupData() {
        // Create test Recurring Donation
        Opportunity opp1 = new Opportunity(
            Name = 'Test Opp 1',
            StageName = 'Pledged',
            CloseDate = Date.today(),
            npsp__Recurring_Donation_Installment_Number__c = 1
        );
        insert opp1;
		
        Opportunity opp2 = new Opportunity(
            Name = 'Test Opp 2',
            StageName = 'Pledged',
            CloseDate = Date.today(),
            npsp__Recurring_Donation_Installment_Number__c = 3
        );
        insert opp2;
		
        // Create OppPayment records
        npe01__OppPayment__c pay1 = new npe01__OppPayment__c(
            npe01__Opportunity__c = opp1.Id,
            npe01__Paid__c = false,
            npe01__Scheduled_Date__c = Date.today().addDays(-1),
            Status__c = 'Pending',
            Attempts__c = 1
        );

        npe01__OppPayment__c pay2 = new npe01__OppPayment__c(
            npe01__Opportunity__c = opp2.Id,
            npe01__Paid__c = false,
            npe01__Scheduled_Date__c = Date.today().addDays(-10),
            Status__c = 'Pending',
            Attempts__c = 3
        );

        insert new List<npe01__OppPayment__c>{ pay1, pay2 };
            
        List<npe01__OppPayment__c> oppsToCheck = [SELECT npe01__Paid__c, npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c, Attempts__c, npe01__Scheduled_Date__c, npe01__Opportunity__r.StageName FROM npe01__OppPayment__c];
        Integer count=0;
        for(npe01__OppPayment__c oppToCheck : oppsToCheck) {
            count++;
            System.debug('###oppToCheck Details ' + count + ':'+oppToCheck.npe01__Paid__c);
            System.debug('###oppToCheck Details ' + count + ':'+oppToCheck.npe01__Opportunity__r.npsp__Recurring_Donation_Installment_Number__c);
            System.debug('###oppToCheck Details ' + count + ':'+oppToCheck.Attempts__c);
            System.debug('###oppToCheck Details ' + count + ':'+oppToCheck.npe01__Scheduled_Date__c);
            System.debug('###oppToCheck Details ' + count + ':'+oppToCheck.npe01__Opportunity__r.StageName);
        }
        
    }

    static testmethod void testBatchExecution() {
        Test.startTest();
        CloseOppsDefeatedBatch batch = new CloseOppsDefeatedBatch();
        Database.executeBatch(batch, 9);
        Test.stopTest();
    }
}