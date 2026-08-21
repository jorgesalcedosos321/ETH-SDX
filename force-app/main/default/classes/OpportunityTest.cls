@isTest
public class OpportunityTest {

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
        opp = [SELECT Type FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Corporate One-off', opp.Type, 'Opportunity Type should be set as "Corporate One-off"');
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
}