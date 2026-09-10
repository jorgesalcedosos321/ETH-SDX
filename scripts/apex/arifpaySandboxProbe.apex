// Real sandbox callouts, not a mocked unit test. Deploy ArifPaySandboxProbe first.
// Allow https://gateway.arifpay.org in Remote Site Settings before running.
// Example callback URLs do not verify Salesforce webhook delivery.
for (String mode : new List<String>{'SUCCESS', 'FAIL'}) {
    String nonce = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    ArifPaySandboxProbe.Result session = ArifPaySandboxProbe.createSession(nonce);
    System.debug(LoggingLevel.ERROR, 'ARIFPAY SESSION: ' + JSON.serializePretty(session));
    System.assertEquals(200, session.httpStatus, session.message);
    System.assertEquals(false, session.error, session.message);
    System.assertNotEquals(null, session.sessionId, 'Missing session ID.');

    ArifPaySandboxProbe.Result payment = ArifPaySandboxProbe.simulatePayment(session.sessionId, mode);
    System.debug(LoggingLevel.ERROR, 'ARIFPAY PAYMENT: ' + JSON.serializePretty(payment));
    System.assertEquals(200, payment.httpStatus, payment.message);
    System.assertEquals(mode == 'FAIL', payment.error, payment.message);
    System.assertEquals(mode == 'SUCCESS' ? 'SUCCESS' : 'FAILED', payment.transactionStatus);

    ArifPaySandboxProbe.Result duplicate = ArifPaySandboxProbe.createSession(nonce);
    System.debug(LoggingLevel.ERROR, 'ARIFPAY DUPLICATE: ' + JSON.serializePretty(duplicate));
    System.assertEquals(400, duplicate.httpStatus, duplicate.message);
    System.assertEquals(true, duplicate.error);
    System.assertEquals('session already exist', duplicate.message);
}
