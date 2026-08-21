@isTest
private class DPOReadTransactionBatchTest {
    // Helper method to create sample Recurring Donation and Opportunity records
    @testSetup
    static void setupData() {
        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        // Create Contact
        Contact con = new Contact(FirstName = 'John Salc', LastName = 'Doe Salc', AccountId = acc.Id, Email = 'jorge2.salcedo3@sos-kd.org', Phone = '4828289122');
        insert con;
        
        // Create Recurring Donation
        npe03__Recurring_Donation__c recurringDonation = new npe03__Recurring_Donation__c(
            npe03__Amount__c = 1300,
            //npe03__Organization__c = acc.Id,
            npe03__Contact__c = con.Id,
            npsp__Day_of_Month__c = '1',
            npe03__Open_Ended_Status__c = 'Open',
            Donor_Type__c = 'Individual', 
            Donation_Type__c = 'Recurring Donation',
            transaction_ID__c = '123456',
            npsp__Status__c = 'Active',
            npe03__Installment_Period__c = 'Monthly',
            npsp__InstallmentFrequency__c = 3
        );
        insert recurringDonation;
    }
    
	@isTest 
    static void RunBatchForSampleResponseData(){
        List<Opportunity> opportunities = [SELECT Id, Name, CloseDate, StageName, npe03__Recurring_Donation__c FROM Opportunity];
        Integer i = opportunities.size() + 1;
        for (Opportunity newOpportunity : opportunities) {
          i = i-1;
          newOpportunity.CloseDate = Date.Today();
          newOpportunity.StageName = 'Pledged';
        } 
        UPDATE opportunities;
        System.debug('opportunities:' + opportunities);
        
        List<npe01__OppPayment__c> payments = [SELECT Id, npe01__Scheduled_Date__c, Attempts__c, npe01__Paid__c, Transaction_Ref__c FROM npe01__OppPayment__c];
        Integer j = 0;
        for (npe01__OppPayment__c payment : payments) {
            if (j < 4) {
                payment.npe01__Scheduled_Date__c = Date.Today().addDays(-j);
                payment.Transaction_Ref__c = (Integer.valueOf('123456') + j) + '';
                payment.Attempts__c = j;
                payment.npe01__Paid__c = false;
                j = j+1;          
                System.debug('payment.Attempts__c:' + payment.Attempts__c);
            }    
        } 
        UPDATE payments;
        
        List<npe01__OppPayment__c> paymentsUpdated = [SELECT Id, npe01__Scheduled_Date__c, Transaction_Ref__c, Attempts__c, npe01__Paid__c, npe01__Opportunity__r.npe03__Recurring_Donation__r.transaction_ID__c,
                                         npe01__Opportunity__r.npe03__Recurring_Donation__r.npsp__Status__c
                                         FROM npe01__OppPayment__c];
        
        System.debug('paymentsUpdated:' + paymentsUpdated);
        for (npe01__OppPayment__c paymentUpdated : paymentsUpdated)
        	System.debug(paymentsUpdated);
        
        DPOReadTransactionBatch btch = new DPOReadTransactionBatch();
        btch.execute(null);        
    }
    
    @isTest 
    static void RunBatchForDPOHandlerMethods(){
        List<Opportunity> opportunities = [SELECT Id, Name, CloseDate, StageName, npe03__Recurring_Donation__c FROM Opportunity];
        Integer i = opportunities.size() + 1;
        for (Opportunity newOpportunity : opportunities) {
          i = i-1;
          newOpportunity.CloseDate = Date.Today();
          newOpportunity.StageName = 'Pledged';
        } 
        UPDATE opportunities;
        System.debug('opportunities:' + opportunities);
        
        List<npe01__OppPayment__c> payments = [SELECT Id, npe01__Scheduled_Date__c, Attempts__c, npe01__Paid__c, Transaction_Ref__c FROM npe01__OppPayment__c];
        Integer j = 0;
        for (npe01__OppPayment__c payment : payments) {
            if (j < 4) {
                payment.npe01__Scheduled_Date__c = Date.Today().addDays(-j);
                payment.Transaction_Ref__c = (Integer.valueOf('123456') + j) + '';
                payment.Attempts__c = j;
                payment.npe01__Paid__c = false;
                j = j+1;          
                System.debug('payment.Attempts__c:' + payment.Attempts__c);
            }    
        } 
        UPDATE payments;
        
        String startTimestamp = Utils.getTimestampFromAddingDays(Date.today(), -1);
		String endTimestamp = Utils.getTimestampFromAddingDays(Date.today(), 0);
        
		DPOHandler dpoHandler = new DPOHandler();
        DPOXMLResponse response = dpoHandler.getTransactionsOneDayAgo(100, 0, startTimestamp, endTimestamp);
        String sampleXML = dpoHandler.xmlResponseSample();
        
        npe01__OppPayment__c paymentFound = dpoHandler.getTransactionByCode(payments, '123456');
        DPOXMLResponse res = new DPOXMLResponse();
        DPOXMLResponse.DPOTransaction dpoTrans = new DPOXMLResponse.DPOTransaction();         
        dpoTrans.TransactionAmount = 1000;
        dpoTrans.TransactionPaymentDate = Date.today();
        dpoTrans.TransactionBookRef = '123322';
        dpoTrans.TransactionApprovalNumber = '10';
        dpoTrans.TransactionRef = '123456';
        res.Transactions = new List<DPOXMLResponse.DPOTransaction> {dpoTrans};
        dpoHandler.saveDPOTransactionValuesToPayment(res);
    }
}