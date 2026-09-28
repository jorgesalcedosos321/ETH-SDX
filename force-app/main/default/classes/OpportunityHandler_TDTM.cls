global class OpportunityHandler_TDTM extends npsp.TDTM_Runnable{
    global override npsp.TDTM_Runnable.DmlWrapper run(List<SObject> newlist, List<SObject> oldlist, npsp.TDTM_Runnable.Action triggerAction, Schema.DescribeSObjectResult objResult) {
        System.debug('###OpportunityHandler_TDTM 1');
        IOpportunityService opp = new OpportunityService();
        npsp.TDTM_Runnable.DmlWrapper dmlWrapper = new npsp.TDTM_Runnable.DmlWrapper();
        List<Opportunity> opportunitysToUpdate = new List<Opportunity>();
        System.debug('###OpportunityHandler_TDTM 2');
        List<Opportunity> newRecords = (List<Opportunity>) newlist;
        List<Opportunity> oldOpportunityList = (List<Opportunity>) oldlist;
		Map<Id, Opportunity> oldRecords = oldOpportunityList != NULL ? new Map<Id, Opportunity>(oldOpportunityList) : NULL;
        System.debug('###OpportunityHandler_TDTM triggerAction:' + triggerAction);
        

        //if (triggerAction == npsp.TDTM_Runnable.Action.AfterInsert) { } else 
        if (triggerAction == npsp.TDTM_Runnable.Action.BeforeInsert) {
            opp.setOpportunityTypeByRDRT(newRecords);
            opp.setOpportunityTypeWithNoRD(newRecords);     
            opp.setDefaultValuesForRDOpportunity(newRecords);
        } else if (triggerAction == npsp.TDTM_Runnable.Action.AfterInsert) {
            opp.sendOneTimeDonorThankYouEmail(newRecords, oldRecords);//SFESWCSD-86
            opp.checkOpportunitiesWithNoRDToNotify(newRecords,oldRecords);//SFESWCSD-86
            opp.sendSuccessfulPaymentMilestoneEmails(newRecords, oldRecords);//SFESWCSD-91
        }else if (triggerAction == npsp.TDTM_Runnable.Action.AfterUpdate) {
            //SFESWCSD-85 case 3
            opp.sendPaymentConfirmationEmail(newRecords, oldRecords);
            //opp.checkOpportunitiesWithRDToNotify(newRecords,oldRecords);
            opp.checkOpportunitiesWithNoRDToNotify(newRecords,oldRecords);
            // Replaced by RecurringDonationService milestone emails. //SFESWCSD-91
            opp.sendEmailNotificationForThreeDeclinedOpps(newRecords,oldRecords); //SFESWCSD-40  
            opp.closeRecurringDonationWhenOpportunityIsCloseLost(newRecords,oldRecords);
            opp.sendOneTimeDonorThankYouEmail(newRecords, oldRecords);//SFESWCSD-86
            opp.sendSuccessfulPaymentMilestoneEmails(newRecords, oldRecords);//SFESWCSD-91
        }

        if (triggerAction == npsp.TDTM_Runnable.Action.AfterInsert || triggerAction == npsp.TDTM_Runnable.Action.AfterUpdate) {
            //if (opportunitysToUpdate != NULL && !opportunitysToUpdate.isEmpty()) {
                dmlWrapper.objectsToUpdate.addAll(opportunitysToUpdate);
            //}
        }
        return dmlWrapper;
    }
}