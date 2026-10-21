//SFESWCSD-92
//Dan 21102026: shared callout mock for tests whose flow reaches the ArifPay cancellation callouts
@IsTest
public class ArifPayHttpMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        res.setBody('{"content":[]}');
        return res;
    }
}
