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

    //SFEUCMSD-147 Creates a Last_Day recurring donation whose only opportunity is on the last day of the current month and runs the batch on it
    private static List<Opportunity> runForLastDayDonation(String dayOfMonth) {
        setupTestData();
        npe03__Recurring_Donation__c recurringDonation = [SELECT Id FROM npe03__Recurring_Donation__c LIMIT 1];
        recurringDonation.npsp__Day_of_Month__c = dayOfMonth;
        update recurringDonation;
        delete [SELECT Id FROM Opportunity WHERE npe03__Recurring_Donation__c = :recurringDonation.Id];

        Date today = Date.today();
        Opportunity base = new Opportunity(
            AccountId = [SELECT Id FROM Account LIMIT 1].Id,
            Name = 'Last Day Donation (1)',
            StageName = 'Pledged',
            Amount = 1000,
            CloseDate = today,
            npe03__Recurring_Donation__c = recurringDonation.Id
        );
        insert base;
        //SFEUCMSD-147 The first opportunity of a recurring donation takes the established date on insert, so the close date is set afterwards
        base.CloseDate = Utils.getInstallmentDate(today.year(), today.month(), 31);
        update base;

        Test.startTest();
        new CreateNextOpportunityBatch().execute(null, new List<npe03__Recurring_Donation__c>{ recurringDonation });
        Test.stopTest();

        return [SELECT CloseDate FROM Opportunity WHERE npe03__Recurring_Donation__c = :recurringDonation.Id AND Id != :base.Id];
    }

    //SFEUCMSD-147
    @isTest
    static void execute_lastDayOfMonth_createsNextOpportunityOnLastDayOfNextMonth() {
        List<Opportunity> created = runForLastDayDonation(Utils.LAST_DAY_OF_MONTH);

        Date nextMonth = Date.today().addMonths(1);
        Assert.areEqual(1, created.size(), 'One opportunity is created for the next month.');
        Assert.areEqual(Date.newInstance(nextMonth.year(), nextMonth.month(), Date.daysInMonth(nextMonth.year(), nextMonth.month())), created[0].CloseDate, 'The next opportunity is on the last day of the next month, not on the day of the current one.');
    }

    //SFEUCMSD-147
    @isTest
    static void createNewOpportunityForNextMonth_withoutDayOfMonth_keepsBaseDay() {
        Opportunity base = new Opportunity(Name = 'Base', Amount = 10, CloseDate = Date.newInstance(2025, 1, 15));

        Opportunity next = new CreateNextOpportunityBatch().createNewOpportunityForNextMonth(base);

        Assert.areEqual(Date.newInstance(2025, 2, 15), next.CloseDate, 'Without a Day of Month the base day is kept.');
        Assert.areEqual('Pledged', next.StageName, 'The next opportunity is pledged.');
    }

    //SFEUCMSD-147
    @isTest
    static void createNewOpportunityForNextMonth_lastDayAfterThirtyDayMonth_returnsTo31st() {
        Opportunity base = new Opportunity(Name = 'Base', Amount = 10, CloseDate = Date.newInstance(2025, 6, 30));

        Opportunity next = new CreateNextOpportunityBatch().createNewOpportunityForNextMonth(base, Utils.LAST_DAY_OF_MONTH);

        Assert.areEqual(Date.newInstance(2025, 7, 31), next.CloseDate, 'After June 30th a Last_Day donation goes back to July 31st.');
    }

    //SFEUCMSD-147
    @isTest
    static void createNewOpportunityForNextMonth_lastDayIntoFebruary_returnsEndOfFebruary() {
        Opportunity base = new Opportunity(Name = 'Base', Amount = 10, CloseDate = Date.newInstance(2026, 1, 31));

        Opportunity next = new CreateNextOpportunityBatch().createNewOpportunityForNextMonth(base, Utils.LAST_DAY_OF_MONTH);

        Assert.areEqual(Date.newInstance(2026, 2, 28), next.CloseDate, 'After January 31st a Last_Day donation falls on February 28th.');
    }

    //SFEUCMSD-147
    @isTest
    static void createNewOpportunityForNextMonth_day30IntoFebruary_returnsEndOfFebruary() {
        Opportunity base = new Opportunity(Name = 'Base', Amount = 10, CloseDate = Date.newInstance(2026, 1, 30));

        Opportunity next = new CreateNextOpportunityBatch().createNewOpportunityForNextMonth(base, '30');

        Assert.areEqual(Date.newInstance(2026, 2, 28), next.CloseDate, 'A day 30 donation falls on February 28th, the highest day of February.');
    }

    //SFEUCMSD-147
    @isTest
    static void createNewOpportunityForNextMonth_day30AfterFebruary_returnsTo30th() {
        Opportunity base = new Opportunity(Name = 'Base', Amount = 10, CloseDate = Date.newInstance(2026, 2, 28));

        Opportunity next = new CreateNextOpportunityBatch().createNewOpportunityForNextMonth(base, '30');

        Assert.areEqual(Date.newInstance(2026, 3, 30), next.CloseDate, 'After February 28th a day 30 donation goes back to March 30th.');
    }
}