//SFESWCSD-92
//3rd WS called by SF
public class ArifPayCancellationService {
    
    public static HttpResponse cancelDonorSubscription(String sessionUuid, String phoneNumber) {
        if (String.isBlank(sessionUuid) || String.isBlank(phoneNumber)) {
            throw new IllegalArgumentException(
                'Session UUID and phone number are required.'
            );
        }

        String encodedSessionUuid = EncodingUtil.urlEncode(
            sessionUuid.trim(),
            'UTF-8'
        );
        String encodedPhoneNumber = EncodingUtil.urlEncode(
            phoneNumber.trim(),
            'UTF-8'
        );

        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            'callout:ArifPay/api/recuring/' +
            encodedSessionUuid +
            '/subscriber/' +
            encodedPhoneNumber
        );
        
        request.setMethod('POST');
        request.setHeader('x-arifpay-key',ArifpayService.getMerchantApiKey());
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(20000);

        HttpResponse response = new Http().send(request);
        Integer statusCode = response.getStatusCode();

        if (statusCode == 202) {
            return response;
        }

        if (statusCode == 400) {
            throw new CalloutException(
                'ArifPay rejected the cancellation because the subscription ' +
                'is pending or the request is invalid.'
            );
        }

        throw new CalloutException(
            'ArifPay cancellation failed with HTTP status ' + statusCode + '.'
        );
    }
    
    public static void cancelSubscription(
        ArifPayCancellationRequest request
    ) {
        
        HttpRequest req = new HttpRequest();
        
        req.setEndpoint('callout:ArifPay/subscription/cancel');
        req.setMethod('POST');
        req.setHeader(
            'Content-Type',
            'application/json'
        );
        req.setHeader(
            'x-arifpay-key',
            ArifpayService.getMerchantApiKey()
        );

        req.setBody(
            JSON.serialize(request)
            );
        
        Http http = new Http();
        
        HttpResponse response = http.send(req);
        
        if (response.getStatusCode() < 200 ||
        response.getStatusCode() >= 300) {
            
            throw new CalloutException(
                'ArifPay cancellation failed. ' +
                'Status: ' + response.getStatusCode() +
                ', Body: ' + response.getBody()
                );
        }
    }
}
