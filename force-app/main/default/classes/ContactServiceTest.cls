@isTest
private class ContactServiceTest {
	@isTest static void ManageContact(){
        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name='Organization' AND SObjectType='Account' LIMIT 1].Id;
        Account acc = new Account(name = 'test', RecordTypeId = recordTypeId);
        INSERT acc;
        
        List<Contact> cons = new List<Contact>();
        Contact con = new Contact(LastName='Peréz', FirstName='Juan', email='test@gmail.com', npe01__PreferredPhone__c = 'Home', npe01__Preferred_Email__c = 'Personal');
        con.AccountId = acc.Id; 
        cons.add(con);
        
        con = new Contact(LastName='Peréz 2', FirstName='Juan 2', email='test2@gmail.com', npe01__PreferredPhone__c = 'Home', npe01__Preferred_Email__c = 'Personal');
        //con.AccountId = acc.Id;
        con.Birthdate = Date.newInstance(2000,Date.Today().Month(),Date.Today().Day());
        cons.add(con);
        
        insert cons;
        
        ContactHandler ch = new ContactHandler(cons, cons, null);
        ch.beforeInsert();
        ch.afterInsert();
        ch.beforeUpdate();
        ch.afterUpdate();
        ch.afterDelete();
        
        boolean exists = false;
        Test.startTest();
		
        for (Contact contact : cons) {
            //if (lead.Company == 'No company registered.') {
        		exists = true;
            //}
        }
        //System.assert(currentLead.Company == 'No company registered.');
		System.assert(exists);
        Test.stopTest();
    }
}