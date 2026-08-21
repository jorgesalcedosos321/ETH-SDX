//SFESWCSD-92
//2nd WS
@RestResource(urlMapping='/arifpay/payments/*')
global inherited sharing class ArifPayCallbackRestService {

    @HttpPost
    global static void callback() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {

            ArifPayCallbackRequest request =
                (ArifPayCallbackRequest) JSON.deserialize(
                    req.requestBody.toString(),
                    ArifPayCallbackRequest.class
                );

            ArifPayCallbackResponse response =
                CallbackService.process(request);

            res.statusCode = 200;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody =
                Blob.valueOf(JSON.serialize(response));

        } catch (Exception e) {

            RestContext.response.statusCode = 500;

            ErrorResponse error = new ErrorResponse();
            error.errorCode = ApiConstants.ERR_SYSTEM;
            error.message = e.getMessage();

            RestContext.response.responseBody =
                Blob.valueOf(JSON.serialize(error));

        }

    }

}