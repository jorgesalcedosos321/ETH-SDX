/**
* @File Name : RecurringDonationHandler.cls
* @Description : Methods to be consumed on the trigger event class
* @Author : Jorge Salcedo
* @Last Modified By : Jorge Salcedo
* @Last Modified On : April 02, 2025
* @Modification Log : April 02, 2025
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | April 02, 2025 |   | Initial Version
**/

public class RecurringDonationHandler {
	IRecurringDonationService rds = new RecurringDonationService();
    public void beforeInsert(List<npe03__Recurring_Donation__c> newRecords) {
   		rds.closeOldRDs(newRecords);
    }

    //SFESWCSD-85 case 1
    public void afterInsert(List<npe03__Recurring_Donation__c> newRecords) {
        rds.sendSponsorshipWelcomeEmail(newRecords);
        //SFESWCSD-85 case 2
        rds.createSponsorshipRegistrationTasks(newRecords);
        //SFESWCSD-91
        rds.sendFirstCommittedDonationWelcomeEmail(newRecords);
    }
    
    public void afterUpdate(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords) {
        //SFESWCSD-91
        rds.sendSuccessfulPaymentMilestoneEmails(newRecords, oldRecords);
        rds.createSixPaymentLoyaltyCallTasks(newRecords, oldRecords);
        //SFESWCSD-85 case 11
        rds.sendSponsorshipCancellationEmail(newRecords, oldRecords);
        rds.closeOpportunitiesFromClosedRDs(newRecords, oldRecords);
    }
}
