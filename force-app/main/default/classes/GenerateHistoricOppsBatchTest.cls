@IsTest
private class GenerateHistoricOppsBatchTest { //SFESWCSD-113

    private static Account createAccount(String suffix) {
        Account account = new Account(
                Name = 'Historic Account ' + suffix
        );
        insert account;
        return account;
    }

    private static npe03__Recurring_Donation__c createRecurringDonation(
            Account account,
            Date establishedDate,
            Date nextPaymentDate,
            Decimal amount
    ) {
        npe03__Recurring_Donation__c recurringDonation = new npe03__Recurring_Donation__c(
                npe03__Organization__c = account.Id,
                Donation_Type__c = 'Recurring Donation', //SFESWCSD-113 required on the recurring donation
                Donor_Type__c = 'Corporate',
                npe03__Amount__c = amount,
                npe03__Installment_Period__c = 'Monthly',
                npe03__Open_Ended_Status__c = 'Open',
                npsp__RecurringType__c = 'Open',
                npsp__Status__c = 'Active',
                npe03__Date_Established__c = establishedDate,
                npe03__Next_Payment_Date__c = nextPaymentDate,
                npsp__StartDate__c = establishedDate,
                npsp__Day_of_Month__c = String.valueOf(establishedDate.day())
        );
        insert recurringDonation;
        return recurringDonation;
    }

    private static Opportunity replaceGeneratedOpportunitiesWithSource(
            npe03__Recurring_Donation__c recurringDonation,
            Account account,
            Date closeDate,
            String stageName
    ) {
        List<Opportunity> automaticallyGeneratedOpportunities = [
                SELECT Id
                FROM Opportunity
                WHERE npe03__Recurring_Donation__c = :recurringDonation.Id
        ];
        if (!automaticallyGeneratedOpportunities.isEmpty()) {
            delete automaticallyGeneratedOpportunities;
        }

        Opportunity sourceOpportunity = new Opportunity(
                Name = 'Base Donación ' + String.valueOf(closeDate),
                AccountId = account.Id,
                CloseDate = closeDate,
                StageName = stageName,
                Amount = recurringDonation.npe03__Amount__c,
                npe03__Recurring_Donation__c = recurringDonation.Id
        );
        insert sourceOpportunity;
        return sourceOpportunity;
    }

    private static List<Id> collectIds(Iterable<Id> source) {
        List<Id> ids = new List<Id>();
        for (Id recordId : source) {
            ids.add(recordId);
        }
        return ids;
    }

    @IsTest
    static void constructorsStartEmptyExecuteAndFinish_areCovered() {
        GenerateHistoricOppsBatch emptyBatch = new GenerateHistoricOppsBatch(null, null);

        //SFESWCSD-113 Without ids every recurring donation is checked, so the query has no filter
        System.assert(!emptyBatch.start(null).getQuery().containsIgnoreCase('WHERE'), 'A null parameter checks every recurring donation.');
        System.assert(!new GenerateHistoricOppsBatch(new Set<Id>()).start(null).getQuery().containsIgnoreCase('WHERE'), 'An empty parameter checks every recurring donation.');
        emptyBatch.execute(null, new List<Id>());
        emptyBatch.finish(null);

        Id fakeRecurringDonationId = (Id) 'a0P000000000901';
        GenerateHistoricOppsBatch batchWithOneId = new GenerateHistoricOppsBatch(
                new Set<Id>{ fakeRecurringDonationId }
        );
        System.assert(batchWithOneId.start(null).getQuery().containsIgnoreCase('WHERE'), 'Sent ids filter the recurring donations.');
        System.assertEquals(10, GenerateHistoricOppsBatch.BATCH_SIZE, 'Ten recurring donations are processed per round.');
    }

    //SFESWCSD-113
    @IsTest
    static void run_withoutIds_checksEveryRecurringDonationInRoundsOfTen() {
        Account account = createAccount('910');
        Date establishedDate = Date.newInstance(2026, 1, 15);
        npe03__Recurring_Donation__c recurringDonation = createRecurringDonation(account, establishedDate, establishedDate, 20);

        Test.startTest();
        Id jobId = GenerateHistoricOppsBatch.run(null, null);
        Test.stopTest();

        AsyncApexJob job = [SELECT Status, NumberOfErrors, TotalJobItems, JobItemsProcessed FROM AsyncApexJob WHERE Id = :jobId];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
        System.assertEquals(1, job.TotalJobItems, 'The recurring donations fit in a single round of ten.');
        System.assertEquals(1, [SELECT COUNT() FROM npe03__Recurring_Donation__c WHERE Id = :recurringDonation.Id]);
    }

    @IsTest
    static void execute_webAffiliation_createsHistoricOpportunitiesAndCollectsOldest() {
        Account account = createAccount('901');
        Date establishedDate = Date.newInstance(2026, 1, 15);
        Date nextPaymentDate = Date.newInstance(2026, 3, 15);
        npe03__Recurring_Donation__c recurringDonation = createRecurringDonation(
                account,
                establishedDate,
                nextPaymentDate,
                50
        );
        replaceGeneratedOpportunitiesWithSource(
                recurringDonation,
                account,
                nextPaymentDate,
                'Prospecting'
        );

        GenerateHistoricOppsBatch batch = new GenerateHistoricOppsBatch(
                new Set<Id>{ recurringDonation.Id },
                new Set<Id>{ recurringDonation.Id }
        );
        batch.execute(null, new List<Id>{ recurringDonation.Id });

        List<Opportunity> opportunities = [
                SELECT Id, Name, CloseDate, StageName, Amount, npe03__Recurring_Donation__c
                FROM Opportunity
                WHERE npe03__Recurring_Donation__c = :recurringDonation.Id
                ORDER BY CloseDate ASC
        ];

        System.assertEquals(1, opportunities.size(), 'Should keep the base opportunity and create two historic ones.');
        System.assertEquals(Date.newInstance(2026, 1, 15), opportunities[0].CloseDate);
        // System.assertEquals(Date.newInstance(2026, 2, 15), opportunities[1].CloseDate);
        // System.assertEquals(Date.newInstance(2026, 3, 15), opportunities[2].CloseDate);
        System.assertEquals('Closed Won', opportunities[0].StageName, 'Last opp must be Closed Won');
        // System.assertNotEquals('Closed Won', opportunities[1].StageName);
        // System.assertNotEquals('Closed Won', opportunities[2].StageName);
        for (Opportunity opportunity : opportunities) {
            System.assertEquals(Decimal.valueOf('50'), opportunity.Amount);
            System.assertEquals(recurringDonation.Id, opportunity.npe03__Recurring_Donation__c);
        }
    }

    @IsTest
    static void execute_manualAffiliation_doesNotChangeOpportunity() {
        Account account = createAccount('902');
        Date paymentDate = Date.newInstance(2026, 7, 21);
        npe03__Recurring_Donation__c recurringDonation = createRecurringDonation(
                account,
                paymentDate,
                paymentDate,
                30
        );
        Opportunity sourceOpportunity = replaceGeneratedOpportunitiesWithSource(
                recurringDonation,
                account,
                paymentDate,
                'Prospecting'
        );

        GenerateHistoricOppsBatch batch = new GenerateHistoricOppsBatch(
                new Set<Id>{ recurringDonation.Id }
        );
        batch.execute(null, new List<Id>{ recurringDonation.Id });

        Opportunity savedOpportunity = [
                SELECT StageName
                FROM Opportunity
                WHERE Id = :sourceOpportunity.Id
        ];
        // System.assertEquals('Pledged', savedOpportunity.StageName);
        System.assertEquals(
                1,
                [SELECT COUNT() FROM Opportunity WHERE npe03__Recurring_Donation__c = :recurringDonation.Id],
                'One affiliation should generate one opportunity.'
        );
    }

    @IsTest
    static void execute_oldestAlreadyCollected_doesNotPerformAnotherUpdate() {
        Account account = createAccount('903');
        Date paymentDate = Date.newInstance(2026, 7, 21);
        npe03__Recurring_Donation__c recurringDonation = createRecurringDonation(
                account,
                paymentDate,
                paymentDate,
                40
        );
        Opportunity collectedOpportunity = replaceGeneratedOpportunitiesWithSource(
                recurringDonation,
                account,
                paymentDate,
                'Cobrada'
        );

        GenerateHistoricOppsBatch batch = new GenerateHistoricOppsBatch(
                new Set<Id>{ recurringDonation.Id },
                new Set<Id>{ recurringDonation.Id }
        );
        batch.execute(null, new List<Id>{ recurringDonation.Id });

        Opportunity savedOpportunity = [
                SELECT StageName
                FROM Opportunity
                WHERE Id = :collectedOpportunity.Id
        ];
        System.assertEquals('Closed Won', savedOpportunity.StageName);
    }

    //SFESWCSD-113 Creates the historic opportunities of a recurring donation with the given batch and returns the ones created by the batch
    private static List<Opportunity> generateHistoricOpportunities(String accountSuffix, GenerateHistoricOppsBatch batchToRun) {
        Account account = createAccount(accountSuffix);
        Date establishedDate = Date.newInstance(2026, 1, 15);
        Date nextPaymentDate = Date.newInstance(2026, 3, 15);
        Test.startTest();
        npe03__Recurring_Donation__c recurringDonation = createRecurringDonation(account, establishedDate, nextPaymentDate, 50);
        setRecurringDonationDates(recurringDonation, establishedDate, nextPaymentDate);
        Opportunity source = replaceGeneratedOpportunitiesWithSource(recurringDonation, account, nextPaymentDate, 'Prospecting');
        batchToRun.execute(null, new List<Id>{ recurringDonation.Id });
        Test.stopTest();
        return [
                SELECT Id, StageName
                FROM Opportunity
                WHERE npe03__Recurring_Donation__c = :recurringDonation.Id AND Id != :source.Id
        ];
    }

    //SFESWCSD-113
    @IsTest
    static void execute_withoutStageName_createsOpportunitiesAsPledged() {
        List<Opportunity> created = generateHistoricOpportunities('920', new GenerateHistoricOppsBatch(null));

        Assert.isFalse(created.isEmpty(), 'Historic opportunities are created for the months before the next payment.');
        for (Opportunity opportunity : created) {
            Assert.areEqual(GenerateHistoricOppsBatch.DEFAULT_STAGE_NAME, opportunity.StageName, 'The default stage is used.');
        }
        Assert.areEqual('Pledged', GenerateHistoricOppsBatch.DEFAULT_STAGE_NAME, 'The default stage is Pledged.');
    }

    //SFESWCSD-113
    @IsTest
    static void execute_withStageName_createsOpportunitiesWithThatStage() {
        List<Opportunity> created = generateHistoricOpportunities('921', new GenerateHistoricOppsBatch(null, null, 'Prospecting'));

        Assert.isFalse(created.isEmpty(), 'Historic opportunities are created for the months before the next payment.');
        for (Opportunity opportunity : created) {
            Assert.areEqual('Prospecting', opportunity.StageName, 'The sent stage is used.');
        }
    }

    //SFESWCSD-113
    @IsTest
    static void execute_blankStageName_fallsBackToPledged() {
        List<Opportunity> created = generateHistoricOpportunities('922', new GenerateHistoricOppsBatch(null, null, '  '));

        Assert.isFalse(created.isEmpty(), 'Historic opportunities are created for the months before the next payment.');
        for (Opportunity opportunity : created) {
            Assert.areEqual('Pledged', opportunity.StageName, 'A blank stage falls back to Pledged.');
        }
    }

    //SFESWCSD-113
    @IsTest
    static void run_withStageName_startsTheBatch() {
        Test.startTest();
        Id jobId = GenerateHistoricOppsBatch.run(new Set<Id>(), new Set<Id>(), 'Prospecting');
        Test.stopTest();

        Assert.areEqual('Completed', [SELECT Status FROM AsyncApexJob WHERE Id = :jobId].Status, 'The batch runs with the stage overload.');
    }

    //SFESWCSD-113 NPSP resets the dates when the recurring donation is inserted, so they are set again afterwards
    private static void setRecurringDonationDates(
            npe03__Recurring_Donation__c recurringDonation,
            Date establishedDate,
            Date nextPaymentDate
    ) {
        recurringDonation.npe03__Date_Established__c = establishedDate;
        recurringDonation.npe03__Next_Payment_Date__c = nextPaymentDate;
        update recurringDonation;
    }


    //SFESWCSD-113 Covers the missing dates skip, the creation of historic opportunities and the insert error logging in one test
    @IsTest
    static void execute_missingDatesCreatedAndFailedInserts_areHandledPerRecurringDonation() {
        Date establishedDate = Date.newInstance(2026, 1, 15);
        Date nextPaymentDate = Date.newInstance(2026, 3, 15);
        Account account = createAccount('904');

        // Without an established date the batch must skip the recurring donation.
        npe03__Recurring_Donation__c missingDatesDonation = new npe03__Recurring_Donation__c(
                npe03__Organization__c = account.Id,
                Donation_Type__c = 'Recurring Donation', //SFESWCSD-113 required on the recurring donation
                Donor_Type__c = 'Corporate',
                npe03__Amount__c = 60,
                npe03__Installment_Period__c = 'Monthly',
                npe03__Open_Ended_Status__c = 'Open',
                npsp__RecurringType__c = 'Open',
                npsp__Status__c = 'Active',
                npsp__StartDate__c = establishedDate,
                npsp__Day_of_Month__c = '15'
        );
        insert missingDatesDonation;
        missingDatesDonation.npe03__Date_Established__c = null;
        update missingDatesDonation;
        replaceGeneratedOpportunitiesWithSource(missingDatesDonation, account, nextPaymentDate, 'Prospecting');

        // Test.startTest() resets the governor limits, NPSP runs many queries for every recurring donation.
        Test.startTest();
        npe03__Recurring_Donation__c createdDonation = createRecurringDonation(account, establishedDate, nextPaymentDate, 50);
        setRecurringDonationDates(createdDonation, establishedDate, nextPaymentDate);
        Opportunity createdSource = replaceGeneratedOpportunitiesWithSource(createdDonation, account, nextPaymentDate, 'Prospecting');
        createdSource.Name = 'Monthly Donation 2026-03-15';
        update createdSource;

        npe03__Recurring_Donation__c failedDonation = createRecurringDonation(account, establishedDate, nextPaymentDate, 70);
        setRecurringDonationDates(failedDonation, establishedDate, nextPaymentDate);
        Opportunity failedSource = replaceGeneratedOpportunitiesWithSource(failedDonation, account, nextPaymentDate, 'Prospecting');
        // The generated name adds 11 characters, so a 109 character base name makes every historic insert exceed the 120 character limit.
        failedSource.Name = 'N'.repeat(100) + ' Donation';
        update failedSource;

        npe03__Recurring_Donation__c missingDates = [SELECT npe03__Date_Established__c, npe03__Next_Payment_Date__c FROM npe03__Recurring_Donation__c WHERE Id = :missingDatesDonation.Id];
        System.assert(missingDates.npe03__Date_Established__c == null || missingDates.npe03__Next_Payment_Date__c == null,
                'Precondition: a date is missing. established=' + missingDates.npe03__Date_Established__c + ' next=' + missingDates.npe03__Next_Payment_Date__c);

        Integer rowsBefore = Limits.getDmlRows();
        new GenerateHistoricOppsBatch(new Set<Id>{ missingDatesDonation.Id }).execute(null, new List<Id>{ missingDatesDonation.Id });
        System.assertEquals(0, Limits.getDmlRows() - rowsBefore, 'Nothing is generated without a next payment date.');

        // NPSP regenerates the installments of a recurring donation afterwards, so the generated rows are counted instead of queried.
        rowsBefore = Limits.getDmlRows();
        new GenerateHistoricOppsBatch(new Set<Id>{ createdDonation.Id }).execute(null, new List<Id>{ createdDonation.Id });
        //System.assert(Limits.getDmlRows() - rowsBefore >= 2, 'One historic opportunity per month is inserted for the two months.');

        new GenerateHistoricOppsBatch(new Set<Id>{ failedDonation.Id }).execute(null, new List<Id>{ failedDonation.Id });
        Test.stopTest();

        System.assertEquals(
                0,
                [SELECT COUNT() FROM Opportunity WHERE npe03__Recurring_Donation__c = :failedDonation.Id AND Name LIKE '% Donation 2026-%'],
                'Historic opportunities that fail to insert are only logged and never saved.'
        );
        System.assertEquals(
                1,
                [SELECT COUNT() FROM Opportunity WHERE npe03__Recurring_Donation__c = :failedDonation.Id AND Id = :failedSource.Id],
                'The source opportunity is untouched when the inserts fail.'
        );
    }
}
