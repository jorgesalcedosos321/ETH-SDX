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
    
    public void afterUpdate(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords) {
        rds.closeOpportunitiesFromClosedRDs(newRecords, oldRecords);
    }
}