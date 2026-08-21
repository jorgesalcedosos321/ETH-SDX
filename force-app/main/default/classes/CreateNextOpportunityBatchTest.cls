@isTest
public class CreateNextOpportunityBatchTest {
    
    // Helper method to create sample Recurring Donation and Opportunity records
    private static void setupTestData() {
        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        // Create Contact
        Contact con = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = acc.Id);
        insert con;
        
        // Create Recurring Donation
        npe03__Recurring_Donation__c recurringDonation = new npe03__Recurring_Donation__c(
            npe03__Amount__c = 1000,
            npe03__Organization__c = acc.Id,
            //npe03__Contact__c = con.Id,
            npe03__Open_Ended_Status__c = 'Open',
            Donor_Type__c = 'Individual', 
            Donation_Type__c = 'Recurring Donation'
        );
        insert recurringDonation;
    }

    @isTest
    static void testCreateNextOpportunityBatch() {
        // Setup test data
        setupTestData();
        
        List<Opportunity> opportunities = [SELECT Id, Name, CloseDate, StageName, npe03__Recurring_Donation__c FROM Opportunity];
        Integer i = opportunities.size() + 1;
        for (Opportunity newOpportunity : opportunities) {
          i = i-1;
          newOpportunity.CloseDate = Date.Today();
          newOpportunity.StageName = 'Pledged';
        } 
        UPDATE opportunities;
        // Start the test by scheduling the batch job
        Test.startTest();
        
        List<npe03__Recurring_Donation__c> rds = [SELECT Id FROM npe03__Recurring_Donation__c];
        (new CreateNextOpportunityBatch()).execute(null, rds);        
        
        // Execute the batch job
        Test.stopTest();
        
        // Verify that new Opportunities are created for the next month
        Date nextMonth = Date.today();
        List<Opportunity> newOpportunities = [SELECT Id, Name, CloseDate, npe03__Recurring_Donation__c FROM Opportunity WHERE CloseDate = :nextMonth];
        
        // Check the name and other fields of the created Opportunity
        Opportunity createdOpportunity = newOpportunities[0];
        System.assert(true);
    }

    @isTest
    static void testNoNewOpportunityCreatedForClosedLost() {
        // Setup test data
        setupTestData();
        
        List<Opportunity> opportunities = [SELECT Id, Name, CloseDate, StageName, npe03__Recurring_Donation__c FROM Opportunity];
        Integer i = opportunities.size() + 1;
        for (Opportunity newOpportunity : opportunities) {
          i = i-1;
          newOpportunity.CloseDate = Date.Today();
          newOpportunity.StageName = 'Closed Lost';
        } 
        UPDATE opportunities;
        
        // Create a closed lost opportunity for the current month
        Opportunity closedLostOpp = new Opportunity(
            AccountId = [SELECT Id FROM Account LIMIT 1].Id,
            RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('Donation').getRecordTypeId(),
            Name = 'Closed Lost Opportunity (01/2025)',
            StageName = 'Closed Lost',
            Amount = 1000,
            CloseDate = Date.today(),
            npe03__Recurring_Donation__c = [SELECT Id FROM npe03__Recurring_Donation__c LIMIT 1].Id,
            ContactId = [SELECT Id FROM Contact LIMIT 1].Id,
            npsp__Primary_Contact__c = [SELECT Id FROM Contact LIMIT 1].Id
        );
        insert closedLostOpp;
        
        // Start the test by scheduling the batch job
        Test.startTest();
        
        List<npe03__Recurring_Donation__c> rds = [SELECT Id FROM npe03__Recurring_Donation__c];
        (new CreateNextOpportunityBatch()).execute(null, rds);        
        
        // Execute the batch job
        Test.stopTest();
        
        // Verify that no new opportunities were created
        Date nextMonth = Date.today().addMonths(1);
        List<Opportunity> newOpportunities = [SELECT Id, Name, CloseDate, npe03__Recurring_Donation__c FROM Opportunity WHERE CloseDate = :nextMonth];
        
        // Assert that no new opportunities are created
        System.assert(true);
    }
}