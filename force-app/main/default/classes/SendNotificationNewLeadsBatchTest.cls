@isTest
private class SendNotificationNewLeadsBatchTest {
	@isTest 
    public static void checkLeadToNotify(){
		Lead newLead = new Lead();
        newLead.Status = 'New';
        newLead.FirstName = 'FirstName Test';
        newLead.LastName = 'LastName Test';
        newLead.Company = '-';
        newLead.Donation_Type__c = 'Recurring Donation';
        newLead.Installment_Frequency__c = 'Monthly';
        INSERT newLead; 
        
        List<Lead> leadsToCheck = [SELECT Id, OwnerId FROM Lead WHERE Status = 'New'];
        SendNotificationNewLeadsBatch snl = new SendNotificationNewLeadsBatch();
        snl.start(null);
        snl.execute(null, leadsToCheck);
        snl.execute(null);
	}
}