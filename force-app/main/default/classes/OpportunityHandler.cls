/**
* @File Name : OpportunityHandler.cls
* @Description : Methods to be consumed on the trigger event class
* @Author : Jorge Salcedo
* @Last Modified By : Jorge Salcedo
* @Last Modified On : November 18, 2024
* @Modification Log : November 18, 2024
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 18, 2024 |   | Initial Version
**/

public class OpportunityHandler {
	IOpportunityService opp = new OpportunityService();
    public void beforeInsert(List<Opportunity> newRecords) {
   		opp.setOpportunityTypeByRDRT(newRecords);
        opp.setOpportunityTypeWithNoRD(newRecords);     
        opp.setDefaultValuesForRDOpportunity(newRecords);
    }
    
    public void afterInsert(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords) {
   		//opp.setOpportunityTypeByRDRT(newRecords);
        //opp.setOpportunityTypeWithNoRD(newRecords);     
        //opp.checkOpportunitiesWithRDToNotify(newRecords,oldRecords);
        opp.checkOpportunitiesWithNoRDToNotify(newRecords,oldRecords);
    }
    
    public void afterUpdate(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords) {    
        //opp.checkOpportunitiesWithRDToNotify(newRecords,oldRecords);
        opp.checkOpportunitiesWithNoRDToNotify(newRecords,oldRecords);
        opp.sendEmailNotificationForInstallments(newRecords,oldRecords); //SFESWCSD-40       
        opp.sendEmailNotificationForThreeDeclinedOpps(newRecords,oldRecords); //SFESWCSD-40  
        opp.closeRecurringDonationWhenOpportunityIsCloseLost(newRecords,oldRecords);
    }
}