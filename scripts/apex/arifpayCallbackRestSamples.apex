//SFESWCSD-92
// Samples that exercise every entry point of ArifPayCallbackRestService in-process,
// the same way an Apex test would: build a RestRequest, set RestContext, call the
// static method, then inspect RestContext.response.
//
// Run:  sf apex run --file scripts/apex/arifpayCallbackRestSamples.apex --target-org eth-sdx
//
// NOTE: this performs real DML (Log__c rows, and for the main callback also the
// Payment / Opportunity state machine in CallbackService.process). Run in a sandbox
// only, and point donationId / recurringUUID at a Recurring Donation whose
// Donation_ID__c exists in that org, otherwise the callback returns HTTP 500.

String successBody = JSON.serialize(new Map<String, Object>{
    'donationId'      => 'DONATION-SPONSORSHIP-002',
    'recurringUUID'   => 'RECURRING-SPONSORSHIP-002',
    'paymentStatus'   => 'SUCCESS',
    'amount'          => 50.00,
    'transactionDate' => '2026-08-27T12:10:00.000Z',
    'referenceId'     => 'ARIFPAY-SUCCESS-ATTEMPT-000',
    'paymentMethod'   => 'Credit Card',
    'cardHolder'      => 'John Doe',
    'creditCardType'  => 'Visa',
    'cardLast4Digits' => '1111',
    'cardExpiryMonth' => 12,
    'cardExpiryYear'  => 2028,
    'currencyEN'      => 'USD'
});

String failureBody = JSON.serialize(new Map<String, Object>{
    'donationId'      => 'DONATION-SPONSORSHIP-001',
    'recurringUUID'   => 'RECURRING-SPONSORSHIP-001',
    'paymentStatus'   => 'FAILURE',
    'amount'          => 50.00,
    'transactionDate' => '2026-08-27T12:00:00.000Z',
    'referenceId'     => 'ARIFPAY-FAILURE-ATTEMPT-001',
    'paymentMethod'   => 'Credit Card',
    'cardHolder'      => 'Jane Doe',
    'creditCardType'  => 'Visa',
    'cardLast4Digits' => '4242',
    'cardExpiryMonth' => 12,
    'cardExpiryYear'  => 2028,
    'currencyEN'      => 'USD'
});

// Payload for the log-only sub-paths (success/cancel/notify/error). Any JSON is accepted;
// it is stored verbatim in Log__c and never deserialized.
String redirectBody = JSON.serialize(new Map<String, Object>{
    'sessionId'   => 'ARIFPAY-SESSION-001',
    'nonce'       => 'abc123',
    'phone'       => '251900000000',
    'totalAmount' => 50.00,
    'transaction' => new Map<String, Object>{
        'transactionId'     => 'TXN-001',
        'transactionStatus' => 'SUCCESS'
    }
});

// ---------------------------------------------------------------------------
// 1) Main callback  ->  POST /services/apexrest/arifpay/payments/
//    Routed to CallbackService.process; returns ArifPayCallbackResponse JSON.
// ---------------------------------------------------------------------------
invoke('/services/apexrest/arifpay/payments/', successBody, 'CALLBACK SUCCESS');

// Same endpoint, FAILURE status: bumps Failed_Payment_Attempts__c and moves the
// Opportunity to Missed / next attempt date (see CallbackService).
invoke('/services/apexrest/arifpay/payments/', failureBody, 'CALLBACK FAILURE');

// ---------------------------------------------------------------------------
// 2) success()  ->  POST /services/apexrest/arifpay/payments/success
// 3) cancel()   ->  POST /services/apexrest/arifpay/payments/cancel
// 4) notify()   ->  POST /services/apexrest/arifpay/payments/notify
// 5) error()    ->  POST /services/apexrest/arifpay/payments/error
//    Each of these only inserts a Log__c row titled SUCCESS/CANCEL/NOTIFY/ERROR
//    and leaves the response body empty (HTTP 200 by default).
// ---------------------------------------------------------------------------
invoke('/services/apexrest/arifpay/payments/success', redirectBody, 'SUCCESS');
invoke('/services/apexrest/arifpay/payments/cancel',  redirectBody, 'CANCEL');
invoke('/services/apexrest/arifpay/payments/notify',  redirectBody, 'NOTIFY');
invoke('/services/apexrest/arifpay/payments/error',   redirectBody, 'ERROR');

// The sub-path methods are global static, so they can also be called directly,
// but they still read RestContext.request.requestBody, so the context must be set first.
RestContext.request = buildRequest('/services/apexrest/arifpay/payments/notify', redirectBody);
RestContext.response = new RestResponse();
ArifPayCallbackRestService.notify();
System.debug('### direct notify() -> status ' + RestContext.response.statusCode);

// Routing is decided by the LAST path segment, case-insensitive, query string ignored.
invoke('/services/apexrest/arifpay/payments/Cancel?sessionId=X', redirectBody, 'CANCEL (mixed case + query)');

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------
RestRequest buildRequest(String uri, String body) {
    RestRequest req = new RestRequest();
    req.requestURI = uri;
    req.httpMethod = 'POST';
    req.addHeader('Content-Type', 'application/json');
    req.requestBody = Blob.valueOf(body);
    return req;
}

void invoke(String uri, String body, String label) {
    RestContext.request = buildRequest(uri, body);
    RestContext.response = new RestResponse();

    ArifPayCallbackRestService.callback();   // dispatches on the URI

    RestResponse res = RestContext.response;
    String responseBody = res.responseBody == null ? '(empty)' : res.responseBody.toString();
    System.debug('### ' + label + ' -> HTTP ' + res.statusCode + ' body: ' + responseBody);
}
