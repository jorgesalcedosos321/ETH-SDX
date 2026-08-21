@isTest
private class PaymentTriggerServiceTest {
	private static Account acc;
    private static Contact con;
    private static npe03__Recurring_Donation__c donation1;
    private static Id recordTypeOppId;
    private static Id recordTypeAccId;
        
    @TestSetup
    public static void setup() {
    	recordTypeAccId = [SELECT Id FROM RecordType WHERE Name='Household Account' AND SObjectType='Account' LIMIT 1].Id;
        acc = new Account(name = 'test', RecordTypeId = recordTypeAccId);
        INSERT acc;
        
        con = new Contact(LastName='Peréz', FirstName='Juan', email='test@gmail.com', npe01__PreferredPhone__c = 'Home', npe01__Preferred_Email__c = 'Personal');
        con.AccountId = acc.Id;         
        INSERT con;
        
        Date lastPaymentDate = Date.today().addDays(-1);
		
        donation1 = new npe03__Recurring_Donation__c();
        donation1.Name = 'CCD TEST 1';
        donation1.npe03__Open_Ended_Status__c = 'Open';
        donation1.npe03__Schedule_Type__c = 'Monthly';
        donation1.npe03__Contact__c = con.Id;
        donation1.npe03__Last_Payment_Date__c = lastPaymentDate;
        donation1.npe03__Next_Payment_Date__c = Date.today();
        donation1.npe03__Amount__c=1000;
        donation1.npsp__PaymentMethod__c = 'Check';
        donation1.Donor_Type__c = 'Individual';
        donation1.Donation_Type__c = 'Recurring Donation';
        INSERT donation1;
        
        //Id, FROM Opportunity WHERE npe03__Recurring_Donation__c IN : rdIds AND ((CALENDAR_YEAR(CloseDate) =: currentMonth.Year() AND CALENDAR_MONTH(CloseDate) =: currentMonth.Month()) OR (CALENDAR_YEAR(CloseDate) =: nextMonth.Year() AND CALENDAR_MONTH(CloseDate) =: nextMonth.Month()))
            
            
        
        List<Opportunity> opps = [SELECT Id FROM Opportunity];
        System.debug('opps:' + opps);
    }
    
    @isTest 
    public static void CheckPaymentCreation(){
     	con = [SELECT Id, AccountId, LastName, FirstName, email, npe01__PreferredPhone__c, npe01__Preferred_Email__c FROM Contact LIMIT 1];
        acc = [SELECT Id, name, RecordTypeId FROM Account LIMIT 1];
        donation1 = [SELECT Id, Name, npe03__Open_Ended_Status__c, npe03__Schedule_Type__c, npe03__Contact__c, npe03__Last_Payment_Date__c, npe03__Next_Payment_Date__c, npe03__Amount__c FROM npe03__Recurring_Donation__c LIMIT 1];
        recordTypeOppId = [SELECT Id FROM RecordType WHERE Name='Donation' AND SObjectType='Opportunity' LIMIT 1].Id;
        
        Opportunity opp1 = new Opportunity();
        opp1.npe03__Recurring_Donation__c = donation1.Id;
        //opp1.StageName = 'Closed Won';
        opp1.StageName = 'Pledged';
        opp1.AccountId = acc.Id;
        opp1.RecordTypeId = recordTypeOppId;
        opp1.Name = 'opp1';
        opp1.Amount = 1000;
        opp1.CloseDate = Date.today().addMonths(1);
        opp1.npsp__Recurring_Donation_Installment_Number__c = 1;
        opp1.ContactId = con.Id;
        INSERT opp1;
        
        List<npe01__OppPayment__c> oppPays = [SELECT Id FROM npe01__OppPayment__c WHERE npe01__Opportunity__c =: opp1.Id AND status__c <> 'Paid' AND npe01__Payment_Date__c = NULL];
        System.assert(oppPays.size() > 0);
        
        for (npe01__OppPayment__c oppPay : oppPays) {
            oppPay.npe01__Payment_Method__c = 'Cash';
            oppPay.status__c = 'Paid';
        }
        
        UPDATE oppPays; 
        
        opp1.StageName = 'Closed Won';
        UPDATE opp1; 
        
        oppPays = [SELECT Id FROM npe01__OppPayment__c WHERE npe01__Opportunity__c =: opp1.Id AND npe01__Paid__c = true AND npe01__Payment_Date__c <> NULL];
        System.assert(oppPays.size() > 0);
    }
    
    @isTest 
    public static void CheckPaymentCreationFailed(){
     	con = [SELECT Id, AccountId, LastName, FirstName, email, npe01__PreferredPhone__c, npe01__Preferred_Email__c FROM Contact LIMIT 1];
        acc = [SELECT Id, name, RecordTypeId FROM Account LIMIT 1];
        donation1 = [SELECT Id, Name, npe03__Open_Ended_Status__c, npe03__Schedule_Type__c, npe03__Contact__c, npe03__Last_Payment_Date__c, npe03__Next_Payment_Date__c, npe03__Amount__c FROM npe03__Recurring_Donation__c LIMIT 1];
        recordTypeOppId = [SELECT Id FROM RecordType WHERE Name='Donation' AND SObjectType='Opportunity' LIMIT 1].Id;
        
        Opportunity opp1 = new Opportunity();
        opp1.npe03__Recurring_Donation__c = donation1.Id;
        //opp1.StageName = 'Closed Won';
        opp1.StageName = 'Pledged';
        opp1.AccountId = acc.Id;
        opp1.RecordTypeId = recordTypeOppId;
        opp1.Name = 'opp1';
        opp1.Amount = 1000;
        opp1.CloseDate = Date.today().addMonths(1);
        opp1.npsp__Recurring_Donation_Installment_Number__c = 2;
        opp1.ContactId = con.Id;
        INSERT opp1;
        
        List<npe01__OppPayment__c> oppPays = [SELECT Id FROM npe01__OppPayment__c WHERE npe01__Opportunity__c =: opp1.Id AND status__c <> 'Paid' AND npe01__Payment_Date__c = NULL];
        System.assert(oppPays.size() > 0);
        
        for (npe01__OppPayment__c oppPay : oppPays) {
            oppPay.npe01__Payment_Method__c = 'Cash';
            oppPay.status__c = 'Failed';
            oppPay.npe01__Payment_Date__c = null;
            oppPay.npe01__Paid__c = false; 
        }
        
        UPDATE oppPays; 
    }
}