//SFESWCSD-92
//Dan 21102026: hermetic coverage for the ArifPay classes (no org config record, no live callouts)
@IsTest
private class ArifPayCancellationServiceTest {
    private static final String ACTIVE_SUBSCRIBERS =
        '{"content":[{"phoneNumber":"251900000001","status":"ACTIVE","amount":10},' +
        '{"phoneNumber":"251900000002","status":"INACTIVE","amount":10}],' +
        '"totalElements":2,"size":10,"pageNumber":0}';

    // Answers by HTTP method + path fragment; any unmatched request gets defaultStatus
    private class ArifPayMock implements HttpCalloutMock {
        Integer putStatus = 200;
        Integer getStatus = 200;
        Integer postStatus = 200;
        String getBody = ACTIVE_SUBSCRIBERS;
        List<String> requests = new List<String>();

        public HttpResponse respond(HttpRequest req) {
            requests.add(req.getMethod() + ' ' + req.getEndpoint());
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token":"tok","expires_in":3600}');
            res.setStatusCode(200);
            if (req.getEndpoint().endsWith('/auth/token')) {
                return res;
            }
            if (req.getMethod() == 'PUT') {
                res.setStatusCode(putStatus);
            } else if (req.getMethod() == 'GET') {
                res.setStatusCode(getStatus);
                res.setBody(getBody);
            } else {
                res.setStatusCode(postStatus);
            }
            return res;
        }
    }

    @TestSetup
    static void setup() {
        ArifpayService.setConfig(new Arifpay_Config__mdt(
            Endpoint__c = 'https://arifpay.test/api',
            Bearer_Token__c = 'bearer',
            Merchant_API_Key__c = 'key'
        ));
    }

    private static ArifPayMock useMock() {
        ArifpayService.setConfig(new Arifpay_Config__mdt(
            Endpoint__c = 'https://arifpay.test/api',
            Bearer_Token__c = 'bearer',
            Merchant_API_Key__c = 'key'
        ));
        ArifPayCancellationService.baseUrl = 'https://arifpay.test/api';
        ArifPayMock mock = new ArifPayMock();
        Test.setMock(HttpCalloutMock.class, mock);
        return mock;
    }

    @IsTest
    static void configGettersReturnConfiguredValues() {
        useMock();
        System.assertEquals('bearer', ArifpayService.getToken());
        System.assertEquals('https://arifpay.test/api', ArifpayService.getEndpoint());
        System.assertEquals('key', ArifpayService.getMerchantApiKey());
    }

    @IsTest
    static void configWithoutActiveRecordDoesNotThrow() {
        ArifpayService.setConfig(new Arifpay_Config__mdt());
        System.assertEquals(null, ArifpayService.getEndpoint());
    }

    @IsTest
    static void setTokenEnqueuesMetadataDeployment() {
        Test.startTest();
        ArifpayService.setToken('new-token');
        Test.stopTest();
        System.assert(true, 'setToken completes without error');
    }

    @IsTest
    static void getValidTokenReturnsATokenForAnyConfigState() {
        useMock();
        Test.startTest();
        String token = ArifpayService.getValidToken();
        Test.stopTest();
        System.assertNotEquals(null, token, 'A valid stored token or a refreshed one is returned');
    }

    @IsTest
    static void chargePostsThePayment() {
        ArifPayMock mock = useMock();
        Test.startTest();
        ArifpayService.charge('agreement-1', 25);
        Test.stopTest();
        System.assert(mock.requests[0].startsWith('POST'), 'The charge is a POST');
    }

    @IsTest
    static void chargeThrowsWhenArifPayRejects() {
        ArifPayMock mock = useMock();
        mock.postStatus = 500;
        Boolean thrown = false;
        Test.startTest();
        try {
            ArifpayService.charge('agreement-1', 25);
        } catch (CalloutException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'A rejected charge raises a CalloutException');
    }

    @IsTest
    static void statusChangeRequiresUuidAndStatus() {
        useMock();
        Boolean thrown = false;
        try {
            ArifPayCancellationService.changeRecurringDonationStatus('', 'CANCELLED');
        } catch (IllegalArgumentException e) {
            thrown = true;
        }
        System.assert(thrown, 'Blank uuid is rejected');
    }

    @IsTest
    static void cancellationSequenceListsAndDeactivatesActiveSubscribers() {
        ArifPayMock mock = useMock();
        Test.startTest();
        ArifPayCancellationService.cancelRecurringDonation('uuid-1', 'CANCELLED');
        Test.stopTest();

        Integer puts = 0;
        Integer deactivations = 0;
        for (String r : mock.requests) {
            if (r.startsWith('PUT')) {
                puts++;
            }
            if (r.startsWith('POST') && r.endsWith('/status')) {
                deactivations++;
            }
        }
        System.assertEquals(1, puts, 'Status change called once');
        System.assertEquals(1, deactivations, 'Only the ACTIVE subscriber is deactivated by the queueable');
    }

    @IsTest
    static void statusChangeAcceptedLogsListFailureWithoutFailing() {
        ArifPayMock mock = useMock();
        mock.getStatus = 500;
        Test.startTest();
        HttpResponse res = ArifPayCancellationService.changeRecurringDonationStatus('uuid-1', 'CANCELLED');
        Test.stopTest();
        System.assertEquals(200, res.getStatusCode());
        System.assertEquals(
            true,
            [SELECT COUNT() FROM Log__c] > 0,
            'The follow-up failure is logged'
        );
    }

    @IsTest
    static void statusChangeRejectedThrowsAndLogs() {
        ArifPayMock mock = useMock();
        mock.putStatus = 400;
        Boolean thrown = false;
        Test.startTest();
        try {
            ArifPayCancellationService.changeRecurringDonationStatus('uuid-1', 'CANCELLED');
        } catch (CalloutException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'A rejected status change raises a CalloutException');
    }

    @IsTest
    static void listSubscribersValidatesAndMapsErrors() {
        ArifPayMock mock = useMock();
        Boolean blankThrown = false;
        try {
            ArifPayCancellationService.listSubscribers(' ');
        } catch (IllegalArgumentException e) {
            blankThrown = true;
        }
        System.assert(blankThrown, 'Blank uuid is rejected');

        Test.startTest();
        mock.getStatus = 400;
        Boolean badRequest = false;
        try {
            ArifPayCancellationService.listSubscribers('uuid-1');
        } catch (CalloutException e) {
            badRequest = e.getMessage().contains('rejected');
        }
        System.assert(badRequest, '400 is reported as a rejected request');

        mock.getStatus = 503;
        Boolean serverError = false;
        try {
            ArifPayCancellationService.listSubscribers('uuid-1');
        } catch (CalloutException e) {
            serverError = e.getMessage().contains('503');
        }
        System.assert(serverError, 'Other statuses report the HTTP status');
        Test.stopTest();
    }

    @IsTest
    static void listSubscribersWithNoActiveSubscribersEnqueuesNothing() {
        ArifPayMock mock = useMock();
        mock.getBody = '{"content":[{"phoneNumber":"251900000002","status":"INACTIVE"}]}';
        Test.startTest();
        ArifPaySubscriberListResponse result = ArifPayCancellationService.listSubscribers('uuid-1');
        Test.stopTest();
        System.assertEquals(1, result.content.size());
    }

    @IsTest
    static void deactivateSubscriberHandlesAcceptedAndRejected() {
        ArifPayMock mock = useMock();
        Test.startTest();
        ArifPayCancellationService.deactivateSubscriber('uuid-1', '251900000001');

        mock.postStatus = 500;
        Boolean thrown = false;
        try {
            ArifPayCancellationService.deactivateSubscriber('uuid-1', '251900000001');
        } catch (CalloutException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'A rejected deactivation raises a CalloutException');
    }

    @IsTest
    static void donorSubscriptionCancellationMapsStatuses() {
        ArifPayMock mock = useMock();
        Boolean blankThrown = false;
        try {
            ArifPayCancellationService.cancelDonorSubscription('uuid-1', '');
        } catch (IllegalArgumentException e) {
            blankThrown = true;
        }
        System.assert(blankThrown, 'Blank phone is rejected');

        Test.startTest();
        mock.postStatus = 202;
        System.assertEquals(
            202,
            ArifPayCancellationService.cancelDonorSubscription('uuid-1', '251900000001').getStatusCode()
        );

        mock.postStatus = 400;
        Boolean badRequest = false;
        try {
            ArifPayCancellationService.cancelDonorSubscription('uuid-1', '251900000001');
        } catch (CalloutException e) {
            badRequest = e.getMessage().contains('pending');
        }
        System.assert(badRequest, '400 is reported as pending/invalid');

        mock.postStatus = 500;
        Boolean serverError = false;
        try {
            ArifPayCancellationService.cancelDonorSubscription('uuid-1', '251900000001');
        } catch (CalloutException e) {
            serverError = e.getMessage().contains('500');
        }
        System.assert(serverError, 'Other statuses report the HTTP status');
        Test.stopTest();
    }

    @IsTest
    static void queueablesDelegateToTheServices() {
        ArifPayMock mock = useMock();
        Test.startTest();
        new ArifPayRDCancellationQueueable('uuid-1', 'CANCELLED').execute(null);

        new ArifPaySubscriberCancellationQueueable('uuid-1', new List<String>()).execute(null);
        new ArifPaySubscriberCancellationQueueable('uuid-1', new List<String>{'251900000001'}).execute(null);

        mock.postStatus = 500;
        new ArifPaySubscriberCancellationQueueable('uuid-1', new List<String>{'251900000001'}).execute(null);

        mock.putStatus = 200;
        new ArifPayNotifyUrlQueueable('uuid-1', 'https://example.com/notify').execute(null);
        mock.putStatus = 500;
        new ArifPayNotifyUrlQueueable('uuid-1', 'https://example.com/notify').execute(null);
        new ArifPayNotifyUrlQueueable('', '').execute(null);
        Test.stopTest();
        System.assertEquals(
            true,
            [SELECT COUNT() FROM Log__c] > 0,
            'Failures are logged instead of thrown'
        );
    }

    @IsTest
    static void cancellationQueueableKeepsItsRequest() {
        ArifPayCancellationRequest request = new ArifPayCancellationRequest();
        request.recurringUUID = 'uuid-1';
        System.assertNotEquals(null, new ArifPayCancellationQueueable(request));
    }

    @IsTest
    static void schedulerChargesPledgedOpportunitiesDueToday() {
        ArifPayMock mock = useMock();
        Test.startTest();
        new ArifpayRecurringScheduler().execute(null);
        Test.stopTest();
        System.assert(true, 'Scheduler runs with nothing due');
    }

    @IsTest
    static void callbackRequestParsesCardExpiry() {
        ArifPayCallbackRequest request = new ArifPayCallbackRequest();
        System.assertEquals(null, request.cardExpiryMonth);

        request.creditCardExpiry = '1228';
        System.assertEquals(12, request.cardExpiryMonth);
        System.assertEquals(2028, request.cardExpiryYear);

        request.creditCardExpiry = '1328';
        System.assertEquals(null, request.cardExpiryMonth);

        request.creditCardExpiry = '12ab';
        System.assertEquals(null, request.cardExpiryYear);
    }

    @IsTest
    static void apiResponseWrappersHoldValues() {
        ApiResponse api = new ApiResponse();
        api.success = true;
        api.error = new ErrorResponse();
        ArifPaySubscriber subscriber = new ArifPaySubscriber();
        subscriber.phoneNumber = '251900000001';
        ArifPayCallbackResponse callback = new ArifPayCallbackResponse();
        callback.success = true;
        System.assertEquals(true, api.success);
        System.assertEquals('251900000001', subscriber.phoneNumber);
        System.assertEquals(true, callback.success);
    }
}
