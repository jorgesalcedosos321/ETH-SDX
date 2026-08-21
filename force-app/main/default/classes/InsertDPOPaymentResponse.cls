@RestResource(urlMapping='/InsertDPOPaymentResponse/*')
global class InsertDPOPaymentResponse {
    @HttpPost 
    global static void CreateWSTransaction() {
        if (RestContext.request.requestBody != null) {
            String body = RestContext.request.requestBody.ToString().trim();
            INSERT Utils.logJsons(body, 'Log DPO Transaction', false);
            system.debug('#### body: ' + body);
        } else {
            INSERT Utils.logJsons(RestContext.request.toString(), 'Log DPO Transaction', true);
        }
    }
}