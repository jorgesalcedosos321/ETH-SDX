public interface IPaymentTriggerService {
    void checkPaidOption(List<npe01__OppPayment__c> newRecords, Map<Id, npe01__OppPayment__c> oldRecords);
    void checkPaymentsWithRDToNotify(List<npe01__OppPayment__c> newRecords, Map<Id, npe01__OppPayment__c> oldRecords);
    void setPaymentMethodFromRD(List<npe01__OppPayment__c> newRecords);
    npe01__OppPayment__c create(DonationRequest request, Id opportunityId);
    npe01__OppPayment__c buildPayment(DonationRequest request, Id opportunityId);
}