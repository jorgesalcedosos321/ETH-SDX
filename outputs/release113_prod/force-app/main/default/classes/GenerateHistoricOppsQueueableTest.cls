//SFESWCSD-113
@IsTest
private class GenerateHistoricOppsQueueableTest {

    //SFESWCSD-113
    private static Integer countJobs(String className) {
        return [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = :className AND JobType IN ('BatchApex', 'Queueable')];
    }

    //SFESWCSD-113 The batch only needs a syntactically valid recurring donation id
    private static Id fakeRecurringDonationId() {
        return Id.valueOf(npe03__Recurring_Donation__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
    }

    //SFESWCSD-113
    @IsTest
    static void execute_withRecurringDonationIds_startsTheBatch() {
        Integer batchJobsBefore = countJobs('GenerateHistoricOppsBatch');

        Test.startTest();
        new GenerateHistoricOppsQueueable(new Set<Id>{ fakeRecurringDonationId() }).execute(null);
        Test.stopTest();

        Assert.areEqual(batchJobsBefore + 1, countJobs('GenerateHistoricOppsBatch'), 'The queueable starts one batch job.');
    }

    //SFESWCSD-113
    @IsTest
    static void execute_withoutIds_doesNotStartTheBatch() {
        Integer batchJobsBefore = countJobs('GenerateHistoricOppsBatch');

        Test.startTest();
        new GenerateHistoricOppsQueueable(null).execute(null);
        new GenerateHistoricOppsQueueable(new Set<Id>()).execute(null);
        Test.stopTest();

        Assert.areEqual(batchJobsBefore, countJobs('GenerateHistoricOppsBatch'), 'No batch job is started without ids.');
    }
}
