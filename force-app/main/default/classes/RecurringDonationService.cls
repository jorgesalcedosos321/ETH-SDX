/**
* @File Name : OpportunityService.cls
* @Description : Implements methods to be used in the handler
* @Author : Jorge Salcedo
* @Last Modified By : Jorge Salcedo
* @Last Modified On : April 2, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | April 2, 2025 |   | Initial Version
**/

public class RecurringDonationService implements IRecurringDonationService {   
    public static void cancelDonation(Set<Id> rdIds) {
        List<npe03__Recurring_Donation__c> rdsToCancel = [SELECT Donation_Id__c, npe03__Contact__r.FirstName, npe03__Contact__r.LastName, npe03__Contact__r.Email, npe03__Amount__c From npe03__Recurring_Donation__c WHERE Id IN : rdIds];
        
        if (!rdsToCancel.isEmpty()) {
            npe03__Recurring_Donation__c recurringDonation = rdsToCancel[0];
            ArifPayCancellationRequest request = new ArifPayCancellationRequest();
            request.recurringUUID = recurringDonation.Donation_Id__c;
            request.firstName = recurringDonation.npe03__Contact__r.FirstName;
            request.lastName = recurringDonation.npe03__Contact__r.LastName;
            request.donorEmail = recurringDonation.npe03__Contact__r.Email;
            request.amount = recurringDonation.npe03__Amount__c;
            System.enqueueJob(new ArifPayCancellationQueueable(request));
        }
    }
    
    /**
     * Processes a donation request.
     */
    //SFESWCSD-92
    /**
     * Donor and Donation Registration
     */
    public static DonationResponse registerDonation(DonationRequest request) {
        ValidationService.validate(request);

        Contact contact =
            ContactService.createOrUpdate(request);

        Account account =
            AccountService.createOrUpdate(request, contact);

        Opportunity opportunity =
            OpportunityService.createDonation(
                request,
                account.Id,
                contact.Id
            );

        npe03__Recurring_Donation__c recurringDonation;

        if (ApiConstants.PAYMENT_RECURRING == request.paymentType) {
            recurringDonation =
                create(
                    request,
                    opportunity.Id,
                    contact.Id
                );

        }

        npe01__OppPayment__c payment =
            PaymentTriggerService.create(
                request,
                opportunity.Id
            );

        DonationResponse response =
            new DonationResponse();

        response.success = true;
        response.status = ApiConstants.STATUS_SUCCESS;
        response.message = ApiConstants.MSG_CREATED;
        response.donationId = opportunity.Id;

        if (recurringDonation != null) {
            response.recurringUUID = recurringDonation.Donation_Id__c;
        }

        return response;
    }

    /**
	* Processes a Sponsorship Registration request.
	*/
    public static DonationResponse registerSponsorship(
        DonationRequest request
    ) {        
        ValidationService.validate(request);
        
        // Create or update Contact
        Contact contact = ContactService.createOrUpdate(request);
        
        // Create or update Account
        Account account = AccountService.createOrUpdate(
            request,
            contact
        );
        
        // Sponsorships are always recurring
        npe03__Recurring_Donation__c recurringDonation =
            RecurringDonationService.createSponsorship(
                request,
                contact.Id
            );
        
        // Create Sponsorship Opportunity
        Opportunity opportunity =
            OpportunityService.createSponsorship(
                request,
                account.Id,
                recurringDonation.Id
            );
        
        // Create first scheduled payment
        npe01__OppPayment__c payment =
            PaymentTriggerService.create(
                request,
                opportunity.Id
            );
        
        DonationResponse response = new DonationResponse();
        response.success = true;
        response.status = ApiConstants.STATUS_SUCCESS;
        response.message = ApiConstants.MSG_CREATED;
        response.donationId = String.valueOf(opportunity.Id);
        response.recurringUUID = recurringDonation.Donation_Id__c;
        
        return response;
    }
    
    /**
    * Creates a Recurring Donation for a Sponsorship.
    */
    public static npe03__Recurring_Donation__c createSponsorship(
        DonationRequest request,
        Id contactId
    ) {        
        npe03__Recurring_Donation__c recurringDonation =
            new npe03__Recurring_Donation__c();
        
        // Standard NPSP fields
        recurringDonation.npe03__Contact__c = contactId;
        recurringDonation.npe03__Amount__c = request.amount;
        
        if (request.dateEstablished != null) {
            recurringDonation.npe03__Date_Established__c =
                request.dateEstablished;
        }
        
        if (!String.isBlank(request.installmentPeriod)) {
            recurringDonation.npe03__Installment_Period__c =
                request.installmentPeriod;
        }
        
        if (!String.isBlank(request.paymentMethod)) {
        	recurringDonation.npsp__PaymentMethod__c = request.paymentMethod;
        }
        
        Id campaignId = CampaignService.getCampaignId(request);
        
        if (campaignId != null) {
            recurringDonation.npe03__Recurring_Donation_Campaign__c = campaignId;
        }
        
        // Custom integration fields
        recurringDonation.Donation_Id__c = request.recurringUUID;
        //TO CONTACT
        //recurringDonation.Source__c = request.source; 
        
        // Custom sponsorship fields
        recurringDonation.Sponsorship_Type__c = request.sponsorshipType;        
        recurringDonation.Sponsorship_Location__c = request.sponsorshipLocation;        
        recurringDonation.Sponsorship_Preference__c = request.sponsorshipPreference;        
        recurringDonation.Sponsorship_Age_Preference__c = request.sponsorshipAgePreference;
        
        //TODO: sponsorshipId Not sure if will be sent
        //recurringDonation.Sponsorship_ID__c = request.sponsorshipId;
        
        insert recurringDonation;
        return recurringDonation;
    }
    
    /**
     * Creates a Recurring Donation.
     */
    public static npe03__Recurring_Donation__c create(
        DonationRequest request,
        Id opportunityId,
        Id contactId
    ) {
        if (request.paymentType != ApiConstants.PAYMENT_RECURRING) {
            return null;
        }

        npe03__Recurring_Donation__c recurringDonation =
            buildRecurringDonation(
                request,
                opportunityId,
                contactId
            );

        insert recurringDonation;
        return recurringDonation;
    }

    /**
     * Builds the Recurring Donation.
     */
    private static npe03__Recurring_Donation__c buildRecurringDonation(
        DonationRequest request,
        Id opportunityId,
        Id contactId
    ) {
        npe03__Recurring_Donation__c rd =
            new npe03__Recurring_Donation__c();

        rd.npe03__Contact__c = contactId;
        rd.npe03__Amount__c = request.amount;

        if (request.dateEstablished != null) {
            rd.npe03__Date_Established__c = request.dateEstablished;
        }

        // Custom fields
        rd.Donation_Id__c = request.recurringUUID;
        rd.npsp__PaymentMethod__c = request.paymentMethod;
        rd.Payment_Type__c = request.paymentType;

        return rd;
    }
    
    public void closeOldRDs(List<npe03__Recurring_Donation__c> newRecords) {
		Set<Id> rdContacts = new Set<Id>();
		Set<Id> rdAccounts = new Set<Id>();
		for (npe03__Recurring_Donation__c newRecord : newRecords) {
			if (newRecord.npsp__RecurringType__c == 'Open' && newRecord.Donor_Type__c =='Individual' && !rdContacts.contains(newRecord.npe03__Contact__c)) {
				rdContacts.add(newRecord.npe03__Contact__c);
			}
            if (newRecord.npsp__RecurringType__c == 'Open' && newRecord.Donor_Type__c =='Corporate' && !rdAccounts.contains(newRecord.npe03__Organization__c)) {
				rdAccounts.add(newRecord.npe03__Organization__c);
			}
		}

        List<npe03__Recurring_Donation__c> rdsFromContacts = [SELECT Id, npe03__Contact__c, npsp__Status__c, npsp__EndDate__c FROM npe03__Recurring_Donation__c 
                                                              WHERE ((npe03__Contact__c IN: rdContacts AND Donor_Type__c = 'Individual') OR (npe03__Organization__c IN: rdAccounts AND Donor_Type__c = 'Corporate')) AND npsp__RecurringType__c = 'Open' AND npsp__Status__c <> 'Closed'];
    
        if (!rdsFromContacts.isEmpty()) {
            for (npe03__Recurring_Donation__c rdsFromContact : rdsFromContacts) {
                rdsFromContact.npsp__Status__c = 'Closed';
                rdsFromContact.npsp__EndDate__c = Date.today();
            }
            
            UPDATE rdsFromContacts;
        }    
    }
    
    public void closeOpportunitiesFromClosedRDs(List<npe03__Recurring_Donation__c> newRecords, Map<Id, npe03__Recurring_Donation__c> oldRecords) {
		Set<Id> rdIds = new Set<Id>();
        for (npe03__Recurring_Donation__c newRecord : newRecords) {
            if (newRecord.npsp__Status__c != oldRecords.get(newRecord.Id).npsp__Status__c && newRecord.npsp__Status__c == 'Closed') {
                rdIds.add(newRecord.Id);
            }
        }
        
        System.debug('closeOpportunitiesFromClosedRDs rdIds:' + rdIds);    
        List<Opportunity> opps = [SELECT Id, StageName FROM Opportunity WHERE npe03__Recurring_Donation__c IN : rdIds AND StageName = 'Pledged'];
        System.debug('closeOpportunitiesFromClosedRDs opps:' + opps);
        
        if (!opps.isEmpty()) {
            for (Opportunity opp : opps) {
                opp.StageName = 'Closed Lost';
            }
            UPDATE opps;
        }
    }
}