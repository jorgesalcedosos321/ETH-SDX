//SFESWCSD-92
@IsTest
private class ArifPayPaymentsRestServiceTest {

    @IsTest
    static void testSubsequentPaymentSuccess() {

        String requestBody =
            '{' +
                '"recurringUUID":"ARIFPAY-REC-20260811-000001",' +
                '"amount":20.00,' +
                '"scheduleDate":"2026-08-11",' +
                '"paymentDate":"2026-08-11",' +
                '"paymentStatus":"SUCCESS"' +
            '}';

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/arifpay/payments';
        req.httpMethod = 'POST';
        req.addHeader(
            'Content-Type',
            'application/json'
        );
        req.requestBody = Blob.valueOf(requestBody);

        RestResponse res = new RestResponse();

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();

        ArifPayCallbackRestService.callback();

        Test.stopTest();

        System.assertNotEquals(
            null,
            RestContext.response,
            'REST response should not be null.'
        );

        System.assertNotEquals(
            null,
            RestContext.response.responseBody,
            'Response body should not be null.'
        );

        System.debug(
            'Status Code: ' +
            RestContext.response.statusCode
        );

        System.debug(
            'Response: ' +
            RestContext.response.responseBody.toString()
        );
    }
}