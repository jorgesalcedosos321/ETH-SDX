@IsTest
private class ArifPaySandboxProbeTest {
    private class SandboxMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        private String mode;
        private Boolean createRequest;

        SandboxMock(Integer statusCode, String responseBody, String mode, Boolean createRequest) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
            this.mode = mode;
            this.createRequest = createRequest;
        }

        public HttpResponse respond(HttpRequest request) {
            System.assertEquals('POST', request.getMethod());
            System.assertEquals('application/json', request.getHeader('Content-Type'));
            System.assertEquals('arif-sandbox-portal-key', request.getHeader('x-arifpay-key'));
            System.assertEquals(mode, request.getHeader('x-arifpay-sim-mode'));
            System.assertEquals('CUSTOMER', request.getHeader('x-arifpay-fee-source'));
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(request.getBody());
            if (createRequest) {
                System.assertEquals('https://gateway.arifpay.org/api/sandbox/c2b/session', request.getEndpoint());
                System.assertEquals('test-nonce', body.get('nonce'));
                System.assertEquals(1, body.get('amount'));
                System.assertEquals('251911000000', body.get('phone'));
                System.assertEquals('https://example.com/notify', body.get('notifyUrl'));
                Datetime expiration = (Datetime) JSON.deserialize(JSON.serialize(body.get('expireDate')), Datetime.class);
                System.assert(expiration > System.now(), 'Session expiry must be in the future.');
            } else {
                System.assertEquals('https://gateway.arifpay.org/api/sandbox/c2b/telebirr-ussd/transfer', request.getEndpoint());
                System.assertEquals('test-session', body.get('sessionId'));
                System.assertEquals(mode == 'SUCCESS' ? '251900000000' : '251911111111', body.get('phoneNumber'));
            }
            HttpResponse response = new HttpResponse();
            response.setStatusCode(statusCode);
            response.setBody(responseBody);
            return response;
        }
    }

    @IsTest
    static void createsSession() {
        Test.setMock(HttpCalloutMock.class, new SandboxMock(200,
            '{"error":false,"msg":"Sandbox session created","data":{"sessionId":"test-session","paymentUrl":"https://checkout.arifpay.org/checkout/test-session","totalAmount":1.0}}', 'SUCCESS', true));
        Test.startTest();
        ArifPaySandboxProbe.Result result = ArifPaySandboxProbe.createSession('test-nonce');
        Test.stopTest();
        System.assertEquals(200, result.httpStatus);
        System.assertEquals(false, result.error);
        System.assertEquals('Sandbox session created', result.message);
        System.assertEquals('test-session', result.sessionId);
        System.assertEquals('https://checkout.arifpay.org/checkout/test-session', result.paymentUrl);
    }

    @IsTest
    static void readsSuccessfulPayment() {
        Test.setMock(HttpCalloutMock.class, new SandboxMock(200,
            '{"error":false,"msg":"Sandbox payment successful","data":{"sessionId":"test-session","transaction":{"transactionStatus":"SUCCESS"}}}', 'SUCCESS', false));
        Test.startTest();
        ArifPaySandboxProbe.Result result = ArifPaySandboxProbe.simulatePayment('test-session', 'SUCCESS');
        Test.stopTest();
        System.assertEquals(200, result.httpStatus);
        System.assertEquals(false, result.error);
        System.assertEquals('SUCCESS', result.transactionStatus);
    }

    @IsTest
    static void http200CanStillMeanFailedPayment() {
        Test.setMock(HttpCalloutMock.class, new SandboxMock(200,
            '{"error":true,"msg":"Simulated failure","data":{"sessionId":"test-session","transaction":{"transactionStatus":"FAILED"}}}', 'FAIL', false));
        Test.startTest();
        ArifPaySandboxProbe.Result result = ArifPaySandboxProbe.simulatePayment('test-session', 'FAIL');
        Test.stopTest();
        System.assertEquals(200, result.httpStatus);
        System.assertEquals(true, result.error);
        System.assertEquals('FAILED', result.transactionStatus);
        System.assertEquals('Simulated failure', result.message);
    }

    @IsTest
    static void readsDuplicateNonceError() {
        Test.setMock(HttpCalloutMock.class, new SandboxMock(400,
            '{"error":true,"msg":"session already exist","data":null}', 'SUCCESS', true));
        Test.startTest();
        ArifPaySandboxProbe.Result result = ArifPaySandboxProbe.createSession('test-nonce');
        Test.stopTest();
        System.assertEquals(400, result.httpStatus);
        System.assertEquals(true, result.error);
        System.assertEquals('session already exist', result.message);
        System.assertEquals(null, result.sessionId);
    }

    @IsTest
    static void rejectsInvalidInputsWithoutCallouts() {
        try {
            ArifPaySandboxProbe.createSession('');
            System.assert(false, 'Expected invalid nonce rejection.');
        } catch (IllegalArgumentException expected) {
            System.assertEquals('A unique nonce is required.', expected.getMessage());
        }
        for (String mode : new List<String>{null, 'LIVE'}) {
            try {
                ArifPaySandboxProbe.simulatePayment('test-session', mode);
                System.assert(false, 'Expected invalid mode rejection.');
            } catch (IllegalArgumentException expected) {
                System.assertEquals(0, Limits.getCallouts());
            }
        }
        try {
            ArifPaySandboxProbe.simulatePayment('', 'SUCCESS');
            System.assert(false, 'Expected missing session rejection.');
        } catch (IllegalArgumentException expected) {
            System.assertEquals(0, Limits.getCallouts());
        }
    }
}
