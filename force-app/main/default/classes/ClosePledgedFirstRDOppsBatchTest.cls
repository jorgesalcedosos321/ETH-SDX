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
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), 100);
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
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), 100);
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
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), 100);
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
        Database.executeBatch(new ClosePledgedFirstRDOppsBatch(), 100);
        Test.stopTest();

        Opportunity result = reload(opp.Id);
        Assert.areEqual('Closed Won', result.StageName, 'Posted opportunity should be untouched');
        Assert.areNotEqual('Closed', result.npe03__Recurring_Donation__r.npsp__Status__c, 'Recurring donation should not be Closed');
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
