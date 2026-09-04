/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class SendEmailNotificationBatchTest {

    @testSetup
    static void setupData() {
        Account account = new Account(Name = 'Email batch test');
        insert account;
        insert new List<Contact>{
            new Contact(
                FirstName = 'Eligible',
                LastName = 'Donor',
                AccountId = account.Id,
                Email = 'eligible@example.com',
                Birthdate = Date.today()
            ),
            new Contact(
                FirstName = 'No email',
                LastName = 'Donor',
                AccountId = account.Id,
                Birthdate = Date.today()
            )
        };
    }

    @isTest
    static void buildsOneTimeDonorTargetsWithOpportunityWhatId() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        List<Contact> contacts = [SELECT Id, Email FROM Contact ORDER BY Email NULLS LAST];
        Contact primaryContact = contacts[0];
        Contact fallbackContact = contacts[1];
        Opportunity primaryOpportunity = createOpportunity(
            account.Id,
            primaryContact.Id,
            'Closed Won'
        );
        Opportunity fallbackOpportunity = createOpportunity(
            account.Id,
            fallbackContact.Id,
            'Closed Won'
        );
        fallbackOpportunity.npsp__Primary_Contact__c = null;

        Map<Id, Id> targets = SendEmailNotificationBatch.buildTargets(
            Utils.ONE_TIME_DONORS_LE,
            new List<sObject>{ primaryOpportunity, fallbackOpportunity }
        );

        System.assertEquals(primaryOpportunity.Id, targets.get(primaryContact.Id));
        System.assertEquals(fallbackOpportunity.Id, targets.get(fallbackContact.Id));
    }

    @isTest
    static void buildsContactTargetsOnlyWhenEmailExists() {
        List<Contact> contacts = [SELECT Id, Email FROM Contact];
        List<sObject> scope = new List<sObject>();
        for (Contact contact : contacts) {
            scope.add(contact);
        }

        Map<Id, Id> targets = SendEmailNotificationBatch.buildTargets(
            Utils.BIRTHDAY_EMAIL,
            scope
        );

        System.assertEquals(1, targets.size());
        System.assert(targets.containsKey([SELECT Id FROM Contact WHERE Email != null LIMIT 1].Id));
    }

    @isTest
    static void supportsAllContactTemplateSelectors() {
        Contact contact = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        List<String> templateKeys = new List<String>{ Utils.BIRTHDAY_EMAIL };

        for (String templateKey : templateKeys) {
            Set<Id> selectedIds = queryLocatorIds(
                new SendEmailNotificationBatch(templateKey).start(null)
            );
            System.assert(
                selectedIds.contains(contact.Id),
                'Expected contact for template ' + templateKey
            );
        }
    }

    @isTest
    static void selectsOneTimeDonationsCreatedOneMonthAgoForLe() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        Opportunity eligible = createOpportunity(
            account.Id,
            contact.Id,
            'Closed Won'
        );
        Opportunity tooRecent = createOpportunity(
            account.Id,
            contact.Id,
            'Closed Won'
        );
        Opportunity wrongDonationType = createOpportunity(
            account.Id,
            contact.Id,
            'Closed Won'
        );
        wrongDonationType.Donation_Type__c = 'Recurring Donation';
        update wrongDonationType;

        Datetime oneMonthAgo = Datetime.newInstance(
            Date.today().addMonths(-1),
            Time.newInstance(12, 0, 0, 0)
        );
        Test.setCreatedDate(eligible.Id, oneMonthAgo);
        Test.setCreatedDate(wrongDonationType.Id, oneMonthAgo);

        Set<Id> selectedIds = queryLocatorIds(
            new SendEmailNotificationBatch(Utils.ONE_TIME_DONORS_LE).start(null)
        );

        System.assertEquals(new Set<Id>{ eligible.Id }, selectedIds);
        System.assert(!selectedIds.contains(tooRecent.Id));
        System.assert(!selectedIds.contains(wrongDonationType.Id));
    }

    @isTest
    static void calculatesOneMonthAnniversaryWithoutMonthEndDuplicates() {
        List<Datetime> februaryLastDay =
            SendEmailNotificationBatch.oneMonthAnniversaryWindow(
                Date.newInstance(2025, 2, 28)
            );
        System.assertEquals(
            Datetime.newInstance(2025, 1, 28, 0, 0, 0),
            februaryLastDay[0]
        );
        System.assertEquals(
            Datetime.newInstance(2025, 2, 1, 0, 0, 0),
            februaryLastDay[1]
        );

        List<Datetime> marchExtraDay =
            SendEmailNotificationBatch.oneMonthAnniversaryWindow(
                Date.newInstance(2025, 3, 29)
            );
        System.assertEquals(marchExtraDay[0], marchExtraDay[1]);

        List<Datetime> marchLastDay =
            SendEmailNotificationBatch.oneMonthAnniversaryWindow(
                Date.newInstance(2025, 3, 31)
            );
        System.assertEquals(marchLastDay[0], marchLastDay[1]);
    }

    @isTest
    static void selectsOnlySixConsecutiveSuccessfulPaymentsForLoyaltyCall() {
        List<Opportunity> sixSuccessful = loyaltyOpportunities(6, null);

        Opportunity sixthPayment =
            SendEmailNotificationBatch.getSixthConsecutivePayment(sixSuccessful);

        System.assertEquals(sixSuccessful[5].Id, sixthPayment.Id);
        System.assertEquals(
            null,
            SendEmailNotificationBatch.getSixthConsecutivePayment(
                loyaltyOpportunities(5, null)
            ),
            'Fewer than six payments must not qualify'
        );
        System.assertEquals(
            null,
            SendEmailNotificationBatch.getSixthConsecutivePayment(
                loyaltyOpportunities(7, null)
            ),
            'A seventh payment must not send the loyalty email again'
        );
        System.assertEquals(
            null,
            SendEmailNotificationBatch.getSixthConsecutivePayment(
                loyaltyOpportunities(6, 3)
            ),
            'A failed payment must break the successful sequence'
        );
    }

    @isTest
    static void rejectsNonSequentialLoyaltyPayments() {
        List<Opportunity> opportunities = loyaltyOpportunities(6, null);
        opportunities[3].npsp__Recurring_Donation_Installment_Number__c = 5;

        System.assertEquals(
            null,
            SendEmailNotificationBatch.getSixthConsecutivePayment(opportunities)
        );
    }

    @isTest
    static void buildsLoyaltyTargetFromSixPaidInstallments() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        npe03__Recurring_Donation__c recurringDonation =
            createSponsorship(contact.Id);

        List<Opportunity> paidInstallments = createPaidInstallments(
            account.Id,
            contact.Id,
            recurringDonation.Id,
            6
        );

        List<sObject> candidates = new List<sObject>();
        Database.QueryLocatorIterator records =
            new SendEmailNotificationBatch(
                Utils.LOYALTY_CALL_AFTER_6
            ).start(null).iterator();
        while (records.hasNext()) {
            sObject candidate = records.next();
            if (candidate.Id == recurringDonation.Id) {
                candidates.add(candidate);
            }
        }

        Map<Id, Id> targets = SendEmailNotificationBatch.buildTargets(
            Utils.LOYALTY_CALL_AFTER_6,
            candidates
        );

        System.assertEquals(1, targets.size());
        System.assertEquals(paidInstallments[5].Id, targets.get(contact.Id));
    }

    @isTest
    static void executesLoyaltyBatchForQualifiedDonor() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        npe03__Recurring_Donation__c recurringDonation =
            createSponsorship(contact.Id);
        createPaidInstallments(account.Id, contact.Id, recurringDonation.Id, 6);

        Test.startTest();
        Id jobId = Database.executeBatch(
            new SendEmailNotificationBatch(Utils.LOYALTY_CALL_AFTER_6),
            10
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors, JobItemsProcessed, TotalJobItems
            FROM AsyncApexJob
            WHERE Id = :jobId
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
        System.assertEquals(job.TotalJobItems, job.JobItemsProcessed);
    }

    //SFESWCSD-85 case 6
    @isTest
    static void selectsContactsWithActiveSponsorshipsForMidYearReport() {
        Contact eligibleContact = [
            SELECT Id
            FROM Contact
            WHERE Email != null
            LIMIT 1
        ];
        createSponsorship(eligibleContact.Id);

        Set<Id> selectedIds = queryLocatorIds(
            new SendEmailNotificationBatch(
                Utils.MID_YEAR_REPORT_PDF
            ).start(null)
        );

        System.assertEquals(new Set<Id>{ eligibleContact.Id }, selectedIds);
    }

    @isTest
    static void reportSelectorsExcludeInactiveSponsorshipsAndMissingEmails() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Contact inactiveContact = new Contact(
            FirstName = 'Inactive',
            LastName = 'Sponsor',
            AccountId = account.Id,
            Email = 'inactive@example.com'
        );
        insert inactiveContact;
        npe03__Recurring_Donation__c inactiveSponsorship =
            createSponsorship(inactiveContact.Id);
        inactiveSponsorship.npsp__Status__c = 'Closed';
        update inactiveSponsorship;

        Contact missingEmailContact = [
            SELECT Id
            FROM Contact
            WHERE Email = null
            LIMIT 1
        ];
        createSponsorship(missingEmailContact.Id);

        for (String templateKey : new List<String>{
            Utils.MID_YEAR_REPORT_PDF,
            Utils.END_OF_YEAR_REPORT_P
        }) {
            Set<Id> selectedIds = queryLocatorIds(
                new SendEmailNotificationBatch(templateKey).start(null)
            );
            System.assert(!selectedIds.contains(inactiveContact.Id));
            System.assert(!selectedIds.contains(missingEmailContact.Id));
        }
    }

    //SFESWCSD-85 case 7
    @isTest
    static void selectsContactsWithActiveSponsorshipsForEndOfYearReport() {
        Contact eligibleContact = [
            SELECT Id
            FROM Contact
            WHERE Email != null
            LIMIT 1
        ];
        createSponsorship(eligibleContact.Id);

        Set<Id> selectedIds = queryLocatorIds(
            new SendEmailNotificationBatch(
                Utils.END_OF_YEAR_REPORT_P
            ).start(null)
        );

        System.assertEquals(new Set<Id>{ eligibleContact.Id }, selectedIds);
    }

    //SFESWCSD-85 case 8
    //SFESWCSD-85 case 9
    //SFESWCSD-85 case 10
    @isTest
    static void evaluatesConsecutiveMissedPaymentReminders() {
        Date firstMissedDate = Date.today().addMonths(-1);
        Opportunity firstMiss = new Opportunity(
            Id = Id.valueOf('006000000000011'),
            StageName = 'Closed Lost',
            CloseDate = firstMissedDate
        );
        Opportunity secondMiss = new Opportunity(
            Id = Id.valueOf('006000000000012'),
            StageName = 'Declined',
            CloseDate = Date.today().addMonths(-2)
        );
        Opportunity thirdMiss = new Opportunity(
            Id = Id.valueOf('006000000000013'),
            StageName = 'Missed',
            CloseDate = Date.today().addMonths(-3)
        );

        System.assertEquals(
            firstMiss.Id,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ firstMiss },
                1,
                Date.today()
            ).Id
        );
        System.assertEquals(
            firstMiss.Id,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ firstMiss, secondMiss },
                2,
                Date.today()
            ).Id
        );
        System.assertEquals(
            firstMiss.Id,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ firstMiss, secondMiss, thirdMiss },
                3,
                Date.today()
            ).Id
        );
        System.assertEquals(
            null,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ firstMiss, secondMiss, thirdMiss },
                1,
                Date.today()
            ),
            'Three misses must not send REMINDER_1'
        );
        System.assertEquals(
            null,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ firstMiss, secondMiss, thirdMiss },
                2,
                Date.today()
            ),
            'Three misses must not send REMINDER_2'
        );
        Opportunity fourthMiss = new Opportunity(
            Id = Id.valueOf('006000000000014'),
            StageName = 'Declined',
            CloseDate = Date.today().addMonths(-4)
        );
        List<Opportunity> fourMisses = new List<Opportunity>{
            firstMiss,
            secondMiss,
            thirdMiss,
            fourthMiss
        };
        for (Integer reminderNumber : new List<Integer>{ 1, 2, 3 }) {
            System.assertEquals(
                null,
                SendEmailNotificationBatch.getReminderOpportunity(
                    fourMisses,
                    reminderNumber,
                    Date.today()
                ),
                'Four misses must not send REMINDER_' + reminderNumber
            );
        }
        System.assertEquals(
            null,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{
                    new Opportunity(
                        StageName = 'Closed Won',
                        CloseDate = firstMissedDate
                    ),
                    firstMiss
                },
                1,
                Date.today()
            )
        );
        System.assertEquals(
            null,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ firstMiss },
                1,
                Date.today().addMonths(1)
            ),
            'Reminder must run in the calendar month after the missed payment'
        );
        Opportunity gapInPayments = new Opportunity(
            Id = Id.valueOf('006000000000015'),
            StageName = 'Missed',
            CloseDate = Date.today().addMonths(-3)
        );
        System.assertEquals(
            null,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ firstMiss, gapInPayments },
                2,
                Date.today()
            ),
            'REMINDER_2 requires misses in each of the previous two months'
        );
    }

    //SFESWCSD-85 case 5
    @isTest
    static void selectsOnlyTheFirstSponsorshipOnItsAnniversary() {
        Contact contact = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        npe03__Recurring_Donation__c firstSponsorship =
            createSponsorship(contact.Id);
        npe03__Recurring_Donation__c laterSponsorship =
            createSponsorship(contact.Id);
        Test.setCreatedDate(
            firstSponsorship.Id,
            Datetime.newInstance(
                Date.today().addYears(-2),
                Time.newInstance(10, 0, 0, 0)
            )
        );
        Test.setCreatedDate(
            laterSponsorship.Id,
            Datetime.newInstance(
                Date.today().addYears(-1),
                Time.newInstance(10, 0, 0, 0)
            )
        );

        SendEmailNotificationBatch batch = new SendEmailNotificationBatch(
            Utils.ANNIVERSARY_EMAIL_1
        );
        Database.QueryLocatorIterator records = batch.start(null).iterator();
        List<sObject> candidates = new List<sObject>();
        while (records.hasNext()) {
            candidates.add(records.next());
        }
        Map<Id, Id> targets = SendEmailNotificationBatch.buildTargets(
            Utils.ANNIVERSARY_EMAIL_1,
            candidates
        );

        System.assertEquals(1, targets.size());
        System.assertEquals(firstSponsorship.Id, targets.get(contact.Id));
    }

    @isTest
    static void rejectsEmptyTemplateKey() {
        try {
            new SendEmailNotificationBatch('').start(null);
            System.assert(false, 'An empty template key must be rejected');
        } catch (IllegalArgumentException exceptionRecord) {
            System.assertEquals('Invalid template key: ', exceptionRecord.getMessage());
        }
    }

    @isTest
    static void emptyScopesAndFinishAreSafe() {
        SendEmailNotificationBatch oneTimeBatch = new SendEmailNotificationBatch(
            Utils.ONE_TIME_DONORS_LE
        );
        oneTimeBatch.execute(null, new List<sObject>());
        oneTimeBatch.finish(null);

        SendEmailNotificationBatch contactBatch = new SendEmailNotificationBatch(
            Utils.BIRTHDAY_EMAIL
        );
        contactBatch.execute(null, new List<sObject>());
        contactBatch.finish(null);
    }

    private static Set<Id> queryLocatorIds(Database.QueryLocator locator) {
        Database.QueryLocatorIterator records = locator.iterator();
        Set<Id> selectedIds = new Set<Id>();
        while (records.hasNext()) {
            selectedIds.add(((sObject) records.next()).Id);
        }
        return selectedIds;
    }

    private static Opportunity createOpportunity(
        Id accountId,
        Id contactId,
        String stageName
    ) {
        Opportunity opportunity = new Opportunity(
            Name = 'One-time donation ' + stageName,
            AccountId = accountId,
            ContactId = contactId,
            npsp__Primary_Contact__c = contactId,
            StageName = stageName,
            CloseDate = Date.today(),
            Donation_Type__c = 'One-time Donation'
        );
        insert opportunity;
        return opportunity;
    }

    private static List<Opportunity> loyaltyOpportunities(
        Integer count,
        Integer failedInstallment
    ) {
        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer installment = 1; installment <= count; installment++) {
            opportunities.add(new Opportunity(
                Id = Id.valueOf(
                    '006000000000' + String.valueOf(installment).leftPad(3, '0')
                ),
                StageName = installment == failedInstallment
                    ? 'Closed Lost'
                    : 'Closed Won',
                npsp__Recurring_Donation_Installment_Number__c = installment
            ));
        }
        return opportunities;
    }

    private static List<Opportunity> createPaidInstallments(
        Id accountId,
        Id contactId,
        Id recurringDonationId,
        Integer count
    ) {
        List<Opportunity> paidInstallments = new List<Opportunity>();
        for (Integer installment = 1; installment <= count; installment++) {
            paidInstallments.add(new Opportunity(
                Name = 'Loyalty installment ' + installment,
                AccountId = accountId,
                ContactId = contactId,
                npsp__Primary_Contact__c = contactId,
                StageName = 'Closed Won',
                CloseDate = Date.today().addMonths(installment - count),
                Donation_Type__c = 'Recurring Donation',
                npe03__Recurring_Donation__c = recurringDonationId,
                npsp__Recurring_Donation_Installment_Number__c = installment
            ));
        }
        insert paidInstallments;
        return paidInstallments;
    }

    private static npe03__Recurring_Donation__c createSponsorship(Id contactId) {
        npe03__Recurring_Donation__c recurringDonation =
            new npe03__Recurring_Donation__c(
                npe03__Contact__c = contactId,
                npe03__Amount__c = 25,
                npe03__Installment_Period__c = ApiConstants.PERIOD_MONTHLY,
                npe03__Open_Ended_Status__c = 'Open',
                npsp__Status__c = 'Active',
                Donor_Type__c = ApiConstants.DONOR_INDIVIDUAL,
                Donation_Type__c = 'Recurring Donation'
            );
        insert recurringDonation;
        recurringDonation.Donation_Type__c = ApiConstants.DONATION_SPONSORSHIP;
        update recurringDonation;
        return recurringDonation;
    }
}
