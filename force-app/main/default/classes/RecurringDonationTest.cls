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

    //SFESWCSD-85 case 1
    @isTest
    static void buildsWelcomeEmailTargetsForNewSponsorships() {
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        npe03__Recurring_Donation__c recurringDonation =
            createRecurringDonation(con.Id, null);

        recurringDonation.Donation_Type__c = ApiConstants.DONATION_SPONSORSHIP;
        npe03__Recurring_Donation__c nonSponsorship =
            new npe03__Recurring_Donation__c(
                Id = recurringDonation.Id,
                npe03__Contact__c = con.Id,
                Donation_Type__c = 'Recurring Donation'
            );
        npe03__Recurring_Donation__c sponsorshipWithoutContact =
            new npe03__Recurring_Donation__c(
                Id = recurringDonation.Id,
                Donation_Type__c = ApiConstants.DONATION_SPONSORSHIP
            );

        Map<Id, Id> targets =
            RecurringDonationService.buildSponsorshipWelcomeTargets(
                new List<npe03__Recurring_Donation__c>{
                    recurringDonation,
                    nonSponsorship,
                    sponsorshipWithoutContact
                }
            );

        System.assertEquals(1, targets.size());
        System.assertEquals(recurringDonation.Id, targets.get(con.Id));
    }

    @isTest
    static void doesNotDispatchWelcomeEmailForNonSponsorships() {
        RecurringDonationService service = new RecurringDonationService();

        Test.startTest();
        service.sendSponsorshipWelcomeEmail(
            new List<npe03__Recurring_Donation__c>{
                new npe03__Recurring_Donation__c(
                    Donation_Type__c = 'Recurring Donation'
                )
            }
        );
        Test.stopTest();
    }

    //SFESWCSD-85 case 2
    @isTest
    static void buildsSponsorshipRegistrationCallTask() {
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        npe03__Recurring_Donation__c recurringDonation =
            createRecurringDonation(con.Id, null);
        recurringDonation.Donation_Type__c = ApiConstants.DONATION_SPONSORSHIP;
        Datetime deadline = System.now().addDays(3);

        List<Task> tasks =
            RecurringDonationService.buildSponsorshipRegistrationTasks(
                new List<npe03__Recurring_Donation__c>{ recurringDonation },
                UserInfo.getUserId(),
                deadline,
                new Map<Id, Contact>{ con.Id => con }
            );

        System.assertEquals(1, tasks.size());
        Task registrationTask = tasks[0];
        System.assertEquals('Registration Confirmation', registrationTask.Subject);
        System.assertEquals('Call', registrationTask.Type);
        System.assertEquals(con.Id, registrationTask.WhoId);
        System.assertEquals(recurringDonation.Id, registrationTask.WhatId);
        System.assertEquals(deadline.date(), registrationTask.ActivityDate);
        System.assertEquals(deadline, registrationTask.ReminderDateTime);
        System.assert(registrationTask.IsReminderSet);
        System.assert(registrationTask.Description.contains(con.FirstName));
        System.assert(registrationTask.Description.contains(con.LastName));
    }

    //SFESWCSD-85 case 11
    @isTest
    static void buildsCancellationTargetForSponsorshipWithFuturePledge() {
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        npe03__Recurring_Donation__c recurringDonation =
            createRecurringDonation(con.Id, null);
        insert new Opportunity(
            Name = 'Future sponsorship installment',
            AccountId = acc.Id,
            ContactId = con.Id,
            npsp__Primary_Contact__c = con.Id,
            npe03__Recurring_Donation__c = recurringDonation.Id,
            StageName = 'Pledged',
            CloseDate = Date.today().addMonths(1)
        );

        npe03__Recurring_Donation__c oldRecurringDonation =
            new npe03__Recurring_Donation__c(
                Id = recurringDonation.Id,
                npsp__Status__c = 'Active'
            );
        recurringDonation.Donation_Type__c = ApiConstants.DONATION_SPONSORSHIP;
        recurringDonation.npsp__Status__c = 'Closed';
        recurringDonation.npsp__ClosedReason__c = 'Other';

        Map<Id, Id> targets =
            RecurringDonationService.buildSponsorshipCancellationTargets(
                new List<npe03__Recurring_Donation__c>{ recurringDonation },
                new Map<Id, npe03__Recurring_Donation__c>{
                    recurringDonation.Id => oldRecurringDonation
                }
            );

        System.assertEquals(1, targets.size());
        System.assertEquals(recurringDonation.Id, targets.get(con.Id));

        recurringDonation.npsp__ClosedReason__c = null;
        targets = RecurringDonationService.buildSponsorshipCancellationTargets(
            new List<npe03__Recurring_Donation__c>{ recurringDonation },
            new Map<Id, npe03__Recurring_Donation__c>{
                recurringDonation.Id => oldRecurringDonation
            }
        );
        System.assertEquals(0, targets.size());
    }

}
