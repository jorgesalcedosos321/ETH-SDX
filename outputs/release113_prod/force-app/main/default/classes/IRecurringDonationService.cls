/**
* @File Name : IRecurringDonationService.cls
* @Description : Interface for service methods
* @Author : Jorge Salcedo
* @Last Modified By : Jorge Salcedo
* @Last Modified On : April 2, 2025
* @Modification Log : 
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | April 2, 2025 |   | Initial Version
**/

public interface IRecurringDonationService {
	void closeOldRDs(List<npe03__Recurring_Donation__c> newRecords);    
    void closeOpportunitiesFromClosedRDs(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords);    
    //SFESWCSD-113
    void generateHistoricOpportunities(List<npe03__Recurring_Donation__c> newRecords);
}