trigger RecurringDonationTrigger on npe03__Recurring_Donation__c (before insert, after insert, after update) {
	RecurringDonationHandler rd = new RecurringDonationHandler();
    if (Trigger.IsBefore && Trigger.IsInsert) {
        rd.beforeInsert(Trigger.new);
    }  
    //SFESWCSD-113
    if (Trigger.IsAfter && Trigger.IsInsert) {
        rd.afterInsert(Trigger.new);
    }
    if (Trigger.IsAfter && Trigger.IsUpdate) {
        rd.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}