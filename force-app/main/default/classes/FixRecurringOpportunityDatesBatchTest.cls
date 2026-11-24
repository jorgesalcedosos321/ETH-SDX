//SFEUCMSD-147
@IsTest
private class FixRecurringOpportunityDatesBatchTest {

    //SFEUCMSD-147 Creates a recurring donation with the given Day of Month and replaces the opportunities NPSP generates with the given dates and stages
    private static npe03__Recurring_Donation__c createDonationWithOpportunities(String dayOfMonth, Map<Date, String> stageByDate) {
        Account account = new Account(Name = 'Fix Dates Account');
        insert account;
        npe03__Recurring_Donation__c donation = new npe03__Recurring_Donation__c(
            npe03__Amount__c = 100,
            npe03__Organization__c = account.Id,
            npe03__Open_Ended_Status__c = 'Open',
            Donor_Type__c = 'Individual',
            Donation_Type__c = 'Recurring Donation'
        );
        insert donation;
        //SFEUCMSD-147 NPSP parses the Day of Month as a number when other fields change in tests, so it is set alone
        update new npe03__Recurring_Donation__c(Id = donation.Id, npsp__Day_of_Month__c = dayOfMonth);
        delete [SELECT Id FROM Opportunity WHERE npe03__Recurring_Donation__c = :donation.Id];

        List<Opportunity> opportunities = new List<Opportunity>();
        for (Date closeDate : stageByDate.keySet()) {
            opportunities.add(new Opportunity(
                AccountId = account.Id,
                Name = 'Donor P100 Donation ' + String.valueOf(closeDate),
                StageName = 'Pledged',
                Amount = 100,
                CloseDate = closeDate,
                npe03__Recurring_Donation__c = donation.Id
            ));
        }
        insert opportunities;

        //SFEUCMSD-147 The first opportunity of a donation takes the established date on insert, so the dates and stages are set again afterwards
        List<npe01__OppPayment__c> payments = new List<npe01__OppPayment__c>();
        for (Opportunity opportunity : opportunities) {
            Date closeDate = Date.valueOf(opportunity.Name.substringAfterLast(' '));
            opportunity.CloseDate = closeDate;
            opportunity.StageName = stageByDate.get(closeDate);
        }
        update opportunities;
        delete [SELECT Id FROM npe01__OppPayment__c WHERE npe01__Opportunity__c IN :opportunities];
        for (Opportunity opportunity : opportunities) {
            payments.add(new npe01__OppPayment__c(
                npe01__Opportunity__c = opportunity.Id,
                npe01__Payment_Amount__c = 100,
                npe01__Scheduled_Date__c = opportunity.CloseDate
            ));
        }
        insert payments;
        return donation;
    }

    //SFEUCMSD-147 The dates of the Gobitsa Mogale donation in production, plus a lone December 1st and a collected May 1st that must not move
    private static Map<Date, String> getProductionLikeDates() {
        return new Map<Date, String>{
            Date.newInstance(2025, 5, 31) => 'Closed Lost',
            Date.newInstance(2025, 7, 1) => 'Pledged',
            Date.newInstance(2025, 7, 31) => 'Pledged',
            Date.newInstance(2025, 8, 31) => 'Pledged',
            Date.newInstance(2025, 10, 1) => 'Pledged',
            Date.newInstance(2025, 10, 31) => 'Pledged',
            Date.newInstance(2025, 12, 1) => 'Pledged',
            Date.newInstance(2026, 3, 3) => 'Pledged',
            Date.newInstance(2026, 3, 31) => 'Pledged',
            Date.newInstance(2026, 5, 1) => 'Closed Won',
            Date.newInstance(2026, 5, 31) => 'Pledged'
        };
    }

    private static Map<String, Opportunity> getOpportunitiesByOriginalName(Id donationId) {
        Map<String, Opportunity> result = new Map<String, Opportunity>();
        for (Opportunity opportunity : [
            SELECT Id, Name, CloseDate, (SELECT npe01__Scheduled_Date__c FROM npe01__OppPayment__r)
            FROM Opportunity WHERE npe03__Recurring_Donation__c = :donationId
        ]) {
            result.put(opportunity.Name, opportunity);
        }
        return result;
    }

    //SFEUCMSD-147
    @IsTest
    static void fixDates_lastDayRolledOver_movesToLastDayOfPreviousMonth() {
        npe03__Recurring_Donation__c donation = createDonationWithOpportunities(Utils.LAST_DAY_OF_MONTH, getProductionLikeDates());

        Test.startTest();
        List<FixRecurringOpportunityDatesBatch.DateFix> fixes = FixRecurringOpportunityDatesBatch.fixDates(new Set<Id>{ donation.Id }, false);
        Test.stopTest();

        Assert.areEqual(3, fixes.size(), 'July 1st, October 1st and March 3rd rolled over: ' + fixes);
        Map<String, Opportunity> opportunitiesByName = getOpportunitiesByOriginalName(donation.Id);
        Assert.areEqual(Date.newInstance(2025, 6, 30), opportunitiesByName.get('Donor P100 Donation 2025-06-30')?.CloseDate, 'July 1st goes back to June 30th with its name.');
        Assert.areEqual(Date.newInstance(2025, 9, 30), opportunitiesByName.get('Donor P100 Donation 2025-09-30')?.CloseDate, 'October 1st goes back to September 30th with its name.');
        Assert.areEqual(Date.newInstance(2026, 2, 28), opportunitiesByName.get('Donor P100 Donation 2026-02-28')?.CloseDate, 'March 3rd goes back to February 28th with its name.');
        Assert.areEqual(Date.newInstance(2026, 2, 28), opportunitiesByName.get('Donor P100 Donation 2026-02-28').npe01__OppPayment__r[0].npe01__Scheduled_Date__c, 'The unpaid payment moves with its opportunity.');
    }

    //SFEUCMSD-147
    @IsTest
    static void fixDates_loneOrCollectedOpportunities_areNotMoved() {
        npe03__Recurring_Donation__c donation = createDonationWithOpportunities(Utils.LAST_DAY_OF_MONTH, getProductionLikeDates());

        Test.startTest();
        FixRecurringOpportunityDatesBatch.fixDates(new Set<Id>{ donation.Id }, false);
        Test.stopTest();

        Map<String, Opportunity> opportunitiesByName = getOpportunitiesByOriginalName(donation.Id);
        Assert.areEqual(Date.newInstance(2025, 12, 1), opportunitiesByName.get('Donor P100 Donation 2025-12-01')?.CloseDate, 'December 1st is the only opportunity of December, so it is not a duplicate and stays.');
        Assert.areEqual(Date.newInstance(2026, 5, 1), opportunitiesByName.get('Donor P100 Donation 2026-05-01')?.CloseDate, 'A collected opportunity keeps the date of its payment.');
        Assert.areEqual(Date.newInstance(2025, 7, 31), opportunitiesByName.get('Donor P100 Donation 2025-07-31')?.CloseDate, 'Opportunities on the right day stay.');
    }

    //SFEUCMSD-147
    @IsTest
    static void fixDates_previewOnly_changesNothing() {
        npe03__Recurring_Donation__c donation = createDonationWithOpportunities(Utils.LAST_DAY_OF_MONTH, getProductionLikeDates());

        Test.startTest();
        List<FixRecurringOpportunityDatesBatch.DateFix> fixes = FixRecurringOpportunityDatesBatch.fixDates(new Set<Id>{ donation.Id }, true);
        Test.stopTest();

        Assert.areEqual(3, fixes.size(), 'The preview finds the same three opportunities.');
        Assert.areEqual(Date.newInstance(2025, 6, 30), fixes[0].newDate, 'The preview shows the new date.');
        Assert.isTrue(String.valueOf(fixes[0]).contains('2025-07-01'), 'The preview shows the old date.');
        Assert.isTrue(getOpportunitiesByOriginalName(donation.Id).containsKey('Donor P100 Donation 2025-07-01'), 'Nothing is saved in preview.');
    }

    //SFEUCMSD-147
    @IsTest
    static void fixDates_day30InFebruary_movesMarch2ndToFebruary28th() {
        npe03__Recurring_Donation__c donation = createDonationWithOpportunities('30', new Map<Date, String>{
            Date.newInstance(2026, 1, 30) => 'Pledged',
            Date.newInstance(2026, 3, 2) => 'Pledged',
            Date.newInstance(2026, 3, 30) => 'Pledged'
        });

        Test.startTest();
        List<FixRecurringOpportunityDatesBatch.DateFix> fixes = FixRecurringOpportunityDatesBatch.fixDates(new Set<Id>{ donation.Id }, false);
        Test.stopTest();

        Assert.areEqual(1, fixes.size(), 'Only March 2nd rolled over.');
        Assert.areEqual(Date.newInstance(2026, 2, 28), [SELECT CloseDate FROM Opportunity WHERE Id = :fixes[0].opportunityId].CloseDate, 'Day 30 falls on February 28th.');
    }

    //SFEUCMSD-147
    @IsTest
    static void fixDates_dayThatCannotRollOver_findsNothing() {
        npe03__Recurring_Donation__c donation = createDonationWithOpportunities('15', new Map<Date, String>{
            Date.newInstance(2026, 3, 1) => 'Pledged',
            Date.newInstance(2026, 3, 15) => 'Pledged'
        });

        Test.startTest();
        List<FixRecurringOpportunityDatesBatch.DateFix> fixes = FixRecurringOpportunityDatesBatch.fixDates(new Set<Id>{ donation.Id }, false);
        Test.stopTest();

        Assert.areEqual(0, fixes.size(), 'A day 15 donation never rolls into the next month.');
    }

    //SFEUCMSD-147
    @IsTest
    static void fixDates_noIds_findsNothing() {
        Assert.areEqual(0, FixRecurringOpportunityDatesBatch.fixDates(null, false).size(), 'Without ids nothing is checked.');
        Assert.areEqual(0, FixRecurringOpportunityDatesBatch.fixDates(new Set<Id>(), false).size(), 'Without ids nothing is checked.');
    }

    //SFEUCMSD-147
    @IsTest
    static void batch_withIds_fixesTheDonation() {
        npe03__Recurring_Donation__c donation = createDonationWithOpportunities(Utils.LAST_DAY_OF_MONTH, getProductionLikeDates());

        Test.startTest();
        Database.executeBatch(new FixRecurringOpportunityDatesBatch(new Set<Id>{ donation.Id }, false), FixRecurringOpportunityDatesBatch.BATCH_SIZE);
        Test.stopTest();

        Assert.isTrue(getOpportunitiesByOriginalName(donation.Id).containsKey('Donor P100 Donation 2025-06-30'), 'The batch moves July 1st to June 30th.');
    }

    //SFEUCMSD-147
    @IsTest
    static void batch_withoutIds_checksDonationsThatCanRollOver() {
        FixRecurringOpportunityDatesBatch batch = new FixRecurringOpportunityDatesBatch(null, true);

        String query = batch.start(null).getQuery();

        Assert.isTrue(query.containsIgnoreCase('npsp__Day_of_Month__c'), 'Only donations with Day of Month 29, 30 or Last_Day are checked.');
        Assert.isFalse(query.containsIgnoreCase('Id IN'), 'Without ids the batch does not filter by id.');
    }

    //SFEUCMSD-147
    @IsTest
    static void replaceNameDate_nameWithoutDate_keepsName() {
        Assert.areEqual('Monthly gift', FixRecurringOpportunityDatesBatch.replaceNameDate('Monthly gift', Date.newInstance(2025, 7, 1), Date.newInstance(2025, 6, 30)), 'A name without the old date is kept.');
        Assert.areEqual('Gift 2025-06-30', FixRecurringOpportunityDatesBatch.replaceNameDate('Gift 2025-07-01', Date.newInstance(2025, 7, 1), Date.newInstance(2025, 6, 30)), 'The trailing date is replaced.');
    }

    //SFEUCMSD-147 Ethiopia opportunity names end with the date as dd/MM/yyyy
    @IsTest
    static void replaceNameDate_ethiopiaNameFormat_keepsFormat() {
        Assert.areEqual('Gift Donation 30/06/2025', FixRecurringOpportunityDatesBatch.replaceNameDate('Gift Donation 01/07/2025', Date.newInstance(2025, 7, 1), Date.newInstance(2025, 6, 30)), 'A dd/MM/yyyy name keeps its format with the new date.');
    }

    //SFEUCMSD-147 Ethiopia also allows Day of Month 31
    @IsTest
    static void fixDates_day31_movesJuly1stToJune30th() {
        npe03__Recurring_Donation__c donation = createDonationWithOpportunities('31', new Map<Date, String>{
            Date.newInstance(2025, 5, 31) => 'Pledged',
            Date.newInstance(2025, 7, 1) => 'Pledged',
            Date.newInstance(2025, 7, 31) => 'Pledged'
        });

        Test.startTest();
        List<FixRecurringOpportunityDatesBatch.DateFix> fixes = FixRecurringOpportunityDatesBatch.fixDates(new Set<Id>{ donation.Id }, false);
        Test.stopTest();

        Assert.areEqual(1, fixes.size(), 'Only July 1st rolled over.');
        Assert.areEqual(Date.newInstance(2025, 6, 30), [SELECT CloseDate FROM Opportunity WHERE Id = :fixes[0].opportunityId].CloseDate, 'Day 31 falls on June 30th.');
    }
}
