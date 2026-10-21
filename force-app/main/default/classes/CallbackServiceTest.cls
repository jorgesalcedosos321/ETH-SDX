//SFESWCSD-92
//Dan 21102026: callback state machine, REST entry point and TDTM handler coverage
@IsTest
private class CallbackServiceTest {
    private static final String UUID = 'UUID-CALLBACK-1';

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Callback Donor');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Callback',
            LastName = 'Donor',
            AccountId = acc.Id,
            Email = 'callback.donor@example.com',
            npe01__Preferred_Email__c = 'Personal',
            npe01__PreferredPhone__c = 'Home'
        );
        insert con;

        npe03__Recurring_Donation__c rd = new npe03__Recurring_Donation__c(
            Name = 'Callback RD',
            npe03__Open_Ended_Status__c = 'Open',
            npe03__Schedule_Type__c = 'Monthly',
            npe03__Contact__c = con.Id,
            npe03__Next_Payment_Date__c = Date.today(),
            npe03__Amount__c = 100,
            npsp__PaymentMethod__c = 'Check',
            Donor_Type__c = 'Individual',
            Donation_Type__c = 'Recurring Donation',
            Donation_Id__c = UUID
        );
        insert rd;

        // The payment's scheduled date is set from the Opportunity close date when it is created.
        // Its 2nd/3rd attempt dates are formulas (scheduled + 3 / + 6 days).
        //   1: due today (1st attempt)   2: 2030-01-28 (3rd attempt falls on 2030-02-03)
        //   3: 2030-01-30 (2nd attempt falls on 2030-02-02)   4: later installment
        List<Date> closeDates = new List<Date>{
            Date.today(),
            Date.newInstance(2030, 1, 28),
            Date.newInstance(2030, 1, 30),
            Date.newInstance(2030, 6, 15)
        };
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 1; i <= 4; i++) {
            opps.add(new Opportunity(
                Name = 'Callback Opp ' + i,
                npe03__Recurring_Donation__c = rd.Id,
                StageName = 'Pledged',
                AccountId = acc.Id,
                ContactId = con.Id,
                Amount = 100,
                CloseDate = closeDates[i - 1],
                npsp__Recurring_Donation_Installment_Number__c = i
            ));
        }
        insert opps;
    }

    private static ArifPayCallbackRequest request(String status) {
        ArifPayCallbackRequest req = new ArifPayCallbackRequest();
        req.recurringUUID = UUID;
        req.paymentStatus = status;
        req.transactionDate = Date.today();
        req.transactionId = 'ARIFPAY-REF-1';
        req.amount = 100;
        return req;
    }

    // The RD itself creates an Opportunity due today, and SFESWCSD-113 pushes the first test
    // Opportunity to next month, so payments are identified by their scheduled date
    private static npe01__OppPayment__c payment(Date scheduled) {
        return [
            SELECT Id, Status__c, npe01__Paid__c, npe01__Written_Off__c, Failed_Payment_Attempts__c,
                   npe01__Check_Reference_Number__c, npe01__Scheduled_Date__c
            FROM npe01__OppPayment__c
            WHERE npe01__Opportunity__r.npe03__Recurring_Donation__r.Donation_Id__c = :UUID
              AND npe01__Scheduled_Date__c = :scheduled
            LIMIT 1
        ];
    }

    private static void setFailedAttempts(Date scheduled, Decimal failedAttempts) {
        update new npe01__OppPayment__c(
            Id = payment(scheduled).Id,
            Failed_Payment_Attempts__c = failedAttempts
        );
    }

    @IsTest
    static void unknownRecurringDonationIsRejected() {
        ArifPayCallbackRequest req = request('SUCCESS');
        req.recurringUUID = 'does-not-exist';
        Boolean thrown = false;
        try {
            CallbackService.process(req);
        } catch (DonationException e) {
            thrown = true;
        }
        System.assert(thrown, 'Unknown UUID raises a DonationException');
    }

    @IsTest
    static void callbackWithoutDuePaymentOnlyAcknowledges() {
        ArifPayCallbackRequest req = request('SUCCESS');
        req.transactionDate = Date.today().addMonths(-8);
        ArifPayCallbackResponse response = CallbackService.process(req);
        System.assertEquals(true, response.success);
    }

    @IsTest
    static void successfulFirstAttemptMarksThePaymentPaid() {
        setFailedAttempts(Date.today(), 0);
        Test.startTest();
        ArifPayCallbackResponse response = CallbackService.process(request('SUCCESS'));
        Test.stopTest();

        System.assertEquals(true, response.success);
        npe01__OppPayment__c pay = payment(Date.today());
        System.assertEquals('Paid', pay.Status__c);
        System.assertEquals(true, pay.npe01__Paid__c);
        System.assertEquals('ARIFPAY-REF-1', pay.npe01__Check_Reference_Number__c);
    }

    @IsTest
    static void failedCallbackCountsAnAttemptAndPendingKeepsItOpen() {
        setFailedAttempts(Date.today(), 0);
        Test.startTest();
        CallbackService.process(request('FAILURE'));
        System.assertEquals(1, payment(Date.today()).Failed_Payment_Attempts__c);
        System.assertEquals('Failed', payment(Date.today()).Status__c);
        Test.stopTest();
    }

    @IsTest
    static void pendingCallbackKeepsThePaymentOpen() {
        setFailedAttempts(Date.today(), 0);
        CallbackService.process(request('PENDING'));
        System.assertEquals('Pending', payment(Date.today()).Status__c);
        System.assertEquals(false, payment(Date.today()).npe01__Paid__c);
    }

    @IsTest
    static void thirdFailureWritesThePaymentOff() {
        setFailedAttempts(Date.newInstance(2030, 1, 28), 2);

        ArifPayCallbackRequest req = request('FAILURE');
        req.transactionDate = Date.newInstance(2030, 2, 3);
        Test.startTest();
        CallbackService.process(req);
        Test.stopTest();

        System.assertEquals(3, payment(Date.newInstance(2030, 1, 28)).Failed_Payment_Attempts__c);
        System.assertEquals(true, payment(Date.newInstance(2030, 1, 28)).npe01__Written_Off__c);
    }

    @IsTest
    static void successOnTheRetryBackfillsTheNextInstallments() {
        setFailedAttempts(Date.newInstance(2030, 1, 30), 1);

        ArifPayCallbackRequest req = request('SUCCESS');
        req.transactionDate = Date.newInstance(2030, 2, 2);
        Test.startTest();
        CallbackService.process(req);
        Test.stopTest();

        // A paid 1st-attempt retry is rebooked, so the payment is found by its reference
        System.assertEquals(
            1,
            [SELECT COUNT() FROM npe01__OppPayment__c WHERE npe01__Check_Reference_Number__c = 'ARIFPAY-REF-1' AND Status__c = 'Paid']
        );
    }

    @IsTest
    static void pastOpportunityHelpersHandleEmptyAndMatchingData() {
        npe03__Recurring_Donation__c rd = [SELECT Id FROM npe03__Recurring_Donation__c WHERE Donation_Id__c = :UUID];
        Test.startTest();
        CallbackService.updatePastOpportunitiesByRDAndInstallment(rd.Id, 1);
        CallbackService.updatePastOpportunitiesByRDAndInstallment(rd.Id, 3);
        CallbackService.updateNextPaymentOnRD(rd.Id, 0);
        CallbackService.updateNextPaymentOnRD(rd.Id, 50);
        CallbackService.updateNextPaymentToPaidByRD(rd.Id, 2, Date.today());
        CallbackService.updateNextPaymentToPaidByRD(rd.Id, 50, Date.today());
        Test.stopTest();

        Integer missed = [
            SELECT COUNT() FROM Opportunity
            WHERE npe03__Recurring_Donation__c = :rd.Id AND StageName = 'Missed'
        ];
        System.assertEquals(true, missed >= 2, 'Installments 1 and 2 are missed before installment 3');
    }

    private static RestResponse callRest(String uri, String body) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        ArifPayCallbackRestService.callback();
        return res;
    }

    @IsTest
    static void restCallbackProcessesAPayment() {
        setFailedAttempts(Date.today(), 0);
        RestResponse res = callRest(
            '/services/apexrest/arifpay/payments',
            '{"recurringUUID":"' + UUID + '","paymentStatus":"SUCCESS","transactionId":"R-1"}'
        );
        System.assertEquals(200, res.statusCode);
        System.assertEquals('Paid', payment(Date.today()).Status__c);
    }

    @IsTest
    static void restCallbackReportsErrorsAsHttp500() {
        System.assertEquals(
            500,
            callRest('/services/apexrest/arifpay/payments', '{"recurringUUID":"missing"}').statusCode
        );
        System.assertEquals(
            500,
            callRest('/services/apexrest/arifpay/payments', 'not json').statusCode
        );
    }

    @IsTest
    static void restSubPathsOnlyWriteALog() {
        for (String action : new List<String>{'success', 'cancel', 'notify', 'error'}) {
            callRest('/services/apexrest/arifpay/payments/' + action + '?x=1', '{"a":1}');
        }
        System.assertEquals(
            true,
            [SELECT COUNT() FROM Log__c] >= 4,
            'Each sub-path writes a log'
        );
        System.assertEquals('', ArifPayCallbackRestService.getRequestAction(' '));
        System.assertEquals('payments', ArifPayCallbackRestService.getRequestAction('/ARIFPAY/Payments?a=b'));
    }

    @IsTest
    static void opportunityHandlerDispatchesEveryTriggerAction() {
        List<Opportunity> opps = [SELECT Id, Name, AccountId, ContactId, StageName, Amount, CloseDate, Type, npe03__Recurring_Donation__c, npsp__Recurring_Donation_Installment_Number__c, npsp__Primary_Contact__c FROM Opportunity];
        OpportunityHandler_TDTM handler = new OpportunityHandler_TDTM();
        Test.startTest();
        handler.run(opps, null, npsp.TDTM_Runnable.Action.BeforeInsert, null);
        handler.run(opps, null, npsp.TDTM_Runnable.Action.AfterInsert, null);
        npsp.TDTM_Runnable.DmlWrapper wrapper =
            handler.run(opps, opps, npsp.TDTM_Runnable.Action.AfterUpdate, null);
        Test.stopTest();
        System.assertNotEquals(null, wrapper);
    }

    @IsTest
    static void paymentHandlerDispatchesEveryTriggerAction() {
        List<npe01__OppPayment__c> payments = [
            SELECT Id, npe01__Opportunity__c, npe01__Paid__c, npe01__Payment_Date__c, npe01__Payment_Amount__c, Status__c
            FROM npe01__OppPayment__c
        ];
        PaymentTriggerHandler_TDTM handler = new PaymentTriggerHandler_TDTM();
        Test.startTest();
        handler.run(payments, null, npsp.TDTM_Runnable.Action.BeforeInsert, null);
        handler.run(payments, payments, npsp.TDTM_Runnable.Action.BeforeUpdate, null);
        npsp.TDTM_Runnable.DmlWrapper wrapper =
            handler.run(payments, payments, npsp.TDTM_Runnable.Action.AfterUpdate, null);
        Test.stopTest();
        System.assertNotEquals(null, wrapper);
    }
}
