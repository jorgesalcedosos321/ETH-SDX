@IsTest
private class RecurringDonationAutomationTest {
    @IsTest
    static void createsOpportunityAndPaymentAutomatically() {
        Account account = new Account(Name = 'Recurring Automation Test');
        insert account;

        Contact contact = new Contact(
            FirstName = 'Recurring',
            LastName = 'Automation',
            AccountId = account.Id
        );
        insert contact;

        Test.startTest();
        npe03__Recurring_Donation__c recurringDonation =
            new npe03__Recurring_Donation__c(
                npe03__Contact__c = contact.Id,
                npe03__Amount__c = 25,
                npe03__Date_Established__c = Date.today(),
                npe03__Installment_Period__c = ApiConstants.PERIOD_MONTHLY,
                npe03__Open_Ended_Status__c = 'Open',
                npsp__PaymentMethod__c = ApiConstants.PAYMENT_CARD,
                Donor_Type__c = ApiConstants.DONOR_INDIVIDUAL,
                Donation_Type__c = 'Recurring Donation',
                Donation_Id__c = 'AUTOMATION-TEST-RECURRING'
            );
        insert recurringDonation;
        Test.stopTest();

        List<Opportunity> opportunities = [
            SELECT Id
            FROM Opportunity
            WHERE npe03__Recurring_Donation__c = :recurringDonation.Id
        ];
        recurringDonation = [
            SELECT npsp__Day_of_Month__c
            FROM npe03__Recurring_Donation__c
            WHERE Id = :recurringDonation.Id
        ];
        List<npe01__OppPayment__c> payments = [
            SELECT Id
            FROM npe01__OppPayment__c
            WHERE npe01__Opportunity__c IN :opportunities
        ];

        Assert.isFalse(
            opportunities.isEmpty(),
            'NPSP should create an Opportunity for a monthly Recurring Donation.'
        );
        Assert.isFalse(
            payments.isEmpty(),
            'NPSP should create a Payment for the generated Opportunity.'
        );
        Assert.areEqual(
            '1',
            recurringDonation.npsp__Day_of_Month__c,
            'Monthly Recurring Donations should default to day 1.'
        );
    }
}
