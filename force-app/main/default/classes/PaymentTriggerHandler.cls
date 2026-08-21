public class PaymentTriggerHandler {
    IPaymentTriggerService pay = new PaymentTriggerService();
    public void beforeInsertPayment(List<npe01__OppPayment__c> newRecords) {
        pay.setPaymentMethodFromRD(newRecords);
   		pay.checkPaidOption(newRecords, null);
    }
	public void beforeUpdatePayment(List<npe01__OppPayment__c> newRecords, Map<Id, npe01__OppPayment__c> oldRecords) {    
        pay.checkPaidOption(newRecords, oldRecords);
    }
    
    public void afterUpdatePayment(List<npe01__OppPayment__c> newRecords, Map<Id, npe01__OppPayment__c> oldRecords) {    
        pay.checkPaymentsWithRDToNotify(newRecords, oldRecords);
    }
}