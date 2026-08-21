trigger OpportunityTrigger on Opportunity (before insert, after insert, after update) {
    OpportunityHandler opp = new OpportunityHandler();
    if (Trigger.IsBefore) {
        if (Trigger.IsInsert) {
            opp.beforeInsert(Trigger.new);
        }
    }  
    if (Trigger.IsAfter) {
        if (Trigger.IsInsert) {
            opp.afterInsert(Trigger.new, Trigger.oldMap);
        }
        if (Trigger.IsUpdate) {
            opp.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }  
}