@isTest
private with sharing class InsertDPOPaymentResponseTest { 
    @testSetup
    static void setupData() {
        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;
        Account acc = new Account(name = 'test 2', RecordTypeId = recordTypeId);
        insert acc;
        
        Contact con1 = new Contact(LastName = 'Peréz 2', FirstName = 'Juan Manuel 2', AccountId = acc.Id, Phone = '9847591111', email = 'test2@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con1;
        
        Other_Participation__c op = new Other_Participation__c (); 
        op.Facer_Code__c = '1122';
        op.Contact__c = con1.Id;
        INSERT op;
        
        Facer_Campaign__c fc = new Facer_Campaign__c();
        fc.Campaign_Name__c = 'Campaign Name'; 
        fc.Online_Campaign_Name__c = 'Online Campaign Name';
        fc.Facer_ID__c = '1122';
        INSERT fc;
        
        Location__c c = new Location__c();
        c.Location_ID__c = '101094';
        INSERT c;
        
        Campaign cp = new Campaign();
        cp.Name = 'New Campaign';
        INSERT cp;
        
        // Create Recurring Donation
        npe03__Recurring_Donation__c recurringDonation = new npe03__Recurring_Donation__c(
            npe03__Amount__c = 1000,
            //npe03__Organization__c = acc.Id,
            npe03__Contact__c = con1.Id,
            npsp__Day_of_Month__c = '1',
            npe03__Open_Ended_Status__c = 'Open',
            Donor_Type__c = 'Individual', 
            Donation_Type__c = 'Recurring Donation',
            transaction_ID__c = '123456',
            Donation_ID__c = 'AAAAA',
            npsp__Status__c = 'Active',
            npe03__Installment_Period__c = 'Monthly',
            npsp__InstallmentFrequency__c = 3
        );
        insert recurringDonation;
    }
    
    @isTest static void NewPaymentTest() {
        for (npe01__OppPayment__c pay : [SELECT npe01__Opportunity__r.npe03__Recurring_Donation__r.Donation_ID__c, npe01__Opportunity__r.Donation_ID__c FROM npe01__OppPayment__c ORDER BY npe01__Scheduled_Date__c]) {
            System.debug('rds Donation_ID__c:' + pay.npe01__Opportunity__r.Donation_ID__c);
            System.debug('rds Name:' + pay.npe01__Opportunity__r.npe03__Recurring_Donation__r.Donation_ID__c);            
        }
        String donationName = [SELECT Donation_ID__c FROM npe03__Recurring_Donation__c LIMIT 1].Donation_ID__c;
        String JsonMsg = '{\n' +
            '"TransactionId":"638759991155797803",\n' +
            '"TransactionDate":"20250224130515",\n' +
            '"FormType":"Recurring Donation",\n' +
            '"Salutation":"Mr.",\n' +
            '"FirstName":"Dan",\n' +
            '"LastName":"Mulupi",\n' +
            '"AddressLine1":"Test ksjdksd",\n' +
            '"Zip":"23400",\n' +
            '"City":"NBO",\n' +
            '"Region":"Erongo",\n' +
            '"Country":"NA",\n' +
            '"Email":"dsiangu@gmail.com",\n' +
            '"Phone":"12343535",\n' +
            '"PhoneArea":"NA(+264)",\n' +
            '"Newsletter":"False",\n' +
            '"DonationId":"' + donationName+ '",\n' +
            '"Amount":"200.00",\n' +
            '"paymentType":"Credit Card",\n' +
            '"CreditCardExpiry":"102026",\n' +
            '"CreditCardNumber":"2211333212101094",\n' +
            '"CreditCardHolder":"Mr.Lee",\n' +
            '"Frequency":"annual"}';
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertDPOPaymentResponse';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;
		InsertDPOPaymentResponse.CreateWSTransaction();       
    }
}