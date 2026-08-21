//1st WS
//SFESWCSD-92
@RestResource(urlMapping='/donation/sponsorship/*')
global inherited sharing class SponsorshipDonationRestService {

    @HttpPost
    global static void process() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            DonationRequest request =
                (DonationRequest) JSON.deserialize(
                    req.requestBody.toString(),
                    DonationRequest.class
                );

            DonationResponse response;

            /*
             * Determine which process should be executed.
             */

            if (isSponsorship(request)) {
                response = RecurringDonationService.registerSponsorship(request);
            } 

            if (response == NULL) {
                 sendError(
                     400,
                     ApiConstants.ERR_VALIDATION,
                     'Error: Is not a sponsorship donation'
                 );
                return;
            }

            res.statusCode = 200;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(
                JSON.serialize(response)
            );
        }
        catch (DonationValidationException ex) {
            sendError(
                400,
                ApiConstants.ERR_VALIDATION,
                ex.getMessage()
            );
        }
        catch (DonationException ex) {
            sendError(
                500,
                ApiConstants.ERR_SYSTEM,
                ex.getMessage()
            );
        }
        catch (Exception ex) {

            sendError(
                500,
                ApiConstants.ERR_SYSTEM,
                ex.getMessage()
            );
        }
    }

    /**
     * Determines whether the request is a sponsorship.
     */
    private static Boolean isSponsorship(
        DonationRequest request
    ) {

        return
            !String.isBlank(request.sponsorshipType)
            || !String.isBlank(request.sponsorshipId);
    }

    /**
     * Sends an error response.
     */
    private static void sendError( 
        Integer statusCode,
        String errorCode,
        String message
    ) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader(
            'Content-Type',
            'application/json'
        );

        ErrorResponse error = new ErrorResponse();
        error.errorCode = errorCode;
        error.message = message;

        RestContext.response.responseBody =
            Blob.valueOf(JSON.serialize(error));
    }
}