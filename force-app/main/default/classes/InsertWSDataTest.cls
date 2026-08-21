/**
 * Created by Jorge on 13/11/2024.
 */

@isTest
private with sharing class InsertWSDataTest { 
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
    
    @isTest static void createSecondRD() {
        Id cont1 = [SELECT Id FROM Contact WHERE email = 'test2@gmail.com' LIMIT 1].Id;
        npe03__Recurring_Donation__c recurringDonation = new npe03__Recurring_Donation__c(
            npe03__Amount__c = 1000,
            //npe03__Organization__c = acc.Id,
            npe03__Contact__c = cont1,
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
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;
		InsertWSData.CreateWSTransaction();       
    }
    
    @isTest static void WrongEmailTransaction() {
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
            '"Email":"dsiangu@gmail@@.com",\n' +
            '"Phone":"12343535",\n' +
            '"PhoneArea":"NA(+264)",\n' +
            '"Newsletter":"False",\n' +
            '"DonationId":"60106-7937174362",\n' +
            '"Amount":"200.00",\n' +
            '"Frequency":"annual"}';
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;
		InsertWSData.CreateWSTransaction();       
    }
    
    @isTest static void WrongAmountTransaction() {
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
            '"Email":"dsiangugmail@.com",\n' +
            '"Phone":"12343535",\n' +
            '"PhoneArea":"NA(+264)",\n' +
            '"Newsletter":"False",\n' +
            '"DonationId":"60106-7937174362",\n' +
            '"Amount":"200AEDX|.00",\n' +
            '"Frequency":"monthly"}';
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;
		InsertWSData.CreateWSTransaction();       
    }
    
    @isTest static void WrongPhoneTransaction() {
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
            '"Email":"dsiangugmail@.com",\n' +
            '"Phone":"12343535AAA",\n' +
            '"PhoneArea":"NA(+264)",\n' +
            '"Newsletter":"False",\n' +
            '"DonationId":"60106-7937174362",\n' +
            '"Amount":"200.00",\n' +
            '"Frequency":"monthly"}';
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;
		InsertWSData.CreateWSTransaction();       
    }
    
    @isTest static void CreateCommonTransaction() {
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
            '"DonationId":"60106-7937174362",\n' +
            '"Amount":"200.00",\n' +
            '"Frequency":"monthly"}';
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }
    
    @isTest static void CreateOneOffTransactionWithNoPayment() {
        String JsonMsg = '{\n' +
            '"TransactionId":"638759991155797803",\n' +
            '"TransactionDate":"20250224130515",\n' +
            '"FormType":"One-time Donation",\n' +
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
            '"DonationId":"60106-7937174362",\n' +
            '"Amount":"200.00",\n' +
            '"Frequency":"one-off"}';
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }
    
    @isTest static void CreateAnuallyTransactionWithNoPayment() {
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
            '"DonationId":"60106-7937174362",\n' +
            '"Amount":"200.00",\n' +            
            '"facerID":"1122",\n' +
            '"locationID":"101094",\n' +
            '"FacerLocationId":"101094",\n' +            
            '"Frequency":"anually"}';
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }
    
    @isTest static void CreateCommonTransactionWithNoPayment() {
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
            '"DonationId":"60106-7937174362",\n' +
            '"Amount":"200.00",\n' +
            '"PaymentStatus":"False",\n' +
            '"PaymentType":"Credit",\n' +
            '"Frequency":"monthly"}';
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }
    
    @isTest static void CreateCommonTransaction_SamePhoneNumber() {
        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;
		String samephone = 'NA(+264)12343535';
        Account acc = new Account(name = 'test', RecordTypeId = recordTypeId);
        insert acc;
        Contact con = new Contact(LastName = 'Peréz', FirstName = 'Juan', AccountId = acc.Id, Phone = samephone, email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con;
        List<Contact> cons = [SELECT Phone FROM Contact];
        System.debug('Cons: ' + cons);
        
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
            '"DonationId":"60106-7937174362",\n' +
            '"Amount":"200.00",\n' +
            '"Frequency":"monthly"}';
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }
    
    @isTest static void GeneralDonation_Monthly_ExistingContact_Company() {
        //String recordTypeICD = '0120D0000004KPdQAM';
        String recordTypeICD = RecordTypeUtils.getRecordTypeId('npe03__Recurring_Donation__c', 'Individual Committed Donation'); //'0121t0000005sKyAAI';

        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;

        Account acc = new Account(name = 'test', RecordTypeId = recordTypeId);
        insert acc;
        Contact con = new Contact(LastName = 'Peréz 2', FirstName = 'Juan 3', AccountId = acc.Id, Phone = '98475934758 4', email = 'test5634@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con;
        Contact con1 = new Contact(LastName = 'Peréz', FirstName = 'Juan Manuel', AccountId = acc.Id, Phone = '98475934758', email = 'test21@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con1;

        /*Other_Participation__c op = new Other_Participation__c();
        op.Contact__c = con1.Id;
        op.Name = 'Facer';
        op.Facer_Code__c = '123014';
        insert op;

        Location__c l = new Location__c();
        l.Name = 'Test';
        l.Location_ID__c = '36';
        insert l;*/

        npe03__Recurring_Donation__c donation9 = new npe03__Recurring_Donation__c(
            //RecordTypeId = recordTypeICD,
            Name = 'ICD TEST 4 21',
            npe03__Open_Ended_Status__c = 'Open',
            npe03__Schedule_Type__c = 'Monthly',
            npe03__Installment_Period__c = 'Monthly',
            npe03__Contact__c = con.id,
            npsp__PaymentMethod__c = 'Check',
            npe03__Last_Payment_Date__c = System.today(),
            npe03__Next_Payment_Date__c = System.today(),
            Donor_Type__c = 'Corporate', 
            Donation_Type__c = 'Recurring Donation',
            npe03__Amount__c = 1000);
        insert donation9;
        List<Contact> lstCon = new List<Contact> ();
        String JsonMsg = '{\n' +
                '"frequencyOfDonation" : "monthly",\n' +
                '"amount" : "50",\n' +
                '"donationSubType" : "general",\n' +
                '"startDate" : "2023-08-15",\n' +
                '"firstName" : "Michael",\n' +
                '"lastName" : "Jackson",\n' +
                '"email" : "email@email.com",\n' +
                '"phone": "995654245",\n' +
                '"campaignID": "I01",\n' +
                '"paymentStatus": "True",\n' +
                '"responseCode": "SampleCode",\n' +
                '"responseMessage": "SampleMessage",\n' +
                '"cardHolderID": "SampleCardHolderID",\n' +
                '"orderID": "SampleOrderID",\n' +
                '"paymentID": "SamplePaymentID",\n' +
                '"personalDataProtectionPolicy": "True",\n' +
                '"dedicatedTo": "SampleText",\n' +
                '"coverTransactionsCosts": "True",\n' +
                '"expDate": "2026-08-15",\n' +
                '"address":"address",\n' +
                '"postalCode":"01256",\n' +
            	'"AddressType":"01256",\n' +
            	'"CompanyName":"01256",\n' +
                '"city":"city",\n' +
                '"country":"country",\n' +
            	'"TransactionDate":"20250101102030",\n' +
                '"dateOfBirth":"2000-08-08"\n' +
                '}';
        system.debug('JsonMsg:' + JsonMsg);

        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = con.Id;
        Test.setFixedSearchResults(fixedSearchResults);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }

    @isTest static void GeneralDonation_Oneoff_NonExistingContact() {
        //String recordTypeICD = '0120D0000004KPdQAM';
        String recordTypeICD = RecordTypeUtils.getRecordTypeId('npe03__Recurring_Donation__c', 'Individual Committed Donation'); //'0121t0000005sKyAAI';

        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;

        Account acc = new Account(name = 'test2', RecordTypeId = recordTypeId);
        insert acc;
        Contact con = new Contact(LastName = 'Peréz', FirstName = 'Juan', AccountId = acc.Id, Phone = '98475934758', email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con;
        Contact con1 = new Contact(LastName = 'Peréz', FirstName = 'Juan Manuel', AccountId = acc.Id, Phone = '98475934758', email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con1;

        /*Other_Participation__c op = new Other_Participation__c();
        op.Contact__c = con1.Id;
        op.Name = 'Facer';
        op.Facer_Code__c = '123014';
        insert op;

        Location__c l = new Location__c();
        l.Name = 'Test';
        l.Location_ID__c = '36';
        insert l;*/

        npe03__Recurring_Donation__c donation9 = new npe03__Recurring_Donation__c(
            //RecordTypeId = recordTypeICD,
            npsp__PaymentMethod__c = 'Check',
            Name = 'ICD TEST 4',
            npe03__Open_Ended_Status__c = 'Open',
            npe03__Schedule_Type__c = 'Bimonthly',
            npe03__Installment_Period__c = 'Bimonthly',
            npe03__Contact__c = con.id,
            npe03__Last_Payment_Date__c = System.today(),
            npe03__Next_Payment_Date__c = System.today(),
            Donor_Type__c = 'Individual', 
            Donation_Type__c = 'Recurring Donation',
            npe03__Amount__c = 1000);
        insert donation9;
        List<Contact> lstCon = new List<Contact> ();
        String JsonMsg = '{\n' +
                '"frequencyOfDonation" : "oneoff",\n' +
                '"amount" : "50",\n' +
                '"donationSubType" : "general",\n' +
                '"startDate" : "2023-08-15",\n' +
                '"firstName" : "Michael",\n' +
                '"lastName" : "Jackson",\n' +
                '"email" : "emailXXX123@email.com",\n' +
                '"phone": "995654245",\n' +
                '"campaignID": "I01",\n' +
                '"paymentStatus": "True",\n' +
                '"responseCode": "SampleCode",\n' +
                '"responseMessage": "SampleMessage",\n' +
                '"cardHolderID": "SampleCardHolderID",\n' +
                '"orderID": "SampleOrderID",\n' +
                '"paymentID": "SamplePaymentID",\n' +
                '"personalDataProtectionPolicy": "True",\n' +
                '"dedicatedTo": "SampleText",\n' +
                '"coverTransactionsCosts": "True",\n' +
                '"expDate": "2026-08-15",\n' +
                '"address":"address",\n' +
                '"postalCode":"01256",\n' +
                '"city":"city",\n' +
                '"country":"country",\n' +
            	'"TransactionDate":"20250101102030",\n' +
                '"dateOfBirth":"2000-08-08"\n' +
            	'"FormType":"One-time Donation",\n' +
            	'"FacerLocationId":"101094",\n' +
            	'"campaignID":"New Campaign",\n' +
            	'"facerID":"1122"\n' +            
                '}';
        system.debug('JsonMsg:' + JsonMsg);

        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = con.Id;
        Test.setFixedSearchResults(fixedSearchResults);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }

    @isTest static void F2FDonation_Monthly_ExistingContact() {
        //String recordTypeICD = '0120D0000004KPdQAM';
        String recordTypeICD = RecordTypeUtils.getRecordTypeId('npe03__Recurring_Donation__c', 'Individual Committed Donation'); //'0121t0000005sKyAAI';

        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;

        Account acc = new Account(name = 'test', RecordTypeId = recordTypeId);
        insert acc;
        Contact con = new Contact(LastName = 'Peréz', FirstName = 'Juan', AccountId = acc.Id, Phone = '98475934758', email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con;
        Contact con1 = new Contact(LastName = 'Peréz', FirstName = 'Juan Manuel', AccountId = acc.Id, Phone = '98475934758', email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con1;

        /*Other_Participation__c op = new Other_Participation__c();
        op.Contact__c = con1.Id;
        op.Name = 'Facer';
        op.Facer_Code__c = '123014';
        insert op;

        Location__c l = new Location__c();
        l.Name = 'Test';
        l.Location_ID__c = '36';
        insert l;*/

        npe03__Recurring_Donation__c donation9 = new npe03__Recurring_Donation__c(
            //RecordTypeId = recordTypeICD,
            Name = 'ICD TEST 4',
            npe03__Open_Ended_Status__c = 'Open',
            npe03__Schedule_Type__c = 'Bimonthly',
            npe03__Installment_Period__c = 'Bimonthly',
            npe03__Contact__c = con.id,
            npsp__PaymentMethod__c = 'Check',
            //npe03__Last_Payment_Date__c = Date.parse('02-07-2023'),
            //npe03__Next_Payment_Date__c = Date.parse('04-08-2023'),
            npe03__Last_Payment_Date__c = System.today(),
            npe03__Next_Payment_Date__c = System.today(),
            Donor_Type__c = 'Individual', 
            Donation_Type__c = 'Recurring Donation',
            npe03__Amount__c = 1000);
        insert donation9;
        List<Contact> lstCon = new List<Contact> ();
        String JsonMsg = '{\n' +
                '"frequencyOfDonation" : "monthly",\n' +
                '"amount" : "50",\n' +
                '"donationSubType" : "F2F",\n' +
                '"startDate" : "2023-08-15",\n' +
                '"firstName" : "Michael",\n' +
                '"lastName" : "Jackson",\n' +
                '"email" : "email@email.com",\n' +
                '"phone": "995654245",\n' +
                '"campaignID": "I01",\n' +
                '"paymentStatus": "True",\n' +
                '"responseCode": "SampleCode",\n' +
                '"responseMessage": "SampleMessage",\n' +
                '"cardHolderID": "SampleCardHolderID",\n' +
                '"orderID": "SampleOrderID",\n' +
                '"paymentID": "SamplePaymentID",\n' +
                '"personalDataProtectionPolicy": "True",\n' +
                '"dedicatedTo": "SampleText",\n' +
                '"coverTransactionsCosts": "True",\n' +
                '"expDate": "2026-08-15",\n' +
                '"address":"address",\n' +
                '"postalCode":"01256",\n' +
                '"city":"city",\n' +
                '"country":"country",\n' +
                '"facerID":"123014",\n' +
                '"locationID":"36",\n' +
            	'"TransactionDate":"20250101102030",\n' +
                '"dateOfBirth":"2000-08-08"\n' +
                '}';
        system.debug('JsonMsg:' + JsonMsg);

        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = con.Id;
        Test.setFixedSearchResults(fixedSearchResults);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }

    @isTest static void F2FDonation_Monthly_ExistingContact_PaymentFalse() {
        //String recordTypeICD = '0120D0000004KPdQAM';
        String recordTypeICD = RecordTypeUtils.getRecordTypeId('npe03__Recurring_Donation__c', 'Individual Committed Donation'); //'0121t0000005sKyAAI';

        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;

        Account acc = new Account(name = 'test', RecordTypeId = recordTypeId);
        insert acc;
        Contact con = new Contact(LastName = 'Peréz', FirstName = 'Juan', AccountId = acc.Id, Phone = '98475934758', email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con;
        Contact con1 = new Contact(LastName = 'Peréz', FirstName = 'Juan Manuel', AccountId = acc.Id, Phone = '98475934758', email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con1;

        /*Other_Participation__c op = new Other_Participation__c();
        op.Contact__c = con1.Id;
        op.Name = 'Facer';
        op.Facer_Code__c = '123014';
        insert op;

        Location__c l = new Location__c();
        l.Name = 'Test';
        l.Location_ID__c = '36';
        insert l;*/

        npe03__Recurring_Donation__c donation9 = new npe03__Recurring_Donation__c(
            //RecordTypeId = recordTypeICD,
            Name = 'ICD TEST 4',
            npe03__Open_Ended_Status__c = 'Open',
            npe03__Schedule_Type__c = 'Bimonthly',
            npe03__Installment_Period__c = 'Bimonthly',
            npe03__Contact__c = con.id,
            npsp__PaymentMethod__c = 'Check',
            //npe03__Last_Payment_Date__c = Date.parse('02-07-2023'),
            //npe03__Next_Payment_Date__c = Date.parse('04-08-2023'),
            npe03__Last_Payment_Date__c = System.today(),
            npe03__Next_Payment_Date__c = System.today(),
            Donor_Type__c = 'Individual', 
            Donation_Type__c = 'Recurring Donation',
            npe03__Amount__c = 1000);
        insert donation9;
        List<Contact> lstCon = new List<Contact> ();
        String JsonMsg = '{\n' +
                '"frequencyOfDonation" : "monthly",\n' +
                '"amount" : "50",\n' +
                '"donationSubType" : "F2F",\n' +
                '"startDate" : "2023-08-15",\n' +
                '"firstName" : "Michael",\n' +
                '"lastName" : "Jackson",\n' +
                '"email" : "email@email.com",\n' +
                '"phone": "995654245",\n' +
                '"campaignID": "I01",\n' +
                '"paymentStatus": "False",\n' +
                '"responseCode": "SampleCode",\n' +
                '"responseMessage": "SampleMessage",\n' +
                '"cardHolderID": "SampleCardHolderID",\n' +
                '"orderID": "SampleOrderID",\n' +
                '"paymentID": "SamplePaymentID",\n' +
                '"personalDataProtectionPolicy": "True",\n' +
                '"dedicatedTo": "SampleText",\n' +
                '"coverTransactionsCosts": "False",\n' +
                '"expDate": "2026-08-15",\n' +
                '"address":"address",\n' +
                '"postalCode":"01256",\n' +
                '"city":"city",\n' +
            	'"facerID":"123014",\n' +
                '"locationID":"36",\n' +
                '"country":"country",\n' +
            	'"TransactionDate":"20250101102030",\n' +
                '"dateOfBirth":"2000-08-08"\n' +
                '}';
        system.debug('JsonMsg:' + JsonMsg);

        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = con.Id;
        Test.setFixedSearchResults(fixedSearchResults);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }

    @isTest static void F2FDonation_Monthly_NonExistingContact_PaymentFalse() {
        //String recordTypeICD = '0120D0000004KPdQAM';
        String recordTypeICD = RecordTypeUtils.getRecordTypeId('npe03__Recurring_Donation__c', 'Individual Committed Donation'); //'0121t0000005sKyAAI';

        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;

        Account acc = new Account(name = 'test', RecordTypeId = recordTypeId);
        insert acc;
        Contact con = new Contact(LastName = 'Peréz', FirstName = 'Juan', AccountId = acc.Id, Phone = '33666555', email = 'xyz@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con;
        Contact con1 = new Contact(LastName = 'Peréz', FirstName = 'Juan Manuel', AccountId = acc.Id, Phone = '9966332255', email = 'xxx@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con1;

        /*Other_Participation__c op = new Other_Participation__c();
        op.Contact__c = con1.Id;
        op.Name = 'Facer';
        op.Facer_Code__c = '123014';
        insert op;

        Location__c l = new Location__c();
        l.Name = 'Test';
        l.Location_ID__c = '36';
        insert l;*/

        npe03__Recurring_Donation__c donation9 = new npe03__Recurring_Donation__c(
            //RecordTypeId = recordTypeICD,
            Name = 'ICD TEST 4',
            npe03__Open_Ended_Status__c = 'Open',
            npe03__Schedule_Type__c = 'Bimonthly',
            npe03__Installment_Period__c = 'Bimonthly',
            npe03__Contact__c = con.id,
            npsp__PaymentMethod__c = 'Check',
            Donor_Type__c = 'Individual', 
            Donation_Type__c = 'Recurring Donation',
            //npe03__Last_Payment_Date__c = Date.parse('02-07-2023'),
            //npe03__Next_Payment_Date__c = Date.parse('04-08-2023'),
            npe03__Last_Payment_Date__c = System.today(),
            npe03__Next_Payment_Date__c = System.today(),
            npe03__Amount__c = 1000);
        insert donation9;
        List<Contact> lstCon = new List<Contact> ();
        String JsonMsg = '{\n' +
                '"frequencyOfDonation" : "monthly",\n' +
                '"amount" : "50",\n' +
                '"donationSubType" : "F2F",\n' +
                '"startDate" : "2023-08-15",\n' +
                '"firstName" : "Non",\n' +
                '"lastName" : "Existing",\n' +
                '"email" : "non@exist.com",\n' +
                '"phone": "223355888",\n' +
                '"campaignID": "I01",\n' +
                '"paymentStatus": "False",\n' +
                '"responseCode": "SampleCode",\n' +
                '"responseMessage": "SampleMessage",\n' +
                '"cardHolderID": "SampleCardHolderID",\n' +
                '"orderID": "SampleOrderID",\n' +
                '"paymentID": "SamplePaymentID",\n' +
                '"personalDataProtectionPolicy": "True",\n' +
                '"dedicatedTo": "SampleText",\n' +
                '"coverTransactionsCosts": "False",\n' +
                '"expDate": "2026-08-15",\n' +
                '"address":"address",\n' +
                '"postalCode":"01256",\n' +
                '"city":"city",\n' +
                '"country":"country",\n' +
            	'"facerID":"123014",\n' +
                '"locationID":"36",\n' +
            	'"TransactionDate":"20250101102030",\n' +
                '"dateOfBirth":"2000-08-08"\n' +
                '}';
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();

        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = con.Id;
        Test.setFixedSearchResults(fixedSearchResults);


    }

    @isTest static void PayrollDonation_Monthly_ExistingContact() {
        //String recordTypeICD = '0120D0000004KPdQAM';
        String recordTypeICD = RecordTypeUtils.getRecordTypeId('npe03__Recurring_Donation__c', 'Individual Committed Donation'); //'0121t0000005sKyAAI';

        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;

        Account acc = new Account(name = 'test', RecordTypeId = recordTypeId);
        insert acc;
        Contact con = new Contact(LastName = 'Peréz', FirstName = 'Juan', AccountId = acc.Id, Phone = '98475934758', email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con;
        Contact con1 = new Contact(LastName = 'Peréz', FirstName = 'Juan Manuel', AccountId = acc.Id, Phone = '98475934758', email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con1;

        /*Other_Participation__c op = new Other_Participation__c();
        op.Contact__c = con1.Id;
        op.Name = 'Facer';
        op.Facer_Code__c = '123014';
        insert op;

        Location__c l = new Location__c();
        l.Name = 'Test';
        l.Location_ID__c = '36';
        insert l;*/

        npe03__Recurring_Donation__c donation9 = new npe03__Recurring_Donation__c(
            //RecordTypeId = recordTypeICD,
            Name = 'ICD TEST 4',
            npe03__Open_Ended_Status__c = 'Open',
            npe03__Schedule_Type__c = 'Bimonthly',
            npe03__Installment_Period__c = 'Bimonthly',
            npe03__Contact__c = con.id,
            npsp__PaymentMethod__c = 'Check',
            //npe03__Last_Payment_Date__c = Date.parse('02-07-2023'),
            //npe03__Next_Payment_Date__c = Date.parse('04-08-2023'),
            npe03__Last_Payment_Date__c = System.today(),
            npe03__Next_Payment_Date__c = System.today(),
            Donor_Type__c = 'Individual', 
            Donation_Type__c = 'Recurring Donation',
            npe03__Amount__c = 1000);
        insert donation9;
        List<Contact> lstCon = new List<Contact> ();
        String JsonMsg = '{\n' +
                '"frequencyOfDonation" : "monthly",\n' +
                '"amount" : "50",\n' +
                '"donationSubType" : "payroll",\n' +
                '"startDate" : "2023-08-15",\n' +
                '"firstName" : "Michael",\n' +
                '"lastName" : "Jackson",\n' +
                '"email" : "email@email.com",\n' +
                '"phone": "995654245",\n' +
                '"campaignID": "I01",\n' +
                '"paymentStatus": "True",\n' +
                '"responseCode": "SampleCode",\n' +
                '"responseMessage": "SampleMessage",\n' +
                '"cardHolderID": "SampleCardHolderID",\n' +
                '"orderID": "SampleOrderID",\n' +
                '"paymentID": "SamplePaymentID",\n' +
                '"personalDataProtectionPolicy": "True",\n' +
                '"dedicatedTo": "SampleText",\n' +
                '"coverTransactionsCosts": "True",\n' +
                '"expDate": "2026-08-15",\n' +
                '"address":"address",\n' +
                '"postalCode":"01256",\n' +
                '"city":"city",\n' +
                '"country":"country",\n' +
            	'"facerID":"123014",\n' +
                '"locationID":"36",\n' +
            	'"TransactionDate":"20250101102030",\n' +
                '"dateOfBirth":"2000-08-08"\n' +
                '}';
        system.debug('JsonMsg:' + JsonMsg);

        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = con.Id;
        Test.setFixedSearchResults(fixedSearchResults);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }

    @isTest static void AmountEmpty() {

        String JsonMsg = '{\n' +
                '"frequencyOfDonation" : "monthly",\n' +
                '"amount" : "",\n' +
                '"donationSubType" : "payroll",\n' +
                '"startDate" : "2023-08-15",\n' +
                '"firstName" : "Michael",\n' +
                '"lastName" : "Jackson",\n' +
                '"email" : "email@email.com",\n' +
                '"phone": "995654245",\n' +
                '"campaignID": "I01",\n' +
                '"paymentStatus": "True",\n' +
                '"responseCode": "SampleCode",\n' +
                '"responseMessage": "SampleMessage",\n' +
                '"cardHolderID": "SampleCardHolderID",\n' +
                '"orderID": "SampleOrderID",\n' +
                '"paymentID": "SamplePaymentID",\n' +
                '"personalDataProtectionPolicy": "True",\n' +
                '"dedicatedTo": "SampleText",\n' +
                '"coverTransactionsCosts": "True",\n' +
                '"expDate": "2026-08-15",\n' +
                '"address":"address",\n' +
                '"postalCode":"01256",\n' +
                '"city":"city",\n' +
                '"country":"country",\n' +
            	'"TransactionDate":"20250101102030",\n' +
                '"dateOfBirth":"2000-08-08"\n' +
                '}';
        system.debug('JsonMsg:' + JsonMsg);



        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }

    @isTest static void UnitTest2() {
        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;
        Account acc = new Account(name = 'test', RecordTypeId = recordTypeId);
        insert acc;
        Contact con1 = new Contact(LastName = 'Peréz', FirstName = 'Juan Manuel', AccountId = acc.Id, Phone = '98475934758', Email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con1;
        Contact con = new Contact(Id = '0031w00000XQg2JAAT', LastName = 'Peréz', FirstName = 'Juan', AccountId = acc.Id, Email = 'test@gmail.com', Phone = '98475934758', npo02__FirstCloseDate__c = Date.today().addDays(20));
        List<Contact> lstCon = new List<Contact> ();
        String JsonMsg = JSON.serialize(con);
        system.debug('JsonMsg:' + JsonMsg);

        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = con1.Id;
        Test.setFixedSearchResults(fixedSearchResults);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }

    @isTest static void UnitTest3() {
        //String recordTypeICD = '0120D0000004KPdQAM';
        String recordTypeICD = RecordTypeUtils.getRecordTypeId('npe03__Recurring_Donation__c', 'Individual Committed Donation'); //'0121t0000005sKyAAI';

        Id recordTypeId = [SELECT Id FROM RecordType WHERE Name = 'Organization' AND SObjectType = 'Account' LIMIT 1].Id;

        Account acc = new Account(name = 'test', RecordTypeId = recordTypeId);
        insert acc;
        Contact con = new Contact(LastName = 'Peréz', FirstName = 'Juan', AccountId = acc.Id, Phone = '98475934758', email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con;
        Contact con1 = new Contact(LastName = 'Peréz', FirstName = 'Juan Manuel', AccountId = acc.Id, Phone = '98475934758', email = 'test@gmail.com', npo02__FirstCloseDate__c = Date.today().addDays(20));
        insert con1;

        npe03__Recurring_Donation__c donation9 = new npe03__Recurring_Donation__c(
            //RecordTypeId = recordTypeICD,
            npsp__PaymentMethod__c = 'Check',
            Name = 'ICD TEST 4',
            npe03__Open_Ended_Status__c = 'Open',
            npe03__Schedule_Type__c = 'Bimonthly',
            npe03__Installment_Period__c = 'Bimonthly',
            npe03__Contact__c = con.id,
            npe03__Last_Payment_Date__c = System.today(),
            npe03__Next_Payment_Date__c = System.today(),
            Donor_Type__c = 'Individual', 
            Donation_Type__c = 'Recurring Donation',
            npe03__Amount__c = 1000);
        insert donation9;
        List<Contact> lstCon = new List<Contact> ();
        String JsonMsg = JSON.serialize(donation9);
        system.debug('JsonMsg:' + JsonMsg);

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }

    @isTest static void UnitErrorTest() {
        String JsonMsg = JSON.serialize('');

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/InsertWSData';
        req.httpMethod = 'POST';
        req.addHeader('Content-Type', 'application/json');
        req.requestBody = Blob.valueof(JsonMsg);
        RestContext.request = req;
        RestContext.response = res;

        InsertWSData.CreateWSTransaction();
    }
}