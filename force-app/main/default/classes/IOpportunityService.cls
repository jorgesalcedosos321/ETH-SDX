/**
* @File Name : IOpportunityService.cls
* @Description : Interface for service methods
* @Author : Jorge Salcedo
* @Last Modified By : Jorge Salcedo
* @Last Modified On : November 18, 2024
* @Modification Log : 
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 18, 2024 |   | Initial Version
**/

public interface IOpportunityService {
    Opportunity createDonation(DonationRequest request, Id accountId, Id contactId);
    void sendOneTimeDonorThankYouEmail(List<Opportunity> newRecords);//SFESWCSD-86
    //SFESWCSD-85 case 3
    void sendPaymentConfirmationEmail(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords);
    //Opportunity buildOpportunity(DonationRequest request, Id accountId);
    String buildOpportunityName(DonationRequest request);
    Opportunity buildSponsorshipOpportunity(DonationRequest request, Id accountId, Id recurringDonationId);
    Opportunity buildDonationOpportunity(DonationRequest request, Id accountId);    
    Opportunity createSponsorship(DonationRequest request, Id accountId, Id recurringDonationId);
        
    void setDefaultValuesForRDOpportunity(List<Opportunity> newRecords);
	void setOpportunityTypeByRDRT(List<Opportunity> newRecords);
    void setOpportunityTypeWithNoRD(List<Opportunity> newRecords);
    //void checkOpportunitiesWithRDToNotify(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords);
    void checkOpportunitiesWithNoRDToNotify(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords);
    void sendEmailNotificationForInstallments(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords); //SFESWCSD-40
    void sendEmailNotificationForThreeDeclinedOpps(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords); //SFESWCSD-40
    void closeRecurringDonationWhenOpportunityIsCloseLost(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords);
    //void checkProcessToNotify(Map<Id, Integer> toNotify, Map<Id, Id> rdContactIds, Map<Id, Id> oppRdIds, List<Contact> conts);
    //Id getOpportunityByRD(Map<Id, Id> oppRdIds, Id rdId);
    Contact getContactById(List<Contact> conts, Id contactId);
}
