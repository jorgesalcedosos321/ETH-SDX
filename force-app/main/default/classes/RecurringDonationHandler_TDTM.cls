global class RecurringDonationHandler_TDTM extends npsp.TDTM_Runnable{
    global override npsp.TDTM_Runnable.DmlWrapper run(List<SObject> newlist, List<SObject> oldlist, npsp.TDTM_Runnable.Action triggerAction, Schema.DescribeSObjectResult objResult) {
        npsp.TDTM_Runnable.DmlWrapper dmlWrapper = new npsp.TDTM_Runnable.DmlWrapper();
        List<npe03__Recurring_Donation__c> rdsToUpdate = new List<npe03__Recurring_Donation__c>();
        List<npe03__Recurring_Donation__c> newRecords = (List<npe03__Recurring_Donation__c>) newlist;
        List<npe03__Recurring_Donation__c> oldRDList = (List<npe03__Recurring_Donation__c>) oldlist;
		Map<Id, npe03__Recurring_Donation__c> oldRecords = oldRDList != NULL ? new Map<Id, npe03__Recurring_Donation__c>(oldRDList) : NULL;            
        
        IRecurringDonationService rds = new RecurringDonationService();
        System.debug('###RecurringDonationHandler_TDTM triggerAction:' + triggerAction);

        if (triggerAction == npsp.TDTM_Runnable.Action.BeforeInsert) {
            rds.defaultMonthlyDayOfMonth(newRecords);
            rds.closeOldRDs(newRecords);    

        }
        else if (triggerAction == npsp.TDTM_Runnable.Action.AfterInsert) {
            rds.sendSponsorshipWelcomeEmail(newRecords);
            //SFESWCSD-85 case 2
            rds.createSponsorshipRegistrationTasks(newRecords);
            //SFESWCSD-91
            //rds.sendFirstCommittedDonationWelcomeEmail(newRecords, oldRecords);
        }
        else if (triggerAction == npsp.TDTM_Runnable.Action.AfterUpdate) {
            //SFESWCSD-91
            //rds.sendFirstCommittedDonationWelcomeEmail(newRecords, oldRecords);
            //rds.sendSuccessfulPaymentMilestoneEmails(newRecords, oldRecords);
            //rds.createSixPaymentLoyaltyCallTasks(newRecords, oldRecords);
            //SFESWCSD-85 case 11
            rds.sendSponsorshipCancellationEmail(newRecords, oldRecords);
            rds.closeOpportunitiesFromClosedRDs(newRecords, oldRecords);
        }
        

        if (triggerAction == npsp.TDTM_Runnable.Action.AfterInsert ||
                triggerAction == npsp.TDTM_Runnable.Action.AfterUpdate) {
            dmlWrapper.objectsToUpdate.addAll(rdsToUpdate);
        }
        return dmlWrapper;
    // private void defaultMonthlyDayOfMonth(
    //     List<npe03__Recurring_Donation__c> newRecords
    // ) {
    //     for (npe03__Recurring_Donation__c recurringDonation : newRecords) {
    //         if (
    //             recurringDonation.npe03__Installment_Period__c ==
    //                 ApiConstants.PERIOD_MONTHLY &&
    //             String.isBlank(recurringDonation.npsp__Day_of_Month__c)
    //         ) {
    //             recurringDonation.npsp__Day_of_Month__c = '1';
    //         }
    //     }
    // }

    /*public void beforeInsert(List<npe03__Recurring_Donation__c> newRecords) {
		defaultMonthlyDayOfMonth(newRecords);
   		rds.closeOldRDs(newRecords);
    }

    //SFESWCSD-85 case 1
    public void afterInsert(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords) {
        rds.sendSponsorshipWelcomeEmail(newRecords);
        //SFESWCSD-85 case 2
        rds.createSponsorshipRegistrationTasks(newRecords);
        //SFESWCSD-91
        rds.sendFirstCommittedDonationWelcomeEmail(newRecords, oldRecords);
    }
    
    public void afterUpdate(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords) {
        //SFESWCSD-91
        rds.sendFirstCommittedDonationWelcomeEmail(newRecords, oldRecords);
        rds.sendSuccessfulPaymentMilestoneEmails(newRecords, oldRecords);
        rds.createSixPaymentLoyaltyCallTasks(newRecords, oldRecords);
        //SFESWCSD-85 case 11
        rds.sendSponsorshipCancellationEmail(newRecords, oldRecords);
        rds.closeOpportunitiesFromClosedRDs(newRecords, oldRecords);
    }*/
    }
}