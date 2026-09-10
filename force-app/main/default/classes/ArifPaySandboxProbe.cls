/** Sandbox-only diagnostic. Does not use merchant credentials or create Salesforce records. */
public with sharing class ArifPaySandboxProbe {
    private static final String BASE_URL = 'https://gateway.arifpay.org/api/sandbox/c2b';
    // Public developer-portal sandbox credential, not a merchant secret.
    private static final String SANDBOX_KEY = 'arif-sandbox-portal-key';

    public class Result {
        public Integer httpStatus;
        public Boolean error;
        public String message;
        public String sessionId;
        public String transactionStatus;
        public String paymentUrl;
    }

    public static Result createSession(String nonce) {
        if (String.isBlank(nonce)) {
            throw new IllegalArgumentException('A unique nonce is required.');
        }
        return send('/session', new Map<String, Object>{
            'cancelUrl' => 'https://example.com/cancel',
            'phone' => '251911000000',
            'email' => 'sandbox@example.com',
            'nonce' => nonce,
            'errorUrl' => 'https://example.com/error',
            'notifyUrl' => 'https://example.com/notify',
            'successUrl' => 'https://example.com/success',
            'expireDate' => System.now().addHours(1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
            'amount' => 1,
            'items' => new List<Object>{new Map<String, Object>{
                'name' => 'Sandbox item',
                'quantity' => 1,
                'price' => 1,
                'description' => 'Sandbox'
            }},
            'lang' => 'EN'
        }, 'SUCCESS');
    }

    public static Result simulatePayment(String sessionId, String mode) {
        if (String.isBlank(sessionId) || (mode != 'SUCCESS' && mode != 'FAIL')) {
            throw new IllegalArgumentException('Session ID and SUCCESS or FAIL mode are required.');
        }
        return send('/telebirr-ussd/transfer', new Map<String, Object>{
            'sessionId' => sessionId,
            'phoneNumber' => mode == 'SUCCESS' ? '251900000000' : '251911111111'
        }, mode);
    }

    private static Result send(String path, Map<String, Object> body, String mode) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(BASE_URL + path);
        request.setMethod('POST');
        request.setTimeout(20000);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('x-arifpay-key', SANDBOX_KEY);
        request.setHeader('x-arifpay-sim-mode', mode);
        request.setHeader('x-arifpay-fee-source', 'CUSTOMER');
        request.setBody(JSON.serialize(body));
        HttpResponse response = new Http().send(request);
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        Result result = new Result();
        result.httpStatus = response.getStatusCode();
        result.error = (Boolean) payload.get('error');
        result.message = (String) payload.get('msg');
        Map<String, Object> data = (Map<String, Object>) payload.get('data');
        if (data != null) {
            result.sessionId = (String) data.get('sessionId');
            result.paymentUrl = (String) data.get('paymentUrl');
            Map<String, Object> paymentTransaction = (Map<String, Object>) data.get('transaction');
            if (paymentTransaction != null) {
                result.transactionStatus = (String) paymentTransaction.get('transactionStatus');
            }
        }
        return result;
    }
}
