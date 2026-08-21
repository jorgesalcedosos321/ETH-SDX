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

}