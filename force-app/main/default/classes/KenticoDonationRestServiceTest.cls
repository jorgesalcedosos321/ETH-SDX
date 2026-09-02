//SFESWCSD-92
@IsTest
private class KenticoDonationRestServiceTest {
    @TestSetup
    static void setupData() {
        insert new Campaign(Name = 'REST Test Campaign', IsActive = true, Campaign_ID__c = 'REST-TEST-CAMPAIGN');
    }

    @IsTest
    static void processesIndividualOneOffDonation() {
        DonationRequest request = baseRequest(ApiConstants.DONOR_INDIVIDUAL);
        request.donationType = ApiConstants.DONATION_ONE_OFF;
        request.paymentType = ApiConstants.PAYMENT_ONE_TIME;
        invokeOneOff(request);

        Contact donor = [SELECT Id, AccountId FROM Contact WHERE Email = :request.email LIMIT 1];
        Opportunity donation = donationFromResponse();
        Assert.areEqual(200, RestContext.response.statusCode, responseBody());
        Assert.isNotNull(donor.AccountId);
        Assert.areEqual(donor.AccountId, donation.AccountId);
        Assert.areEqual(
            1,
            [
                SELECT COUNT()
                FROM npe01__OppPayment__c
                WHERE npe01__Opportunity__c = :donation.Id
            ],
            'A one-time Opportunity must have exactly one Payment.'
        );
    }

    @IsTest
    static void processesCorporateOneOffDonation() {
        DonationRequest request = baseRequest(ApiConstants.DONOR_CORPORATE);
        request.donationType = ApiConstants.DONATION_ONE_OFF;
        request.paymentType = ApiConstants.PAYMENT_ONE_TIME;
        invokeOneOff(request);

        Account donor = [SELECT Id, Email__c, Phone FROM Account WHERE Name = :request.accountName LIMIT 1];
        Contact primaryContact = corporatePrimaryContact(request, donor.Id);
        Opportunity donation = donationFromResponse();
        Assert.areEqual(200, RestContext.response.statusCode, responseBody());
        Assert.areEqual(request.email, donor.Email__c);
        Assert.areEqual(request.phone, donor.Phone);
        Assert.areEqual(donor.Id, donation.AccountId);
        assertCorporateContactData(request, donor.Id, primaryContact);
        Assert.areEqual(primaryContact.Id, donation.npsp__Primary_Contact__c);
        Assert.areEqual(
            1,
            [
                SELECT COUNT()
                FROM npe01__OppPayment__c
                WHERE npe01__Opportunity__c = :donation.Id
            ],
            'A one-time Opportunity must have exactly one Payment.'
        );
    }

    @IsTest
    static void processesIndividualMonthlyRecurringDonation() {
        DonationRequest request = baseRequest(ApiConstants.DONOR_INDIVIDUAL);
        request.donationType = ApiConstants.DONATION_RECURRING;
        request.paymentType = ApiConstants.PAYMENT_RECURRING;
        request.frequency = ApiConstants.FREQUENCY_MONTHLY;
        request.dateEstablished = Date.today();
        request.recurringUUID = 'REST-MONTHLY-RECURRING-INDIVIDUAL';

        invokeOneOff(request);

        Assert.areEqual(200, RestContext.response.statusCode, responseBody());
        DonationResponse donationResponse = response();
        Opportunity generatedOpportunity = [
            SELECT Id, npe03__Recurring_Donation__r.Donation_Id__c
            FROM Opportunity
            WHERE Id = :donationResponse.donationId
        ];

        Assert.areEqual(
            request.recurringUUID,
            generatedOpportunity.npe03__Recurring_Donation__r.Donation_Id__c
        );
        Assert.areEqual(
            1,
            [
                SELECT COUNT()
                FROM npe01__OppPayment__c
                WHERE npe01__Opportunity__c = :generatedOpportunity.Id
            ]
        );
    }

    @IsTest
    static void processesIndividualSponsorship() {
        DonationRequest request = sponsorshipRequest(ApiConstants.DONOR_INDIVIDUAL);
        invokeSponsorship(request);

        Assert.areEqual(200, RestContext.response.statusCode, responseBody());
        Contact donor = [SELECT Id FROM Contact WHERE Email = :request.email LIMIT 1];
        npe03__Recurring_Donation__c recurringDonation = recurringDonationFromResponse();
        Assert.areEqual(donor.Id, recurringDonation.npe03__Contact__c);
        Assert.isNull(recurringDonation.npe03__Organization__c);
        Assert.areEqual(ApiConstants.DONOR_INDIVIDUAL, recurringDonation.Donor_Type__c);
        Assert.areEqual('020-502-0001', recurringDonation.Sponsorship_ID__c);

        request.recurringUUID = request.recurringUUID + '-SECOND';
        npe03__Recurring_Donation__c secondSponsorship =
            RecurringDonationService.createSponsorship(request, donor.Id);
        Assert.areEqual('020-502-0002', secondSponsorship.Sponsorship_ID__c);

    }

    @IsTest
    static void processesCorporateSponsorship() {
        DonationRequest request = sponsorshipRequest(ApiConstants.DONOR_CORPORATE);
        invokeSponsorship(request);

        Assert.areEqual(200, RestContext.response.statusCode, responseBody());
        Account donor = [SELECT Id FROM Account WHERE Name = :request.accountName LIMIT 1];
        Contact primaryContact = corporatePrimaryContact(request, donor.Id);
        npe03__Recurring_Donation__c recurringDonation = recurringDonationFromResponse();
        Opportunity donation = donationFromResponse();
        Assert.areEqual(donor.Id, recurringDonation.npe03__Organization__c);
        Assert.isNull(recurringDonation.npe03__Contact__c);
        Assert.areEqual(ApiConstants.DONOR_CORPORATE, recurringDonation.Donor_Type__c);
        Assert.areEqual('020-502-0001', recurringDonation.Sponsorship_ID__c);
        assertCorporateContactData(request, donor.Id, primaryContact);
        Assert.areEqual(primaryContact.Id, donation.npsp__Primary_Contact__c);

    }

    @IsTest
    static void ignoresInvalidCorporateContactPicklistValues() {
        DonationRequest request = baseRequest(ApiConstants.DONOR_CORPORATE);
        request.donationType = ApiConstants.DONATION_ONE_OFF;
        request.paymentType = ApiConstants.PAYMENT_ONE_TIME;
        request.donationId = 'REST-DONATION-CORPORATE-INVALID-PICKLISTS';
        request.accountName = 'REST Corporate Invalid Picklists';
        request.email = 'invalid-picklists@example.com';
        request.gender = 'Not a configured gender';
        request.source = 'Not a configured source';

        invokeOneOff(request);

        Assert.areEqual(200, RestContext.response.statusCode, responseBody());
        Contact primaryContact = [
            SELECT Gender__c, Source__c
            FROM Contact
            WHERE Email = :request.email
            LIMIT 1
        ];
        Assert.isNull(primaryContact.Gender__c);
        Assert.isNull(primaryContact.Source__c);
    }

    @IsTest
    static void oneOffEndpointRejectsSponsorshipPayload() {
        DonationRequest request = sponsorshipRequest(ApiConstants.DONOR_INDIVIDUAL);
        invokeOneOff(request);
        Assert.areEqual(400, RestContext.response.statusCode);
    }

    @IsTest
    static void sponsorshipEndpointRejectsOneOffPayload() {
        DonationRequest request = baseRequest(ApiConstants.DONOR_INDIVIDUAL);
        request.donationType = ApiConstants.DONATION_ONE_OFF;
        request.paymentType = ApiConstants.PAYMENT_ONE_TIME;
        invokeSponsorship(request);
        Assert.areEqual(400, RestContext.response.statusCode);
    }

    @IsTest
    static void oneOffEndpointReturnsValidationError() {
        DonationRequest oneOffRequest = baseRequest(ApiConstants.DONOR_INDIVIDUAL);
        oneOffRequest.donationType = ApiConstants.DONATION_ONE_OFF;
        oneOffRequest.paymentType = ApiConstants.PAYMENT_ONE_TIME;
        oneOffRequest.email = null;
        invokeOneOff(oneOffRequest);
        Assert.areEqual(400, RestContext.response.statusCode);
    }

    @IsTest
    static void sponsorshipEndpointReturnsValidationError() {
        DonationRequest sponsorRequest = sponsorshipRequest(
            ApiConstants.DONOR_CORPORATE
        );
        sponsorRequest.accountName = null;
        invokeSponsorship(sponsorRequest);
        Assert.areEqual(400, RestContext.response.statusCode);
    }

    @IsTest
    static void endpointsReturnSystemErrorsForMalformedJson() {
        prepareMalformedRestRequest('/services/apexrest/donation/oneOffCommitted/');
        OneOffCommittedDonationRestService.process();
        Assert.areEqual(500, RestContext.response.statusCode);

        prepareMalformedRestRequest('/services/apexrest/donation/sponsorship/');
        SponsorshipDonationRestService.process();
        Assert.areEqual(500, RestContext.response.statusCode);
    }

    private static DonationRequest baseRequest(String donorType) {
        DonationRequest request = new DonationRequest();
        request.transactionType = 'Donation';
        request.donorType = donorType;
        request.donationId = 'REST-DONATION-' + donorType;
        request.donationAmount = 100;
        request.firstName = 'REST';
        request.lastName = 'Donor';
        request.salutation = 'Ms.';
        request.email = donorType.toLowerCase() + '@example.com';
        request.phone = donorType == ApiConstants.DONOR_CORPORATE ? '5551002000' : '5551001000';
        request.birthday = Date.newInstance(1990, 1, 15);
        request.gender = 'Female';
        request.accountName = 'REST Corporate Donor';
        request.city = 'Lima';
        request.country = 'Peru';
        request.mailingStreet = '123 Test Street';
        request.mailingState = 'Lima';
        request.mailingPostalCode = '15001';
        request.personalDataConsent = true;
        request.childDataSafeguarding = false;
        request.emailOptOut = false;
        request.campaignId = 'REST-TEST-CAMPAIGN';
        request.paymentMethod = ApiConstants.PAYMENT_CARD;
        request.source = 'Web';
        return request;
    }

    private static DonationRequest sponsorshipRequest(String donorType) {
        DonationRequest request = baseRequest(donorType);
        request.donationType = ApiConstants.DONATION_SPONSORSHIP;
        request.paymentType = ApiConstants.PAYMENT_RECURRING;
        request.frequency = ApiConstants.PERIOD_MONTHLY;
        request.dateEstablished = Date.today();
        request.recurringUUID = 'REST-RECURRING-' + donorType;
        request.sponsorshipType = ApiConstants.SPONSOR_CHILD;
        request.sponsorshipCategory = 'Education';
        request.villageSelection = 'Addis Ababa';
        request.age = '8 - 11 yrs';
        request.sponsorshipPreference = 'No Preference';
        request.sponsorshipId = 'REST-SPONSORSHIP-' + donorType;
        request.childDataSafeguarding = true;
        return request;
    }

    private static void invokeOneOff(DonationRequest request) {
        prepareRestRequest('/services/apexrest/donation/oneOffCommitted/', request);
        Test.startTest();
        OneOffCommittedDonationRestService.process();
        Test.stopTest();
    }

    private static void invokeSponsorship(DonationRequest request) {
        prepareRestRequest('/services/apexrest/donation/sponsorship/', request);
        Test.startTest();
        SponsorshipDonationRestService.process();
        Test.stopTest();
    }

    private static void prepareRestRequest(String uri, DonationRequest request) {
        RestRequest restRequest = new RestRequest();
        restRequest.requestURI = uri;
        restRequest.httpMethod = 'POST';
        restRequest.requestBody = Blob.valueOf(JSON.serialize(request));
        RestContext.request = restRequest;
        RestContext.response = new RestResponse();
    }

    private static void prepareMalformedRestRequest(String uri) {
        RestRequest restRequest = new RestRequest();
        restRequest.requestURI = uri;
        restRequest.httpMethod = 'POST';
        restRequest.requestBody = Blob.valueOf('{invalid-json');
        RestContext.request = restRequest;
        RestContext.response = new RestResponse();
    }

    private static void invokeArifPayCallback(DonationRequest donationRequest) {
        ArifPayCallbackRequest callback = new ArifPayCallbackRequest();
        callback.donationId = donationRequest.donationId;
        callback.recurringUUID = donationRequest.recurringUUID;
        callback.paymentStatus = 'SUCCESS';
        callback.amount = donationRequest.donationAmount;
        callback.transactionDate = Date.today();
        callback.referenceId = 'ARIFPAY-' + donationRequest.donorType;
        callback.paymentMethod = donationRequest.paymentMethod;
        callback.cardHolder = donationRequest.donorType == ApiConstants.DONOR_CORPORATE
            ? donationRequest.accountName
            : donationRequest.firstName + ' ' + donationRequest.lastName;
        callback.creditCardType = 'Visa';
        callback.cardLast4Digits = '4242';
        callback.cardExpiryMonth = 12;
        callback.cardExpiryYear = 2028;
        callback.currencyEN = 'USD';

        RestRequest restRequest = new RestRequest();
        restRequest.requestURI = '/services/apexrest/arifpay/payments/';
        restRequest.httpMethod = 'POST';
        restRequest.requestBody = Blob.valueOf(JSON.serialize(callback));
        RestContext.request = restRequest;
        RestContext.response = new RestResponse();
        ArifPayCallbackRestService.callback();
    }

    private static void assertSuccessfulCallback(String recurringUUID) {
        Assert.areEqual(200, RestContext.response.statusCode, responseBody());

        npe01__OppPayment__c payment = [
            SELECT npe01__Paid__c, Status__c, npe01__Check_Reference_Number__c
            FROM npe01__OppPayment__c
            WHERE npe01__Opportunity__r.npe03__Recurring_Donation__r.Donation_Id__c = :recurringUUID
            LIMIT 1
        ];
        Assert.isTrue(payment.npe01__Paid__c);
        Assert.areEqual('Paid', payment.Status__c);
        Assert.isNotNull(payment.npe01__Check_Reference_Number__c);
    }

    private static Opportunity donationFromResponse() {
        DonationResponse response = response();
        return [
            SELECT Id, AccountId, npsp__Primary_Contact__c
            FROM Opportunity
            WHERE Id = :response.donationId
        ];
    }

    private static Contact corporatePrimaryContact(
        DonationRequest request,
        Id accountId
    ) {
        return [
            SELECT Id, AccountId, Salutation, FirstName, LastName, Email,
                   Phone, Birthdate, Gender__c, Source__c,
                   HasOptedOutOfEmail,
                   MailingStreet, MailingCity, MailingState,
                   MailingPostalCode, MailingCountry
            FROM Contact
            WHERE AccountId = :accountId AND Email = :request.email
            LIMIT 1
        ];
    }

    private static void assertCorporateContactData(
        DonationRequest request,
        Id accountId,
        Contact primaryContact
    ) {
        Assert.areEqual(accountId, primaryContact.AccountId);
        Assert.areEqual(request.salutation, primaryContact.Salutation);
        Assert.areEqual(request.firstName, primaryContact.FirstName);
        Assert.areEqual(request.lastName, primaryContact.LastName);
        Assert.areEqual(request.email, primaryContact.Email);
        Assert.areEqual(request.phone, primaryContact.Phone);
        Assert.areEqual(request.birthday, primaryContact.Birthdate);
        Assert.areEqual(request.gender, primaryContact.Gender__c);
        Assert.areEqual(request.source, primaryContact.Source__c);
        Assert.areEqual(request.mailingStreet, primaryContact.MailingStreet);
        Assert.areEqual(request.city, primaryContact.MailingCity);
        Assert.areEqual(request.mailingState, primaryContact.MailingState);
        Assert.areEqual(
            request.mailingPostalCode,
            primaryContact.MailingPostalCode
        );
        Assert.areEqual(request.country, primaryContact.MailingCountry);
        Assert.areEqual(request.emailOptOut, primaryContact.HasOptedOutOfEmail);
    }

    private static npe03__Recurring_Donation__c recurringDonationFromResponse() {
        DonationResponse donationResponse = response();
        return [
            SELECT npe03__Contact__c, npe03__Organization__c, Donor_Type__c, Sponsorship_ID__c
            FROM npe03__Recurring_Donation__c
            WHERE Donation_Id__c = :donationResponse.recurringUUID
            LIMIT 1
        ];
    }

    private static DonationResponse response() {
        return (DonationResponse) JSON.deserialize(responseBody(), DonationResponse.class);
    }

    private static String responseBody() {
        return RestContext.response.responseBody == null ? null : RestContext.response.responseBody.toString();
    }
}