//SFESWCSD-92
@IsTest
private class KenticoDonationRestServiceTest {
    @TestSetup
    static void setupData() {
        
        List<Campaign> campaigns = new List<Campaign>();
        
        campaigns.add(new Campaign(
            Name = 'Test Campaign I08',
            IsActive = true,
            Campaign_ID__c = 'I08'
        ));
        
        campaigns.add(new Campaign(
            Name = 'Test Campaign I09',
            IsActive = true,
            Campaign_ID__c = 'I09'
        ));
        
        insert campaigns;
    }        
        
    @IsTest
    static void testProcessRecurringDonation() {

        String requestBody =
            '{' +
                '"transactionType":"Donation",' +
                '"donorType":"Individual",' +
                '"donationType":"Recurring",' +
                '"donationId":"DON-2026-000002",' +

                '"sponsorshipType":null,' +
                '"sponsorshipCategory":null,' +
                '"sponsorshipLocation":null,' +
                '"sponsorshipAgePreference":null,' +
                '"sponsorshipPreference":null,' +
                '"sponsorshipId":null,' +

                '"amount":20.00,' +
                '"installmentPeriod":"Monthly",' +
                '"dateEstablished":"2026-08-11",' +

                '"salutation":"Ms",' +
                '"firstName":"Sarah",' +
                '"lastName":"Johnson",' +
                '"email":"sarah.johnson@example.com",' +
                '"phone":"+251922123456",' +
                '"birthday":"1990-03-20",' +
                '"gender":"Female",' +

                '"mailingStreet":"45 Bole Road",' +
                '"mailingCity":"Addis Ababa",' +
                '"mailingState":"Addis Ababa",' +
                '"mailingPostalCode":"1000",' +
                '"mailingCountry":"Ethiopia",' +

                '"accountName":null,' +

                '"emailOptOut":false,' +
                '"personalDataConsent":true,' +
                '"childDataSafeguarding":false,' +

                '"campaign":"I08",' +
                '"recurringUUID":"ARIFPAY-REC-20260811-000001",' +

                '"paymentMethod":"ArifPay",' +
                '"paymentType":"CreditCard",' +

                '"source":"Digital Media"' +
            '}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/donation/oneOffCommitted';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);

        RestResponse res = new RestResponse();

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();

        OneOffCommittedDonationRestService.process();

        Test.stopTest();

        System.assertEquals(
            200,
            RestContext.response.statusCode,
            'The REST service should return HTTP 200.'
        );

        System.assertNotEquals(
            null,
            RestContext.response.responseBody,
            'The response body should not be null.'
        );

        System.debug(
            'Response: ' +
            RestContext.response.responseBody.toString()
        );
    }
    
    
    @IsTest
    static void testProcessSponsorship() {
        
        String requestBody =
            '{' +
            '"transactionType":"Donation",' +
            '"donorType":"Individual",' +
            '"donationType":"Sponsorship",' +
            '"donationId":"DON-2026-000004",' +
            
            '"sponsorshipType":"Child Sponsorship",' +
            '"sponsorshipCategory":"Education",' +
            '"sponsorshipLocation":"Addis Ababa",' +
            '"sponsorshipAgePreference":"6-10",' +
            '"sponsorshipPreference":"Any",' +
            '"sponsorshipId":"SP-2026-000123",' +
            
            '"amount":30.00,' +
            '"installmentPeriod":"Monthly",' +
            '"dateEstablished":"2026-08-11",' +
            
            '"salutation":"Mr",' +
            '"firstName":"David",' +
            '"lastName":"Wilson",' +
            '"email":"david.wilson@example.com",' +
            '"phone":"+251933456789",' +
            '"birthday":"1988-10-12",' +
            '"gender":"Male",' +
            
            '"mailingStreet":"25 Churchill Avenue",' +
            '"mailingCity":"Addis Ababa",' +
            '"mailingState":"Addis Ababa",' +
            '"mailingPostalCode":"1000",' +
            '"mailingCountry":"Ethiopia",' +
            
            '"accountName":null,' +
            
            '"emailOptOut":false,' +
            '"personalDataConsent":true,' +
            '"childDataSafeguarding":true,' +
            
            '"campaign":"I09",' +
            '"recurringUUID":"ARIFPAY-REC-20260811-000002",' +
            
            '"paymentMethod":"ArifPay",' +
            '"paymentType":"CreditCard",' +
            
            '"source":"Website"' +
            '}';
        
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/donation/oneOffCommitted/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        
        OneOffCommittedDonationRestService.process();
        
        Test.stopTest();
        
        System.assertEquals(
            200,
            RestContext.response.statusCode
        );
        
        System.assertNotEquals(
            null,
            RestContext.response.responseBody
        );
    }    
}