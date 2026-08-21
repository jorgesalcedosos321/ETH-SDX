trigger PaymentTrigger on npe01__OppPayment__c (before Insert, before Update, after Update) {
    PaymentTriggerHandler pay = new PaymentTriggerHandler();
    if (Trigger.isBefore && Trigger.isInsert) {
        pay.beforeInsertPayment(Trigger.New);
    }
    if (Trigger.isBefore && Trigger.isUpdate) {
        pay.beforeUpdatePayment(Trigger.New, Trigger.oldMap);
    }
    
    if (Trigger.isAfter && Trigger.isUpdate) {
        pay.afterUpdatePayment(Trigger.New, Trigger.oldMap);
    }
}