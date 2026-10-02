//SFESWCSD-92
//3rd WS called by SF
public class ArifPayCancellationService {
    public static String baseUrl = ArifpayService.getEndpoint();

    // Entry point for the cancellation sequence: 01 -> 02 -> 03.
    // changeRecurringDonationStatus (01) itself calls listSubscribers (02) on
    // success, which in turn chains deactivateSubscriber (03) asynchronously,
    // one callout at a time, via ArifPaySubscriberCancellationQueueable.
    public static void cancelRecurringDonation(String sessionUuid, String status) {
        changeRecurringDonationStatus(sessionUuid, status);
    }

    //01 in sequence
    public static HttpResponse changeRecurringDonationStatus(String sessionUuid, String status) {
        if (String.isBlank(sessionUuid) || String.isBlank(status)) {
            throw new IllegalArgumentException(
                'Session UUID and status are required.'
            );
        }

        String encodedSessionUuid = EncodingUtil.urlEncode(
            sessionUuid.trim(),
            'UTF-8'
        );
        String encodedStatus = EncodingUtil.urlEncode(
            status.trim(),
            'UTF-8'
        );

        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            baseUrl + '/recuring/update/recurring/' +
            encodedSessionUuid
        );
        
        System.debug('###changeRecurringDonationStatus 1:' + baseUrl + '/recuring/update/recurring/' + encodedSessionUuid);
        Map<String, Object> body = new Map<String, Object>{'status' => status};

        System.debug('###changeRecurringDonationStatus 2:' + ArifpayService.getMerchantApiKey());
        request.setMethod('PUT');
        request.setHeader('x-arifpay-key',ArifpayService.getMerchantApiKey());
        request.setHeader('Content-Type', 'application/json');
        request.setBody(JSON.serialize(body));
        request.setTimeout(20000);
        System.debug('###changeRecurringDonationStatus 2a:' + JSON.serialize(body));

        HttpResponse response = new Http().send(request);
        Integer statusCode = response.getStatusCode();
        String responseBody = response.getBody();
        System.debug('###changeRecurringDonationStatus 3 responseBody:' + responseBody);
        System.debug('###changeRecurringDonationStatus 3 statusCode:' + statusCode);

        if (statusCode == 200 || statusCode == 202) {
            // The status change itself already succeeded - a failure in the
            // listSubscribers/deactivation follow-up must not surface as a
            // failure of changeRecurringDonationStatus, just get logged.
            // DML must come after every callout in the transaction (otherwise
            // "You have uncommitted work pending"), so the logs are collected
            // here and inserted once listSubscribers has finished.
            List<Log__c> logs = new List<Log__c>{
                Utils.logJsons(
                    'Status code:' + statusCode + ' / response:' + responseBody + ' / request:' + request,
                    'Log ArifPay Cancellation',
                    false
                )
            };

            try {
                listSubscribers(sessionUuid);
            } catch (Exception e) {
                logs.add(
                    Utils.logJsons(
                        'listSubscribers failed after a successful status change for uuid:' +
                        encodedSessionUuid + ' / error:' + e.getMessage(),
                        'Log ArifPay Cancellation',
                        true
                    )
                );
            }
            Database.INSERT(logs, false);
            return response;
        } else { //if (statusCode == 400) {
            Database.INSERT(Utils.logJsons(
                    'Status code:' + statusCode + ' / response:' + responseBody + ' / request:' + request,
                    'Log ArifPay Cancellation',
                    true
            ),false);
            throw new CalloutException(
                'ArifPay rejected the cancellation uuid:' + encodedSessionUuid + '/ status:' + status
            );
        }
    }
    
    //02 in sequence
    public static ArifPaySubscriberListResponse listSubscribers(String sessionUuid) {
        if (String.isBlank(sessionUuid)) {
            throw new IllegalArgumentException(
                'Session UUID is required.'
            );
        }

        String encodedSessionUuid = EncodingUtil.urlEncode(
            sessionUuid.trim(),
            'UTF-8'
        );

        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            baseUrl + '/recuring/recurring-sessions/' + encodedSessionUuid + '/subscribers?status=ACTIVE&page=0&size=10'
        );

        request.setMethod('GET');
        request.setHeader('x-arifpay-key',ArifpayService.getMerchantApiKey());
        //request.setHeader('Content-Type', 'application/json');
        request.setTimeout(20000);

        System.debug('###ArifPaySubscriberListResponse 1 request:' + request);

        HttpResponse response = NULL;

        try {
            response = new Http().send(request);
        }catch(Exception ex) {
            System.debug('###ArifPaySubscriberListResponse 1a ex.getMessage():' + ex.getMessage());    
        }
        System.debug('###ArifPaySubscriberListResponse 1a response:' + response);

        Integer statusCode = response.getStatusCode();

        System.debug('###ArifPaySubscriberListResponse 2 response:' + response);

        if (statusCode == 200) {
            ArifPaySubscriberListResponse activeSubscribers = (ArifPaySubscriberListResponse) JSON.deserialize(
                response.getBody(),
                ArifPaySubscriberListResponse.class
            );

            System.debug('###ArifPaySubscriberListResponse 2 activeSubscribers:' + activeSubscribers);

            List<String> phonesToDeactivate = new List<String>();
            for (ArifPaySubscriber asub : activeSubscribers.content) {
                if (String.isNotBlank(asub.status) && asub.status.equalsIgnoreCase('active')) {
                    phonesToDeactivate.add(asub.phoneNumber);
                }
            }

            System.debug('###ArifPaySubscriberListResponse 2 phonesToDeactivate:' + phonesToDeactivate);
            // Cancel each active subscriber one callout at a time via a
            // chained Queueable instead of looping synchronously here -
            // several HttpResponse callouts back to back in one transaction
            // risks callout/time limits (and callouts aren't allowed at all
            // from trigger context).
            if (!phonesToDeactivate.isEmpty()) {
                System.enqueueJob(
                    new ArifPaySubscriberCancellationQueueable(encodedSessionUuid, phonesToDeactivate)
                );
            }

            return activeSubscribers;
        }

        if (statusCode == 400) {
            throw new CalloutException(
                'ArifPay rejected the subscriber list request.'
            );
        }

        throw new CalloutException(
            'ArifPay list subscribers failed with HTTP status ' + statusCode + '.'
        );
    }

    //03 in sequence
    public static void deactivateSubscriber(String encodedSessionUuid, String phoneToDeactivate) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(
            baseUrl + '/recuring/' + encodedSessionUuid + '/subscriber/' + phoneToDeactivate + '/status'
        );

        Map<String, Object> body = new Map<String, Object>{'status' => 'INACTIVE'};
        request.setMethod('POST');
        request.setHeader('x-arifpay-key', ArifpayService.getMerchantApiKey());
        request.setHeader('Content-Type', 'application/json');
        request.setBody(JSON.serialize(body));
        request.setTimeout(20000);

        HttpResponse response = new Http().send(request);
        Integer statusCode = response.getStatusCode();

        if (statusCode == 200 || statusCode == 202) {
            Database.INSERT(Utils.logJsons(
                'ArifPay deactivate subscriber status code: ' + statusCode + ' / response: ' + body + ' / request:' + request,
                'Log ArifPay Deactivate Subscriber',
                true
            ),false);
        } else { //if (statusCode == 400) {        
            Database.INSERT(Utils.logJsons(
                'ArifPay deactivate subscriber status code: ' + statusCode + ' / response: ' + body + ' / request:' + request,
                'Log ArifPay Deactivate Subscriber',
                false
            ),false);
            throw new CalloutException(
                'ArifPay rejected the update subscriber to inactive. Phone:' + phoneToDeactivate + '/ uuid:' + encodedSessionUuid
            );
        }
    }

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
            baseUrl + '/recuring/' +
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