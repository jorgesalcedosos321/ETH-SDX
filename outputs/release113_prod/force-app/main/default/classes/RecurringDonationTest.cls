@isTest
public class RecurringDonationTest {
    // Helper method to create test data
    private static Opportunity createOpportunity(Id accountId, Id contactId, String stageName, String type, Id recurringDonationId) {
        Opportunity opp = new Opportunity(
            AccountId = accountId,
            ContactId = contactId, 
            StageName = stageName,
            Type = type,
            npe03__Recurring_Donation__c = recurringDonationId,
            Name = 'OppRandom' + AccountId, 
            CloseDate = Date.Today()
        );
        insert opp;
        return opp;
    }

    private static Account createAccount(String recordTypeName) {
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = :recordTypeName LIMIT 1];
        Account acc = new Account(
            Name = 'Test Account',
            RecordTypeId = rt.Id
        );
        insert acc;
        return acc;
    }

    private static Contact createContact(Id accountId) {
        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            AccountId = accountId,
            npe01__Preferred_Email__c = 'Personal',
            npe01__HomeEmail__c = 'john.doe@example.com'
        );
        insert con;
        return con;
    }

    private static npe03__Recurring_Donation__c createRecurringDonation(Id contactId, Id organizationId) {
        npe03__Recurring_Donation__c rd = new npe03__Recurring_Donation__c(
            npe03__Contact__c = contactId,
            npe03__Organization__c = organizationId,
            npsp__PaymentMethod__c = 'Check',
            npe03__Amount__c  = 100,
            npsp__Day_of_Month__c = '1',
            Donor_Type__c = 'Individual', 
            Donation_Type__c = 'Recurring Donation'       
        );
        insert rd;
        return rd;
    }

    @isTest
    static void testSetOpportunityTypeByRDRT() {
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        
        npe03__Recurring_Donation__c rd = createRecurringDonation(con.Id, null);
        
        Opportunity opp = createOpportunity(acc.Id, con.Id, 'Prospecting', 'New', rd.Id);
        
        List<Opportunity> oppList = new List<Opportunity>{ opp };
            Test.startTest();
        
        // Execute method
        OpportunityService service = new OpportunityService();
        service.setOpportunityTypeByRDRT(oppList);
        
        Test.stopTest();
        
        // Assert results
        opp = [SELECT Type FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Individual Committed', opp.Type, 'Opportunity Type should be set as "Individual Committed"');
    }

    //SFESWCSD-113
    private static npe03__Recurring_Donation__c createHistoricRecurringDonation() {
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        return createRecurringDonation(con.Id, null);
    }

    //SFESWCSD-113
    private static Integer countJobs(String className) {
        return [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = :className AND JobType IN ('BatchApex', 'Queueable')];
    }

    //SFESWCSD-113
    @isTest
    static void generateHistoricOpportunities_establishedBeforeCurrentMonth_startsBatch() {
        createHistoricRecurringDonation();
        List<npe03__Recurring_Donation__c> rds = [SELECT Id, npe03__Date_Established__c FROM npe03__Recurring_Donation__c];
        rds[0].npe03__Date_Established__c = Date.today().toStartOfMonth().addDays(-1);
        Integer batchJobsBefore = countJobs('GenerateHistoricOppsBatch');

        Test.startTest();
        new RecurringDonationService().generateHistoricOpportunities(rds);
        Test.stopTest();

        Assert.areEqual(batchJobsBefore + 1, countJobs('GenerateHistoricOppsBatch'), 'One batch job is started for the old recurring donations.');
    }

    //SFESWCSD-113
    @isTest
    static void generateHistoricOpportunities_establishedInCurrentMonth_doesNotStartBatch() {
        createHistoricRecurringDonation();
        List<npe03__Recurring_Donation__c> rds = [SELECT Id, npe03__Date_Established__c FROM npe03__Recurring_Donation__c];
        for (npe03__Recurring_Donation__c rd : rds) {
            rd.npe03__Date_Established__c = Date.today().toStartOfMonth();
        }
        rds.add(new npe03__Recurring_Donation__c(Name = 'No date', npe03__Date_Established__c = null));
        Integer batchJobsBefore = countJobs('GenerateHistoricOppsBatch');

        Test.startTest();
        new RecurringDonationService().generateHistoricOpportunities(rds);
        Test.stopTest();

        Assert.areEqual(batchJobsBefore, countJobs('GenerateHistoricOppsBatch'), 'Recurring donations of the current month or without date are skipped.');
    }

    //SFESWCSD-113
    @isTest
    static void generateHistoricOpportunities_nullOrEmptyList_doesNothing() {
        Integer batchJobsBefore = countJobs('GenerateHistoricOppsBatch');

        Test.startTest();
        new RecurringDonationService().generateHistoricOpportunities(null);
        new RecurringDonationService().generateHistoricOpportunities(new List<npe03__Recurring_Donation__c>());
        Test.stopTest();

        Assert.areEqual(batchJobsBefore, countJobs('GenerateHistoricOppsBatch'), 'No job is started without recurring donations.');
    }

    //SFESWCSD-113
    @isTest
    static void scheduleHistoricOpportunities_batchOrFutureContext_enqueuesQueueable() {
        createHistoricRecurringDonation();
        Set<Id> rdIds = new Map<Id, npe03__Recurring_Donation__c>([SELECT Id FROM npe03__Recurring_Donation__c]).keySet();
        Integer queueableJobsBefore = countJobs('GenerateHistoricOppsQueueable');

        Test.startTest();
        RecurringDonationService.scheduleHistoricOpportunities(rdIds, true, RecurringDonationService.HISTORIC_OPPS_STAGE_NAME);
        Test.stopTest();

        Assert.areEqual(queueableJobsBefore + 1, countJobs('GenerateHistoricOppsQueueable'), 'A queueable is used where executeBatch is not allowed.');
    }

    //SFESWCSD-113
    @isTest
    static void scheduleHistoricOpportunities_queueableLimitReached_doesNotThrow() {
        createHistoricRecurringDonation();
        Set<Id> rdIds = new Map<Id, npe03__Recurring_Donation__c>([SELECT Id FROM npe03__Recurring_Donation__c]).keySet();

        Test.startTest();
        for (Integer i = 0; i < Limits.getLimitQueueableJobs(); i++) {
            System.enqueueJob(new GenerateHistoricOppsQueueable(null));
        }
        RecurringDonationService.scheduleHistoricOpportunities(rdIds, true, RecurringDonationService.HISTORIC_OPPS_STAGE_NAME);
        Integer queuedJobs = Limits.getQueueableJobs();
        Test.stopTest();

        Assert.areEqual(Limits.getLimitQueueableJobs(), queuedJobs, 'The limit is reached and no extra job is enqueued.');
    }
}