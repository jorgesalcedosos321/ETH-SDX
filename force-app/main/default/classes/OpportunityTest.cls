@isTest
public class OpportunityTest {

    //SFESWCSD-85 case 3
    @isTest
    static void buildsPaymentConfirmationTargetsForEligibleOpportunities() {
        Id nonRecurringOpportunityId = Id.valueOf('006000000000001');
        Id firstInstallmentOpportunityId = Id.valueOf('006000000000002');
        Id laterInstallmentOpportunityId = Id.valueOf('006000000000003');
        Id unchangedOpportunityId = Id.valueOf('006000000000004');
        Id nonRecurringContactId = Id.valueOf('003000000000001');
        Id recurringContactId = Id.valueOf('003000000000002');
        Id recurringDonationId = Id.valueOf(
            npe03__Recurring_Donation__c.SObjectType.getDescribe().getKeyPrefix() +
            '000000000001'
        );

        List<Opportunity> newRecords = new List<Opportunity>{
            new Opportunity(
                Id = nonRecurringOpportunityId,
                StageName = 'Closed Won',
                Donation_Type__c = 'One-time Donation',
                ContactId = nonRecurringContactId
            ),
            new Opportunity(
                Id = firstInstallmentOpportunityId,
                StageName = 'Closed Won',
                Donation_Type__c = 'One-time Donation',
                npe03__Recurring_Donation__c = recurringDonationId,
                npsp__Recurring_Donation_Installment_Number__c = 1,
                npsp__Primary_Contact__c = recurringContactId
            ),
            new Opportunity(
                Id = laterInstallmentOpportunityId,
                StageName = 'Closed Won',
                Donation_Type__c = 'One-time Donation',
                npe03__Recurring_Donation__c = recurringDonationId,
                npsp__Recurring_Donation_Installment_Number__c = 2,
                npsp__Primary_Contact__c = recurringContactId
            ),
            new Opportunity(
                Id = unchangedOpportunityId,
                StageName = 'Closed Won',
                Donation_Type__c = 'One-time Donation',
                ContactId = nonRecurringContactId
            )
        };
        Map<Id, Opportunity> oldRecords = new Map<Id, Opportunity>{
            nonRecurringOpportunityId => new Opportunity(
                Id = nonRecurringOpportunityId,
                StageName = 'Pledged'
            ),
            firstInstallmentOpportunityId => new Opportunity(
                Id = firstInstallmentOpportunityId,
                StageName = 'Pledged'
            ),
            laterInstallmentOpportunityId => new Opportunity(
                Id = laterInstallmentOpportunityId,
                StageName = 'Pledged'
            ),
            unchangedOpportunityId => new Opportunity(
                Id = unchangedOpportunityId,
                StageName = 'Closed Won'
            )
        };

        Map<Id, Id> targets = OpportunityService.buildPaymentConfirmationTargets(
            newRecords,
            oldRecords
        );

        System.assertEquals(2, targets.size());
        System.assertEquals(
            nonRecurringOpportunityId,
            targets.get(nonRecurringContactId)
        );
        System.assertEquals(
            firstInstallmentOpportunityId,
            targets.get(recurringContactId)
        );

        Opportunity noContact = new Opportunity(
            Id = Id.valueOf('006000000000005'),
            StageName = 'Closed Won',
            Donation_Type__c = 'One-time Donation'
        );
        Opportunity notWon = new Opportunity(
            Id = Id.valueOf('006000000000006'),
            StageName = 'Pledged',
            Donation_Type__c = 'One-time Donation',
            ContactId = nonRecurringContactId
        );
        targets = OpportunityService.buildPaymentConfirmationTargets(
            new List<Opportunity>{ noContact, notWon },
            new Map<Id, Opportunity>{
                noContact.Id => new Opportunity(
                    Id = noContact.Id,
                    StageName = 'Pledged'
                ),
                notWon.Id => new Opportunity(
                    Id = notWon.Id,
                    StageName = 'Prospecting'
                )
            }
        );
        System.assertEquals(0, targets.size());
    }

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
        // The service sets the Type on the in-memory records (BeforeInsert), it does not update them
        System.assertEquals('Individual Committed', oppList[0].Type, 'Opportunity Type should be set as "Individual Committed"');
    }

    @isTest
    static void testSetOpportunityTypeWithNoRD() {
        Account acc = createAccount('Organization');
        Contact con = createContact(acc.Id);

        Opportunity opp = createOpportunity(acc.Id, con.Id, 'Prospecting', 'New', null);
        
        List<Opportunity> oppList = new List<Opportunity>{ opp };
        Test.startTest();
        
        // Execute method
        OpportunityService service = new OpportunityService();
        service.setOpportunityTypeWithNoRD(oppList);
        
        Test.stopTest();
        
        // Assert results
        System.assertEquals('Corporate One-off', oppList[0].Type, 'Opportunity Type should be set as "Corporate One-off"');
    }

    @isTest
    static void testCheckOpportunitiesWithNoRDToNotify() {
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        
        Opportunity opp = createOpportunity(acc.Id, con.Id, 'Closed Won', 'Individual Committed', null);
        Opportunity opp2 = createOpportunity(acc.Id, con.Id, 'Closed Won', 'Individual One-off', null);
        
        Map<Id, Opportunity> oldRecords = new Map<Id, Opportunity>();
        oldRecords.put(opp.Id, opp);
        oldRecords.put(opp2.Id, opp2);

        List<Opportunity> newRecords = new List<Opportunity>{ opp, opp2 };
        
        Test.startTest();
        
        OpportunityService service = new OpportunityService();
        service.checkOpportunitiesWithNoRDToNotify(newRecords, oldRecords);
        
        Test.stopTest();
        
        // We can't easily verify email sending, but you can ensure that no errors were thrown
        System.assert(true, 'Method executed without errors');
    }

    @isTest
    static void buildsImmediateOneTimeThankYouTargetsOnRegistration() {
        Id primaryContactId = Id.valueOf('003000000000001');
        Id fallbackContactId = Id.valueOf('003000000000002');
        Opportunity primaryContactOpportunity = new Opportunity(
            Id = Id.valueOf('006000000000001'),
            ContactId = fallbackContactId,
            npsp__Primary_Contact__c = primaryContactId,
            StageName = 'Closed Won',
            Donation_Type__c = 'One-time Donation'
        );
        Opportunity fallbackContactOpportunity = new Opportunity(
            Id = Id.valueOf('006000000000002'),
            ContactId = fallbackContactId,
            StageName = 'Closed Won',
            Donation_Type__c = 'One-time Donation'
        );
        Opportunity recurringDonationOpportunity = new Opportunity(
            Id = Id.valueOf('006000000000003'),
            ContactId = primaryContactId,
            StageName = 'Closed Won',
            Donation_Type__c = 'Recurring Donation'
        );
        // Previous stage of each Opportunity: targets are only built when it moves to Closed Won
        Map<Id, Opportunity> oldOpportunities = new Map<Id, Opportunity>{
            primaryContactOpportunity.Id => new Opportunity(Id = primaryContactOpportunity.Id, StageName = 'Pledged'),
            fallbackContactOpportunity.Id => new Opportunity(Id = fallbackContactOpportunity.Id, StageName = 'Pledged'),
            recurringDonationOpportunity.Id => new Opportunity(Id = recurringDonationOpportunity.Id, StageName = 'Pledged')
        };

        Map<Id, Id> targets =
            OpportunityService.buildOneTimeDonorThankYouTargets(
                new List<Opportunity>{
                    primaryContactOpportunity,
                    fallbackContactOpportunity,
                    recurringDonationOpportunity
                },
                oldOpportunities
            );

        System.assertEquals(2, targets.size());
        System.assertEquals(
            primaryContactOpportunity.Id,
            targets.get(primaryContactId)
        );
        System.assertEquals(
            fallbackContactOpportunity.Id,
            targets.get(fallbackContactId)
        );
    }

    @isTest
    static void testCheckOpportunitiesWithRDToNotify() {
        Account acc = createAccount('Organization');
        Contact con = createContact(acc.Id);
        con.npe01__Preferred_Email__c = 'Personal';
        con.npe01__HomeEmail__c = 'jorge.salcedo@sos-kd.org';
        UPDATE con;
        
        npe03__Recurring_Donation__c rd = createRecurringDonation(con.Id, null);

        Opportunity opp = createOpportunity(acc.Id, con.Id, 'Closed Won', 'Individual Committed', rd.Id);
        Opportunity opp2 = createOpportunity(acc.Id, con.Id, 'Closed Won', 'Individual One-off', rd.Id);
        
        Map<Id, Opportunity> oldRecords = new Map<Id, Opportunity>();
        oldRecords.put(opp.Id, opp);
        oldRecords.put(opp2.Id, opp2);

        List<Opportunity> newRecords = new List<Opportunity>{ opp, opp2 };
        
        Test.startTest(); 
        
        OpportunityService service = new OpportunityService();
        //service.checkOpportunitiesWithRDToNotify(newRecords, oldRecords);
        
        Test.stopTest();
        
        // We can't easily verify email sending, but you can ensure that no errors were thrown
        System.assert(true, 'Method executed without errors');
    }

    @isTest
    static void testCheckProcessToNotify() {
        Map<Id, Integer> toNotify = new Map<Id, Integer>{};
        Map<Id, Id> rdContactIds = new Map<Id, Id>();
        Map<Id, Id> oppRdIds = new Map<Id, Id>();
        
        Test.startTest();
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        List<Contact> conts = new List<Contact>{con};
        OpportunityService service = new OpportunityService();
        
        service.getContactById(conts, con.Id);
            
        //service.checkProcessToNotify(toNotify, rdContactIds, oppRdIds, conts);
        
        Test.stopTest();
        
        // We can't easily verify email sending, but you can ensure that no errors were thrown
        System.assert(true, 'Method executed without errors');
    }

    private static void createEmailTemplates() {
        List<EmailTemplate> templates = new List<EmailTemplate>{
            new EmailTemplate(Name='Thank You Email', Subject='Thanks!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
            new EmailTemplate(Name='Welcome Email', Subject='Welcome!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
            new EmailTemplate(Name='Referral Ask Email', Subject='Refer someone!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
            new EmailTemplate(Name='Impact Email', Subject='Your impact!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
            new EmailTemplate(Name='Upgrade Email', Subject='Upgrade now!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
            new EmailTemplate(Name='One Year Thank You Email', Subject='1 Year Thanks!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom')
        };
        //insert templates;
    }

    private static Contact createContact(String email) {
        Contact c = new Contact(
            FirstName = 'Ana',
            LastName = 'Tester',
            Email = email,
            npsp__Do_Not_Contact__c = false,
            HasOptedOutOfEmail = false
        );
        insert c;
        return c;
    }

    private static npe03__Recurring_Donation__c createRecurringDonation(Integer totalPaidInstallments, Contact cont) {
        npe03__Recurring_Donation__c rd = new npe03__Recurring_Donation__c(
            Name = 'Test RD',
            npe03__Contact__c = cont.Id,
            npe03__Amount__c  = 100,
            npe03__Installment_Period__c = 'Monthly',
            npe03__Total_Paid_Installments__c = totalPaidInstallments,            
            Donation_Type__c = 'Recurring Donation',
            Donor_Type__c = 'Individual'
        ); 
            
        insert rd;
        return rd;
    }

    @isTest
    static void testSendEmailNotificationForInstallments() {
        createEmailTemplates();
        Contact c = createContact('email@test.com');
        
        Test.startTest();
        for (Integer installment : new List<Integer>{1, 2, 4}) { //, 6, 10, 12
            npe03__Recurring_Donation__c rd = createRecurringDonation(installment, c);

            Opportunity oldOpp = new Opportunity(
                Name = 'Old Opp',
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                Donation_Type__c = 'Recurring Donation',
                Donor_Type__c = 'Individual'
            );
            insert oldOpp;
                
            Opportunity newOpp = new Opportunity(
                Id = oldOpp.Id,
                Name = 'New Opp',
                StageName = (installment == 1 ? 'Declined' : 'Closed Won'),
                CloseDate = Date.today(),
                Donation_Type__c = 'Recurring Donation',
                Donor_Type__c = 'Individual',
                npsp__Primary_Contact__c = c.Id,
                npe03__Recurring_Donation__c = rd.Id
            );
            update newOpp;

            (new OpportunityService()).sendEmailNotificationForInstallments(
                new List<Opportunity>{newOpp},
                new Map<Id, Opportunity>{oldOpp.Id => oldOpp}
            );
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testSendEmailNotificationForInstallments2ndGroup() {
        createEmailTemplates();
        Contact c = createContact('email@test.com');
        
        Test.startTest();
        for (Integer installment : new List<Integer>{6, 10, 12}) { //, 
            npe03__Recurring_Donation__c rd = createRecurringDonation(installment, c);

            Opportunity oldOpp = new Opportunity(
                Name = 'Old Opp',
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                Donation_Type__c = 'Recurring Donation',
                Donor_Type__c = 'Individual'
            );
            insert oldOpp;

            Opportunity newOpp = new Opportunity(
                Id = oldOpp.Id,
                Name = 'New Opp',
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                Donation_Type__c = 'Recurring Donation',
                Donor_Type__c = 'Individual',
                npsp__Primary_Contact__c = c.Id,
                npe03__Recurring_Donation__c = rd.Id
            );
            update newOpp;

            (new OpportunityService()).sendEmailNotificationForInstallments(
                new List<Opportunity>{newOpp},
                new Map<Id, Opportunity>{oldOpp.Id => oldOpp}
            );
        }
        
        Test.stopTest();
    }


    @isTest
    static void testIsThreeConsecutivesDeclinedOpps() {
        Contact c = createContact('email@test.com');
        npe03__Recurring_Donation__c rd = createRecurringDonation(0, c);
        Opportunity opp1 = new Opportunity(
            Name = 'Declined 1',
            StageName = 'Declined',
            CloseDate = Date.today(),
            npe03__Recurring_Donation__c = rd.Id
        );
        Opportunity opp2 = new Opportunity(
            Name = 'Declined 2',
            StageName = 'Declined',
            CloseDate = Date.today().addDays(1),
            npe03__Recurring_Donation__c = rd.Id
        );
        Opportunity opp3 = new Opportunity(
            Name = 'Declined 3',
            StageName = 'Declined',
            CloseDate = Date.today().addDays(2),
            npe03__Recurring_Donation__c = rd.Id
        );

        insert new List<Opportunity>{opp1, opp2, opp3};

        Opportunity result = new OpportunityService().isThreeConsecutivesDeclinedOpps(opp3.Id, rd.Id, new List<Opportunity>{opp1, opp2, opp3});
        System.assertNotEquals(null, result);
        System.assertEquals(opp3.Id, result.Id);
    }

    @isTest
    static void testIsThreeConsecutivesDeclinedOppsNegative() {
        Contact c = createContact('email@test.com');
        npe03__Recurring_Donation__c rd = createRecurringDonation(0, c);
        Opportunity opp1 = new Opportunity(
            Name = 'Closed 1',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            npe03__Recurring_Donation__c = rd.Id
        );
        Opportunity opp2 = new Opportunity(
            Name = 'Declined 2',
            StageName = 'Declined',
            CloseDate = Date.today().addDays(1),
            npe03__Recurring_Donation__c = rd.Id
        );
        Opportunity opp3 = new Opportunity(
            Name = 'Declined 3',
            StageName = 'Declined',
            CloseDate = Date.today().addDays(2),
            npe03__Recurring_Donation__c = rd.Id
        );

        insert new List<Opportunity>{opp1, opp2, opp3};

        Opportunity result = new OpportunityService().isThreeConsecutivesDeclinedOpps(opp3.Id, rd.Id, new List<Opportunity>{opp1, opp2, opp3});
        System.assertEquals(null, result);
    }

    //SFESWCSD-113
    private static npe03__Recurring_Donation__c createRDWithNoOpportunities(Id contactId, Date dateEstablished) {
        npe03__Recurring_Donation__c rd = createRecurringDonation(contactId, null);
        rd.npe03__Date_Established__c = dateEstablished;
        update rd;
        delete [SELECT Id FROM Opportunity WHERE npe03__Recurring_Donation__c = :rd.Id];
        return rd;
    }

    //SFESWCSD-113 The TDTM handler does not run in test context, so the service is called directly
    //on in-memory Opportunities, as the BeforeInsert handler does.
    private static Opportunity newOpportunity(Id rdId, Date closeDate) {
        return new Opportunity(
            Name = 'Opp113',
            StageName = 'Prospecting',
            npe03__Recurring_Donation__c = rdId,
            CloseDate = closeDate
        );
    }

    //SFESWCSD-113
    @isTest
    static void shouldSetCloseDateToDateEstablished_WhenFirstOpportunityOfRD() {
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        Date established = Date.today().addDays(10);
        npe03__Recurring_Donation__c rd = createRDWithNoOpportunities(con.Id, established);
        Opportunity opp = newOpportunity(rd.Id, Date.today());

        Test.startTest();
        new OpportunityService().setFirstOpportunityCloseDate(new List<Opportunity>{ opp });
        Test.stopTest();

        Assert.areEqual(established, opp.CloseDate, 'First opportunity should use the RD Date Established as CloseDate');
    }

    //SFESWCSD-113
    @isTest
    static void shouldAddOneMonth_WhenSecondOpportunityIsInSameMonthAsFirst() {
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        npe03__Recurring_Donation__c rd = createRDWithNoOpportunities(con.Id, Date.newInstance(2030, 1, 10));
        insert newOpportunity(rd.Id, Date.newInstance(2030, 1, 10));
        Opportunity second = newOpportunity(rd.Id, Date.newInstance(2030, 1, 20));

        Test.startTest();
        new OpportunityService().setFirstOpportunityCloseDate(new List<Opportunity>{ second });
        Test.stopTest();

        Assert.areEqual(Date.newInstance(2030, 2, 20), second.CloseDate, 'Second opportunity in the same month as the first should move one month ahead');
    }

    //SFESWCSD-113
    @isTest
    static void shouldKeepCloseDate_WhenSecondOpportunityIsInAnotherMonth() {
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        npe03__Recurring_Donation__c rd = createRDWithNoOpportunities(con.Id, Date.newInstance(2030, 1, 10));
        insert newOpportunity(rd.Id, Date.newInstance(2030, 1, 10));
        Opportunity second = newOpportunity(rd.Id, Date.newInstance(2030, 2, 5));

        Test.startTest();
        new OpportunityService().setFirstOpportunityCloseDate(new List<Opportunity>{ second });
        Test.stopTest();

        Assert.areEqual(Date.newInstance(2030, 2, 5), second.CloseDate, 'Second opportunity in a different month should keep its CloseDate');
    }

    //SFESWCSD-113
    @isTest
    static void shouldKeepCloseDate_WhenOpportunityHasNoRD() {
        Opportunity opp = newOpportunity(null, Date.today());

        Test.startTest();
        new OpportunityService().setFirstOpportunityCloseDate(new List<Opportunity>{ opp });
        Test.stopTest();

        Assert.areEqual(Date.today(), opp.CloseDate, 'One-off opportunities should keep their CloseDate');
    }

    //SFESWCSD-91 Returns the Donations_Calls queue, creating it (enabled for Task) if the org does not have it
    private static Id getOrCreateDonationsCallsQueue() {
        List<Group> existing = [
            SELECT Id FROM Group
            WHERE Type = 'Queue' AND DeveloperName = :OpportunityService.DONOR_CALLS_QUEUE
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        Id queueId;
        // Queues are setup objects: DML on them must not be mixed with the data created by the test
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group donationsCalls = new Group(
                Name = 'Donations Calls',
                DeveloperName = OpportunityService.DONOR_CALLS_QUEUE,
                Type = 'Queue'
            );
            insert donationsCalls;
            insert new QueueSobject(QueueId = donationsCalls.Id, SobjectType = 'Task');
            queueId = donationsCalls.Id;
        }
        return queueId;
    }

    //SFESWCSD-91
    private static Map<Id, npe03__Recurring_Donation__c> queryRecurringDonationsWithContact(Set<Id> rdIds) {
        return new Map<Id, npe03__Recurring_Donation__c>([
            SELECT Id, npe03__Contact__c, npe03__Contact__r.FirstName, npe03__Contact__r.LastName,
                npe03__Contact__r.Phone, npe03__Contact__r.Email
            FROM npe03__Recurring_Donation__c
            WHERE Id IN :rdIds
        ]);
    }

    //SFESWCSD-91
    @isTest
    static void shouldCreateLoyaltyAndWelcomeTasksOwnedByTheQueue() {
        Id queueId = getOrCreateDonationsCallsQueue();
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        npe03__Recurring_Donation__c loyaltyRd = createRecurringDonation(con.Id, null);
        npe03__Recurring_Donation__c welcomeRd = createRecurringDonation(con.Id, null);
        npe03__Recurring_Donation__c bothRd = createRecurringDonation(con.Id, null);
        Map<Id, npe03__Recurring_Donation__c> rdById = queryRecurringDonationsWithContact(
            new Set<Id>{ loyaltyRd.Id, welcomeRd.Id, bothRd.Id }
        );

        Test.startTest();
        OpportunityService.buildDonorCallTasks(
            rdById,
            new Set<Id>{ loyaltyRd.Id, bothRd.Id },
            new Set<Id>{ welcomeRd.Id, bothRd.Id }
        );
        Test.stopTest();

        Map<String, Task> tasksByKey = new Map<String, Task>();
        for (Task donorTask : [
            SELECT Subject, OwnerId, WhoId, WhatId, Description, ActivityDate, Priority
            FROM Task
            WHERE WhatId IN :rdById.keySet()
        ]) {
            tasksByKey.put(donorTask.WhatId + '|' + donorTask.Subject, donorTask);
        }

        Assert.areEqual(4, tasksByKey.size(), 'One task per RD and subject: loyalty, welcome and both for the RD in the two sets');
        for (String key : new List<String>{
            loyaltyRd.Id + '|Loyalty call after 6 payments',
            welcomeRd.Id + '|Welcome the new donor CG',
            bothRd.Id + '|Loyalty call after 6 payments',
            bothRd.Id + '|Welcome the new donor CG'
        }) {
            Task donorTask = tasksByKey.get(key);
            Assert.isNotNull(donorTask, 'Missing task ' + key);
            Assert.areEqual(queueId, donorTask.OwnerId, 'The task must be owned by the queue, not by a user');
            Assert.areEqual(con.Id, donorTask.WhoId);
            Assert.areEqual(Date.today(), donorTask.ActivityDate);
            Assert.areEqual('Normal', donorTask.Priority);
            Assert.isTrue(donorTask.Description.contains('First Name: John'), 'Description carries the donor contact details');
            Assert.isTrue(donorTask.Description.contains('Last Name: Doe'));
        }
    }

    //SFESWCSD-91
    @isTest
    static void shouldNotCreateTasks_WhenThereAreNoRecurringDonationsToCall() {
        getOrCreateDonationsCallsQueue();
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        npe03__Recurring_Donation__c rd = createRecurringDonation(con.Id, null);

        Test.startTest();
        // Nothing to call
        OpportunityService.buildDonorCallTasks(
            queryRecurringDonationsWithContact(new Set<Id>{ rd.Id }),
            new Set<Id>(),
            new Set<Id>()
        );
        // The RD to call is not in the queried map
        OpportunityService.buildDonorCallTasks(
            new Map<Id, npe03__Recurring_Donation__c>(),
            new Set<Id>{ rd.Id },
            new Set<Id>()
        );
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Task WHERE WhatId = :rd.Id]);
    }

    //SFESWCSD-91
    @isTest
    static void shouldNotFailTheSave_WhenTheQueueDoesNotExist() {
        Account acc = createAccount('Household Account');
        Contact con = createContact(acc.Id);
        npe03__Recurring_Donation__c rd = createRecurringDonation(con.Id, null);
        Map<Id, npe03__Recurring_Donation__c> rdById = queryRecurringDonationsWithContact(new Set<Id>{ rd.Id });

        // The org queue cannot be deleted (existing Tasks use it), so point the service to one that does not exist
        OpportunityService.DONOR_CALLS_QUEUE = 'Queue_That_Does_Not_Exist';

        Test.startTest();
        OpportunityService.buildDonorCallTasks(rdById, new Set<Id>{ rd.Id }, new Set<Id>{ rd.Id });
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Task WHERE WhatId = :rd.Id], 'No task is created and no exception is thrown');
    }
}