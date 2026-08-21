/**
 * Service responsible for processing ArifPay callbacks.
 */
public inherited sharing class CallbackService {
    /**
     * Processes a payment callback.
     */
    //SFESWCSD-92
    public static ArifPayCallbackResponse process(
        ArifPayCallbackRequest request
    ) {

        List<npe03__Recurring_Donation__c> recurringDonations = [
            SELECT Id
                   //, Recurring_UUID__c
            FROM npe03__Recurring_Donation__c
            //TODO: WHERE Recurring_UUID__c = :request.recurringUUID
        ];

        if (recurringDonations.isEmpty()) {
            throw new DonationException(
                'Recurring Donation not found.'
            );
        }

        List<npe01__OppPayment__c> payments = [
            SELECT Id,
                   npe01__Payment_Amount__c
            FROM npe01__OppPayment__c
            WHERE npe01__Opportunity__r.npe03__Recurring_Donation__c =
                  :recurringDonations[0].Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!payments.isEmpty()) {
            npe01__OppPayment__c payment = payments[0];
            // Future implementation:
            // payment.Payment_Status__c = request.paymentStatus;
            // payment.Reference_Id__c = request.referenceId;
            UPDATE payment;
        }

        ArifPayCallbackResponse response =
            new ArifPayCallbackResponse();

        response.success = true;
        response.message = ApiConstants.MSG_PAYMENT_RECEIVED;

        return response;

    }

}