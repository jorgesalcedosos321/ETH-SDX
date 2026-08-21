/**
* @File Name : LeadHandler.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : October 26, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 26, 2024 |   | Initial Version
**/

public with sharing class LeadHandler {
	final List<Lead> newRecords;
    final Map<Id, Lead> oldMap;

    public LeadHandler(List<Lead> newRecords, Map<Id, Lead> oldMap){
        this.newRecords = newRecords;
        this.oldMap = oldMap;
    }

    public void beforeInsert(){
        LeadService.setDefaultCompanyNameIfEmpty(newRecords);
        //LeadService.CheckNextFinishDonationDate(newRecords, oldMap, true);
    }

	//public void afterInsert(){
        //LeadService.SendCommitedNotification(newRecords);
    //}
}