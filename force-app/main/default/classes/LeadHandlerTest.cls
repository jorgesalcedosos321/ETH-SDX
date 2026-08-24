@isTest
private class LeadHandlerTest {
	@isTest 
    static void creatingLead(){
        List<Lead> leads = new List<Lead>();
        Lead newLead = new Lead();
        newLead.Status = 'New';
        newLead.FirstName = 'FirstName Test';
        newLead.LastName = 'LastName Test';
        newLead.Company = '-';
        newLead.Donation_Type__c = 'Recurring Donation';
        newLead.Installment_Frequency__c = 'Monthly';
        leads.add(newLead);
        
        newLead = new Lead();
        newLead.Status = 'New';
        newLead.FirstName = 'FirstName Test 2';
        newLead.LastName = 'LastName Test 2';
        newLead.Company = 'ACME';
        //newLead.Donation_Type__c = 'Recurring Donation';
        newLead.Installment_Frequency__c = 'Monthly';
        leads.add(newLead);
        INSERT leads;
        
        LeadHandler lh = new LeadHandler(leads, null);
        lh.beforeInsert();
        //lh.afterInsert();
        
        boolean exists = false;
        Test.startTest();
		
        for (Lead lead : leads) {
            if (lead.Company == 'No company registered.') {
        		exists = true;
            }
        }
        //System.assert(currentLead.Company == 'No company registered.');
		System.assert(exists);
        Test.stopTest();
    }
}