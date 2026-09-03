//SFESWCSD-92
//2nd WS
@RestResource(urlMapping='/arifpay/payments/*')
global inherited sharing class ArifPayCallbackRestService {

    @HttpPost
    global static void callback() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String action = getRequestAction(req.requestURI);
        if (action == 'cancel') {
            cancel();
            return;
        }
        if (action == 'notify') {
            notify();
            return;
        }
        if (action == 'error') {
            error();
            return;
        }

        try {
            insertCallbackLog(req.requestBody.toString(), 'CALLBACK');
            
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

    global static void cancel() {
        RestRequest req = RestContext.request;
        insertCallbackLog(req.requestBody.toString(), 'CANCEL');
    }

    global static void notify() {
        RestRequest req = RestContext.request;
        insertCallbackLog(req.requestBody.toString(), 'NOTIFY');
    }

    global static void error() {
        RestRequest req = RestContext.request;
        insertCallbackLog(req.requestBody.toString(), 'ERROR');
    }

    private static String getRequestAction(String requestUri) {
        if (String.isBlank(requestUri)) {
            return '';
        }

        String normalizedUri = requestUri.toLowerCase();
        Integer queryStringIndex = normalizedUri.indexOf('?');
        if (queryStringIndex >= 0) {
            normalizedUri = normalizedUri.substring(0, queryStringIndex);
        }

        List<String> pathParts = normalizedUri.split('/');
        return pathParts.isEmpty() ? '' : pathParts[pathParts.size() - 1];
    }


    /**
     * Title: Insert callback log
     * Description: Creates and inserts the callback request log, reporting any DML errors without interrupting processing.
     */
    private static void insertCallbackLog(String requestBody, String title) {
        Log__c ls = Utils.logJsons(requestBody, title, false);
        Database.SaveResult sr = Database.insert(ls, false);
        if (sr.isSuccess()) {
            System.debug('###ArifPayCallbackRestService Log inserted successfully with Id: ' + sr.getId());
        } else {
            System.debug('###ArifPayCallbackRestService ' + title + ' Failed to insert log. Errors:');
            for (Database.Error err : sr.getErrors()) {
                System.debug('###ArifPayCallbackRestService ' + title + ' Error inserting log: ' + err.getMessage());
            }
        }
    }    
}
