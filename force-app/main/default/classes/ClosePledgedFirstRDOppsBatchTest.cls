//SFEUCMSD-130
@isTest
private class ClosePledgedFirstRDOppsBatchTest {

    //SFEUCMSD-130
    private static Opportunity createRdWithOpp(String accName, Decimal installmentNumber, String stageName, Datetime createdDate) {
        Account acc = new Account(Name = accName);
        insert acc;
        npe03__Recurring_Donation__c rd = new npe03__Recurring_Donation__c(
            npe03__Amount__c = 1000,
            npe03__Organization__c = acc.Id,
            npe03__Open_Ended_Status__c = 'Open',
            Donor_Type__c = 'Individual',
            Donation_Type__c = 'Recurring Donation'
        );
        insert rd;
        Opportunity opp = [SELECT Id FROM Opportunity WHERE npe03__Recurring_Donation__c =: rd.Id LIMIT 1];
        opp.StageName = stageName;
        opp.npsp__Recurring_Donation_Installment_Number__c = installmentNumber;
        update opp;
        Test.setCreatedDate(opp.Id, createdDate);
        return opp;
    }

    //SFEUCMSD-130
    private static Opportunity reload(Id oppId) {
        return [SELECT Id, StageName, npe03__Recurring_Donation__r.npsp__Status__c FROM Opportunity WHERE Id =: oppId];
    }

    //SFEUCMSD-130
    @isTest
    static void shouldCloseOppAndRd_WhenFirstPledgedOppOlderThan24Hours() {
        Opportunity opp = createRdWithOpp('Old First', 1, 'Pledged', Datetime.now().addHours(-25));

        Test.startTest();
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), ClosePledgedFirstRDOppsBatch.BATCH_SIZE);
        Test.stopTest();

        Opportunity result = reload(opp.Id);
        Assert.areEqual('Closed Lost', result.StageName, 'Opportunity should be Closed Lost');
        Assert.areEqual('Closed', result.npe03__Recurring_Donation__r.npsp__Status__c, 'Recurring donation should be Closed');
    }

    //SFEUCMSD-130
    @isTest
    static void shouldNotCloseAnything_WhenOppIsLessThan24HoursOld() {
        Opportunity opp = createRdWithOpp('Recent First', 1, 'Pledged', Datetime.now().addHours(-2));

        Test.startTest();
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), ClosePledgedFirstRDOppsBatch.BATCH_SIZE);
        Test.stopTest();

        Opportunity result = reload(opp.Id);
        Assert.areEqual('Pledged', result.StageName, 'Opportunity should remain Pledged');
        Assert.areNotEqual('Closed', result.npe03__Recurring_Donation__r.npsp__Status__c, 'Recurring donation should not be Closed');
    }

    //SFEUCMSD-130
    @isTest
    static void shouldNotCloseAnything_WhenOppIsNotFirstInstallment() {
        Opportunity opp = createRdWithOpp('Second Installment', 2, 'Pledged', Datetime.now().addHours(-48));

        Test.startTest();
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), ClosePledgedFirstRDOppsBatch.BATCH_SIZE);
        Test.stopTest();

        Opportunity result = reload(opp.Id);
        Assert.areEqual('Pledged', result.StageName, 'Second installment should remain Pledged');
        Assert.areNotEqual('Closed', result.npe03__Recurring_Donation__r.npsp__Status__c, 'Recurring donation should not be Closed');
    }

    //SFEUCMSD-130
    @isTest
    static void shouldNotCloseAnything_WhenOppIsNotPledged() {
        Opportunity opp = createRdWithOpp('Already Posted', 1, 'Closed Won', Datetime.now().addHours(-48));

        Test.startTest();
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), ClosePledgedFirstRDOppsBatch.BATCH_SIZE);
        Test.stopTest();

        Opportunity result = reload(opp.Id);
        Assert.areEqual('Closed Won', result.StageName, 'Posted opportunity should be untouched');
        Assert.areNotEqual('Closed', result.npe03__Recurring_Donation__r.npsp__Status__c, 'Recurring donation should not be Closed');
    }

    //BUG_EXCEPTION
    private static Opportunity createRdWithCampaignAndOpp(String accName, String campaignName) {
        Campaign cmp = new Campaign(Name = campaignName);
        insert cmp;
        Account acc = new Account(Name = accName);
        insert acc;
        npe03__Recurring_Donation__c rd = new npe03__Recurring_Donation__c(
            npe03__Amount__c = 1000,
            npe03__Organization__c = acc.Id,
            npe03__Open_Ended_Status__c = 'Open',
            Donor_Type__c = 'Individual',
            Donation_Type__c = 'Recurring Donation',
            npe03__Recurring_Donation_Campaign__c = cmp.Id
        );
        insert rd;
        Opportunity opp = [SELECT Id FROM Opportunity WHERE npe03__Recurring_Donation__c =: rd.Id LIMIT 1];
        opp.StageName = 'Pledged';
        opp.npsp__Recurring_Donation_Installment_Number__c = 1;
        update opp;
        //SFEUCMSD-130 inside the 24 to 48 hours window
        Test.setCreatedDate(opp.Id, Datetime.now().addHours(-30));
        return opp;
    }

    //SFEUCMSD-130
    @isTest
    static void shouldNotCloseAnything_WhenFirstPledgedOppOlderThan48Hours() {
        Opportunity opp = createRdWithOpp('Old Data First', 1, 'Pledged', Datetime.now().addHours(-49));

        Test.startTest();
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), ClosePledgedFirstRDOppsBatch.BATCH_SIZE);
        Test.stopTest();

        Opportunity result = reload(opp.Id);
        Assert.areEqual('Pledged', result.StageName, 'A first installment created more than 48 hours ago must stay Pledged');
        Assert.areNotEqual('Closed', result.npe03__Recurring_Donation__r.npsp__Status__c, 'Its recurring donation must not be Closed');
    }

    //SFEUCMSD-130
    @isTest
    static void shouldCloseOppAndRd_WhenFirstPledgedOppJustUnder48Hours() {
        Opportunity opp = createRdWithOpp('Edge First', 1, 'Pledged', Datetime.now().addHours(-47));

        Test.startTest();
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), ClosePledgedFirstRDOppsBatch.BATCH_SIZE);
        Test.stopTest();

        Opportunity result = reload(opp.Id);
        Assert.areEqual('Closed Lost', result.StageName, 'A first installment created 47 hours ago is inside the window and must be closed');
        Assert.areEqual('Closed', result.npe03__Recurring_Donation__r.npsp__Status__c, 'Its recurring donation must be Closed');
    }

    //BUG_EXCEPTION
    @isTest
    static void shouldNotCloseAnything_WhenRecurringDonationCampaignIsF2F() {
        Opportunity opp = createRdWithCampaignAndOpp('F2F Donor', 'F2F');
        Assert.areEqual('F2F', [SELECT Current_Campaign_Name__c FROM npe03__Recurring_Donation__c WHERE Id =: [SELECT npe03__Recurring_Donation__c FROM Opportunity WHERE Id =: opp.Id].npe03__Recurring_Donation__c].Current_Campaign_Name__c, 'Precondition: the recurring donation campaign resolves to F2F');

        Test.startTest();
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), ClosePledgedFirstRDOppsBatch.BATCH_SIZE);
        Test.stopTest();

        Opportunity result = reload(opp.Id);
        Assert.areEqual('Pledged', result.StageName, 'F2F opportunity should remain Pledged');
        Assert.areNotEqual('Closed', result.npe03__Recurring_Donation__r.npsp__Status__c, 'F2F recurring donation should not be Closed');
    }

    //BUG_EXCEPTION
    @isTest
    static void shouldCloseOppAndRd_WhenRecurringDonationCampaignIsNotF2F() {
        Opportunity opp = createRdWithCampaignAndOpp('Other Campaign Donor', 'Another Campaign');

        Test.startTest();
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), ClosePledgedFirstRDOppsBatch.BATCH_SIZE);
        Test.stopTest();

        Opportunity result = reload(opp.Id);
        Assert.areEqual('Closed Lost', result.StageName, 'Non F2F opportunity should be Closed Lost');
        Assert.areEqual('Closed', result.npe03__Recurring_Donation__r.npsp__Status__c, 'Non F2F recurring donation should be Closed');
    }

    //SFEUCMSD-130
    @isTest
    static void shouldBeScheduled_WhenSchedulableExecuted() {
        String cronTime = '0 0 1 * * ?';

        Test.startTest();
        Id jobId = System.schedule('ClosePledgedFirstRDOppsBatchTest', cronTime, new ClosePledgedFirstRDOppsBatch());
        Test.stopTest();

        CronTrigger trigger1 = [SELECT CronExpression FROM CronTrigger WHERE Id =: jobId];
        Assert.areEqual(cronTime, trigger1.CronExpression, 'Cron expression should match');
    }
}