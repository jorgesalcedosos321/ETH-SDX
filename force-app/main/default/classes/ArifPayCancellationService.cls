//SFESWCSD-92
//3rd WS called by SF
public class ArifPayCancellationService {

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