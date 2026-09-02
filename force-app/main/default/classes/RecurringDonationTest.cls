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

    //SFESWCSD-91
    @isTest
    static void buildsSuccessfulPaymentMilestoneEmailTargets() {
        Id contactId = Id.valueOf('003000000000021');
        List<npe03__Recurring_Donation__c> newRecords =
            new List<npe03__Recurring_Donation__c>();
        Map<Id, npe03__Recurring_Donation__c> oldRecords =
            new Map<Id, npe03__Recurring_Donation__c>();
        Map<Integer, String> expectedTemplates = new Map<Integer, String>{
            2 => Utils.THANK_YOU_EMAIL_AFTER_2,
            3 => Utils.THANK_YOU_EMAIL_AFTER_3,
            4 => Utils.THANK_YOU_EMAIL_AFTER_4,
            6 => Utils.THANK_YOU_EMAIL_AFTER_6,
            12 => Utils.THANK_YOU_EMAIL_AFTER_12
        };

        Integer sequence = 1;
        for (Integer paymentCount : expectedTemplates.keySet()) {
            Id recurringDonationId = Id.valueOf(
                npe03__Recurring_Donation__c.SObjectType.getDescribe().getKeyPrefix() +
                String.valueOf(sequence).leftPad(12, '0')
            );
            newRecords.add(new npe03__Recurring_Donation__c(
                Id = recurringDonationId,
                npe03__Contact__c = contactId,
                Donation_Type__c = 'Recurring Donation',
                npe03__Total_Paid_Installments__c = paymentCount
            ));
            oldRecords.put(recurringDonationId, new npe03__Recurring_Donation__c(
                Id = recurringDonationId,
                npe03__Total_Paid_Installments__c = paymentCount - 1
            ));
            sequence++;
        }

        Map<String, Map<Id, Id>> targetsByTemplate =
            RecurringDonationService.buildSuccessfulPaymentMilestoneTargets(
                newRecords,
                oldRecords
            );

        System.assertEquals(5, targetsByTemplate.size());
        for (String templateKey : expectedTemplates.values()) {
            System.assertEquals(1, targetsByTemplate.get(templateKey).size());
            System.assert(targetsByTemplate.get(templateKey).containsKey(contactId));
        }
    }

    @isTest
    static void ignoresNonMilestoneAndIneligiblePaymentUpdates() {
        Id contactId = Id.valueOf('003000000000061');
        String prefix = npe03__Recurring_Donation__c.SObjectType
            .getDescribe().getKeyPrefix();
        Id unchangedId = Id.valueOf(prefix + '000000000061');
        Id nonMilestoneId = Id.valueOf(prefix + '000000000062');
        Id sponsorshipId = Id.valueOf(prefix + '000000000063');
        Id missingContactId = Id.valueOf(prefix + '000000000064');
        List<npe03__Recurring_Donation__c> newRecords =
            new List<npe03__Recurring_Donation__c>{
                new npe03__Recurring_Donation__c(
                    Id = unchangedId,
                    npe03__Contact__c = contactId,
                    Donation_Type__c = 'Recurring Donation',
                    npe03__Total_Paid_Installments__c = 2
                ),
                new npe03__Recurring_Donation__c(
                    Id = nonMilestoneId,
                    npe03__Contact__c = contactId,
                    Donation_Type__c = 'Recurring Donation',
                    npe03__Total_Paid_Installments__c = 5
                ),
                new npe03__Recurring_Donation__c(
                    Id = sponsorshipId,
                    npe03__Contact__c = contactId,
                    Donation_Type__c = ApiConstants.DONATION_SPONSORSHIP,
                    npe03__Total_Paid_Installments__c = 6
                ),
                new npe03__Recurring_Donation__c(
                    Id = missingContactId,
                    Donation_Type__c = 'Recurring Donation',
                    npe03__Total_Paid_Installments__c = 6
                )
            };
        Map<Id, npe03__Recurring_Donation__c> oldRecords =
            new Map<Id, npe03__Recurring_Donation__c>{
                unchangedId => new npe03__Recurring_Donation__c(
                    Id = unchangedId,
                    npe03__Total_Paid_Installments__c = 2
                ),
                nonMilestoneId => new npe03__Recurring_Donation__c(
                    Id = nonMilestoneId,
                    npe03__Total_Paid_Installments__c = 4
                ),
                sponsorshipId => new npe03__Recurring_Donation__c(
                    Id = sponsorshipId,
                    npe03__Total_Paid_Installments__c = 5
                ),
                missingContactId => new npe03__Recurring_Donation__c(
                    Id = missingContactId,
                    npe03__Total_Paid_Installments__c = 5
                )
            };

        System.assertEquals(
            0,
            RecurringDonationService.buildSuccessfulPaymentMilestoneTargets(
                newRecords,
                oldRecords
            ).size()
        );
    }

    //SFESWCSD-91
    @isTest
    static void buildsSixPaymentLoyaltyTasksForBothOwners() {
        Id recurringDonationId = Id.valueOf(
            npe03__Recurring_Donation__c.SObjectType.getDescribe().getKeyPrefix() +
            '000000000031'
        );
        Id contactId = Id.valueOf('003000000000031');
        Contact contact = new Contact(
            Id = contactId,
            FirstName = 'Test',
            LastName = 'Donor',
            Phone = '+251911000000',
            Email = 'donor@example.com'
        );
        npe03__Recurring_Donation__c recurringDonation =
            new npe03__Recurring_Donation__c(
                Id = recurringDonationId,
                npe03__Contact__c = contactId,
                Donation_Type__c = 'Recurring Donation',
                npe03__Total_Paid_Installments__c = 6
            );
        Set<Id> ownerIds = new Set<Id>{
            Id.valueOf('005000000000031'),
            Id.valueOf('005000000000032')
        };

        List<Task> tasks =
            RecurringDonationService.buildSixPaymentLoyaltyCallTasks(
                new List<npe03__Recurring_Donation__c>{ recurringDonation },
                ownerIds,
                new Map<Id, Contact>{ contactId => contact }
            );

        System.assertEquals(2, tasks.size());
        for (Task loyaltyTask : tasks) {
            System.assertEquals('Loyalty call after 6 payments', loyaltyTask.Subject);
            System.assertEquals('Call', loyaltyTask.Type);
            System.assertEquals(contactId, loyaltyTask.WhoId);
            System.assertEquals(recurringDonationId, loyaltyTask.WhatId);
            System.assert(ownerIds.contains(loyaltyTask.OwnerId));
            System.assert(loyaltyTask.Description.contains(contact.FirstName));
            System.assert(loyaltyTask.Description.contains(contact.LastName));
            System.assert(loyaltyTask.Description.contains(contact.Phone));
            System.assert(loyaltyTask.Description.contains(contact.Email));
        }
    }

    //SFESWCSD-91
    @isTest
    static void buildsWelcomeTargetOnlyForFirstCommittedDonation() {
        Id contactId = Id.valueOf('003000000000041');
        Id recurringDonationId = Id.valueOf(
            npe03__Recurring_Donation__c.SObjectType.getDescribe().getKeyPrefix() +
            '000000000041'
        );
        npe03__Recurring_Donation__c recurringDonation =
            new npe03__Recurring_Donation__c(
                Id = recurringDonationId,
                npe03__Contact__c = contactId,
                Donation_Type__c = 'Recurring Donation'
            );
        List<npe03__Recurring_Donation__c> newRecords =
            new List<npe03__Recurring_Donation__c>{ recurringDonation };
        Map<Id, Integer> newCounts = new Map<Id, Integer>{ contactId => 1 };

        Map<Id, Id> targets =
            RecurringDonationService.buildFirstCommittedDonationTargets(
                newRecords,
                newCounts,
                new Map<Id, Integer>{ contactId => 1 }
            );
        System.assertEquals(recurringDonationId, targets.get(contactId));

        targets = RecurringDonationService.buildFirstCommittedDonationTargets(
            newRecords,
            newCounts,
            new Map<Id, Integer>{ contactId => 2 }
        );
        System.assertEquals(0, targets.size());

        Id secondDonationId = Id.valueOf(
            npe03__Recurring_Donation__c.SObjectType.getDescribe().getKeyPrefix() +
            '000000000042'
        );
        npe03__Recurring_Donation__c secondDonation =
            new npe03__Recurring_Donation__c(
                Id = secondDonationId,
                npe03__Contact__c = contactId,
                Donation_Type__c = 'Recurring Donation'
            );
        targets = RecurringDonationService.buildFirstCommittedDonationTargets(
            new List<npe03__Recurring_Donation__c>{
                recurringDonation,
                secondDonation
            },
            new Map<Id, Integer>{ contactId => 2 },
            new Map<Id, Integer>{ contactId => 2 }
        );
        System.assertEquals(1, targets.size());
        System.assertEquals(recurringDonationId, targets.get(contactId));

        recurringDonation.Donation_Type__c = ApiConstants.DONATION_SPONSORSHIP;
        targets = RecurringDonationService.buildFirstCommittedDonationTargets(
            new List<npe03__Recurring_Donation__c>{ recurringDonation },
            new Map<Id, Integer>{ contactId => 1 },
            new Map<Id, Integer>{ contactId => 1 }
        );
        System.assertEquals(0, targets.size());
    }

    //SFESWCSD-91
    @isTest
    static void buildsFirstCommittedDonationCallTask() {
        Id contactId = Id.valueOf('003000000000051');
        Id recurringDonationId = Id.valueOf(
            npe03__Recurring_Donation__c.SObjectType.getDescribe().getKeyPrefix() +
            '000000000051'
        );
        Contact contact = new Contact(
            Id = contactId,
            FirstName = 'New',
            LastName = 'Donor',
            Email = 'new.donor@example.com',
            Phone = '+251911111111'
        );
        npe03__Recurring_Donation__c recurringDonation =
            new npe03__Recurring_Donation__c(
                Id = recurringDonationId,
                OwnerId = UserInfo.getUserId(),
                npe03__Contact__c = contactId,
                Donation_Type__c = 'Recurring Donation'
        );
        Datetime deadline = System.now().addDays(1);
        Set<Id> ownerIds = new Set<Id>{
            Id.valueOf('005000000000051'),
            Id.valueOf('005000000000052')
        };

        List<Task> tasks =
            RecurringDonationService.buildFirstCommittedDonationCallTasks(
                new Map<Id, Id>{ contactId => recurringDonationId },
                new Map<Id, npe03__Recurring_Donation__c>{
                    recurringDonationId => recurringDonation
                },
                new Map<Id, Contact>{ contactId => contact },
                deadline,
                ownerIds
            );

        System.assertEquals(2, tasks.size());
        for (Task welcomeTask : tasks) {
            System.assertEquals('Welcome the new donor', welcomeTask.Subject);
            System.assertEquals('Call', welcomeTask.Type);
            System.assertEquals(contactId, welcomeTask.WhoId);
            System.assertEquals(recurringDonationId, welcomeTask.WhatId);
            System.assert(ownerIds.contains(welcomeTask.OwnerId));
            System.assertEquals(deadline.date(), welcomeTask.ActivityDate);
            System.assertEquals(deadline, welcomeTask.ReminderDateTime);
            System.assert(welcomeTask.Description.contains(contact.FirstName));
            System.assert(welcomeTask.Description.contains(contact.LastName));
            System.assert(welcomeTask.Description.contains(contact.Email));
            System.assert(welcomeTask.Description.contains(contact.Phone));
        }
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

        recurringDonation.npsp__ClosedReason__c = 'Other';
        recurringDonation.npsp__Status__c = 'Lapsed';
        targets = RecurringDonationService.buildSponsorshipCancellationTargets(
            new List<npe03__Recurring_Donation__c>{ recurringDonation },
            new Map<Id, npe03__Recurring_Donation__c>{
                recurringDonation.Id => oldRecurringDonation
            }
        );
        System.assertEquals(recurringDonation.Id, targets.get(con.Id));

        oldRecurringDonation.npsp__Status__c = 'Lapsed';
        targets = RecurringDonationService.buildSponsorshipCancellationTargets(
            new List<npe03__Recurring_Donation__c>{ recurringDonation },
            new Map<Id, npe03__Recurring_Donation__c>{
                recurringDonation.Id => oldRecurringDonation
            }
        );
        System.assertEquals(0, targets.size());
    }

}
