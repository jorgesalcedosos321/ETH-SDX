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
    void defaultMonthlyDayOfMonth(List<npe03__Recurring_Donation__c> newRecords);
    DonationResponse registerSponsorship(DonationRequest request); //SFESWCSD-92
    DonationResponse registerDonation(DonationRequest request); //SFESWCSD-92
    npe03__Recurring_Donation__c createSponsorship(DonationRequest request, Id contactId); //SFESWCSD-92
	npe03__Recurring_Donation__c create(DonationRequest request, Id opportunityId, Id contact);  //SFESWCSD-92
    void cancelDonation(Set<Id> rdIds); //SFESWCSD-92
    void closeOldRDs(List<npe03__Recurring_Donation__c> newRecords);
    //SFESWCSD-85 case 1
    void sendSponsorshipWelcomeEmail(List<npe03__Recurring_Donation__c> newRecords);
    //SFESWCSD-85 case 2
    void createSponsorshipRegistrationTasks(List<npe03__Recurring_Donation__c> newRecords);
    //SFESWCSD-91
    void sendFirstCommittedDonationWelcomeEmail(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords);
    //SFESWCSD-91
    void sendSuccessfulPaymentMilestoneEmails(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords);
    void createSixPaymentLoyaltyCallTasks(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords);
    //SFESWCSD-85 case 11
    void sendSponsorshipCancellationEmail(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords);
    void closeOpportunitiesFromClosedRDs(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords);
    // Returns, per Recurring Donation Id, whether it has at least consecutiveCount Closed Won opportunities in a row (by installment number).
    //Map<Id, Boolean> hasConsecutiveClosedWonOpportunities(Set<Id> recurringDonationIds, Integer consecutiveCount);
    // Returns, per Recurring Donation Id, the length of its longest run of consecutive Closed Won opportunities (by installment number).
    //Map<Id, Integer> getMaxConsecutiveClosedWonOpportunities(Set<Id> recurringDonationIds);
}