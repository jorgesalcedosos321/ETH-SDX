global class PaymentTriggerHandler_TDTM extends npsp.TDTM_Runnable {
    global override npsp.TDTM_Runnable.DmlWrapper run(List<SObject> newlist, List<SObject> oldlist, npsp.TDTM_Runnable.Action triggerAction, Schema.DescribeSObjectResult objResult) {
        IPaymentTriggerService pay = new PaymentTriggerService();
        npsp.TDTM_Runnable.DmlWrapper dmlWrapper = new npsp.TDTM_Runnable.DmlWrapper();
        
        List<npe01__OppPayment__c> paymentsToUpdate = new List<npe01__OppPayment__c>();
        List<npe01__OppPayment__c> newRecords = (List<npe01__OppPayment__c>) newlist;
        List<npe01__OppPayment__c> oldPayList = (List<npe01__OppPayment__c>) oldlist;
		Map<Id, npe01__OppPayment__c> oldRecords = oldPayList != NULL ? new Map<Id, npe01__OppPayment__c>(oldPayList) : NULL;
        System.debug('###PaymentTriggerHandler_TDTM triggerAction:' + triggerAction);

        if (triggerAction == npsp.TDTM_Runnable.Action.BeforeInsert) {
            pay.setPaymentMethodFromRD(newRecords);
            pay.checkPaidOption(newRecords, null);      
        } else if (triggerAction == npsp.TDTM_Runnable.Action.BeforeUpdate) {
            pay.checkPaidOption(newRecords, oldRecords);
        } else if (triggerAction == npsp.TDTM_Runnable.Action.AfterUpdate) {
            pay.checkPaymentsWithRDToNotify(newRecords, oldRecords);
        }

        if (triggerAction == npsp.TDTM_Runnable.Action.AfterInsert ||
            triggerAction == npsp.TDTM_Runnable.Action.AfterUpdate) {
                //if (paymentsToUpdate != NULL & !paymentsToUpdate.isEmpty()) {
                    dmlWrapper.objectsToUpdate.addAll(paymentsToUpdate);
                //}
        }
        return dmlWrapper;
    }
}