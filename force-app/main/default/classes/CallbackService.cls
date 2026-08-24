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
            FROM npe03__Recurring_Donation__c
            WHERE Donation_ID__c = :request.recurringUUID
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

            boolean isPaid = String.isNotBlank(request.paymentStatus)
                ? request.paymentStatus.equalsIgnoreCase('success')
                : false;
            boolean isFailure = String.isNotBlank(request.paymentStatus)
                ? request.paymentStatus.equalsIgnoreCase('failure')
                : false;
            boolean isPending = String.isNotBlank(request.paymentStatus)
                ? request.paymentStatus.equalsIgnoreCase('pending')
                : false;

            payment.Status__c = isPaid ? 'Paid' : isFailure ? 'Failed' : 'Pending';

            payment.npe01__Paid__c = false;
            payment.npe01__Written_Off__c = false;

            if (isPaid) {
                payment.npe01__Paid__c = true;
            }
            if (isFailure) {
                payment.npe01__Written_Off__c = true;
            }

            payment.npe01__Payment_Date__c = request.transactionDate.date();
            payment.npsp__Card_Expiration_Month__c = request.cardExpiryMonth + '';
            payment.npsp__Card_Expiration_Year__c = request.cardExpiryYear + '';
            payment.npsp__Card_Network__c = request.creditCardType != null
                ? request.creditCardType
                : request.cardNetwork;
            payment.Credit_Card_Number__c = request.cardLast4Digits != null
                ? request.cardLast4Digits
                : request.cardLast4;
            payment.npe01__Check_Reference_Number__c = request.referenceId;
            payment.Credit_Card_Holder__c = request.cardHolder;
            UPDATE payment;
        }

        ArifPayCallbackResponse response =
            new ArifPayCallbackResponse();

        response.success = true;
        response.message = ApiConstants.MSG_PAYMENT_RECEIVED;

        return response;

    }

}