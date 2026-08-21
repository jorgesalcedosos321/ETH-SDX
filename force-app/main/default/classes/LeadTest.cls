@isTest
private class LeadTest {
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
        
        LeadHandler lh = new LeadHandler(new List<Lead> {newLead}, null);
        lh.beforeInsert();
	}
}