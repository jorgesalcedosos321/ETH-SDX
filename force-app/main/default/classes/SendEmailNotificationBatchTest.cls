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
    static void selectsOnlySuccessfulOneTimeDonationsCreatedOneMonthAgo() {
        Account account = [SELECT Id FROM Account LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        Opportunity eligible = createOpportunity(account.Id, contact.Id, 'Closed Won');
        Opportunity tooRecent = createOpportunity(account.Id, contact.Id, 'Closed Won');
        Opportunity unsuccessful = createOpportunity(account.Id, contact.Id, 'Closed Lost');
        Test.setCreatedDate(
            eligible.Id,
            Datetime.newInstance(Date.today().addMonths(-1), Time.newInstance(12, 0, 0, 0))
        );
        Test.setCreatedDate(
            unsuccessful.Id,
            Datetime.newInstance(Date.today().addMonths(-1), Time.newInstance(12, 0, 0, 0))
        );

        SendEmailNotificationBatch batch = new SendEmailNotificationBatch(
            Utils.ONE_TIME_DONORS_TH
        );
        Database.QueryLocatorIterator records = batch.start(null).iterator();
        Set<Id> selectedIds = new Set<Id>();
        while (records.hasNext()) {
            selectedIds.add(((Opportunity) records.next()).Id);
        }

        System.assertEquals(new Set<Id>{ eligible.Id }, selectedIds);
        System.assert(!selectedIds.contains(tooRecent.Id));
        System.assert(!selectedIds.contains(unsuccessful.Id));
    }

    @isTest
    static void buildsOneTimeThankYouTargetsWithOpportunityWhatId() {
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
            Utils.ONE_TIME_DONORS_TH,
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
        Account account = [SELECT Id FROM Account LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        createOpportunity(account.Id, contact.Id, 'Closed Lost');

        List<String> templateKeys = new List<String>{
            Utils.BIRTHDAY_EMAIL,
            Utils.LOYALTY_CALL_AFTER_6,
            Utils.ONE_TIME_DONORS_LE
        };

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
        Date missedDate = Date.today().addMonths(-1);
        Opportunity firstMiss = new Opportunity(
            Id = Id.valueOf('006000000000011'),
            StageName = 'Closed Lost',
            CloseDate = missedDate
        );
        Opportunity secondMiss = new Opportunity(
            Id = Id.valueOf('006000000000012'),
            StageName = 'Declined',
            CloseDate = missedDate
        );
        Opportunity thirdMiss = new Opportunity(
            Id = Id.valueOf('006000000000013'),
            StageName = 'Missed',
            CloseDate = missedDate
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
            secondMiss.Id,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ secondMiss, firstMiss },
                2,
                Date.today()
            ).Id
        );
        System.assertEquals(
            thirdMiss.Id,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ thirdMiss, secondMiss, firstMiss },
                3,
                Date.today()
            ).Id
        );
        System.assertEquals(
            null,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ thirdMiss, secondMiss, firstMiss },
                1,
                Date.today()
            ),
            'Three misses must not send REMINDER_1'
        );
        System.assertEquals(
            null,
            SendEmailNotificationBatch.getReminderOpportunity(
                new List<Opportunity>{ thirdMiss, secondMiss, firstMiss },
                2,
                Date.today()
            ),
            'Three misses must not send REMINDER_2'
        );
        Opportunity fourthMiss = new Opportunity(
            Id = Id.valueOf('006000000000014'),
            StageName = 'Declined',
            CloseDate = missedDate
        );
        List<Opportunity> fourMisses = new List<Opportunity>{
            fourthMiss,
            thirdMiss,
            secondMiss,
            firstMiss
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
                        CloseDate = missedDate
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
                Date.today().addDays(1)
            ),
            'Reminder must run exactly one month after the missed payment'
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
            Utils.ONE_TIME_DONORS_TH
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
