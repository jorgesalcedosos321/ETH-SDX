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

        Boolean isCorporate = isCorporateDonor(request);

        Account account = isCorporate
            ? AccountService.createOrUpdate(request)
            : null;

        Contact contact = ContactService.createOrUpdate(
            request,
            isCorporate ? account.Id : null
        );

        Id accountId = isCorporate ? account.Id : contact.AccountId;

        Opportunity opportunity;
        npe03__Recurring_Donation__c recurringDonation;

        if (ApiConstants.FREQUENCY_MONTHLY == request.frequency) {
            recurringDonation =
                create(
                    request,
                    null,
                    isCorporate ? account.Id : contact.Id
                );
            opportunity = getGeneratedOpportunity(recurringDonation.Id);
        } else {
            opportunity = OpportunityService.createDonation(
                request,
                accountId,
                contact.Id
            );
        }

        if (recurringDonation != null) {
            opportunity.npsp__Primary_Contact__c = contact.Id;
            update opportunity;
        }

        DonationResponse response = new DonationResponse();
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
        Boolean isCorporate = isCorporateDonor(request);

        // Corporate Accounts are handled explicitly. Individual Accounts are
        // created automatically when the Contact is inserted.
        Account account = isCorporate
            ? AccountService.createOrUpdate(request)
            : null;

        Contact contact = ContactService.createOrUpdate(
            request,
            isCorporate ? account.Id : null
        );

        // Sponsorships are always recurring
        npe03__Recurring_Donation__c recurringDonation =
            RecurringDonationService.createSponsorship(
                request,
                isCorporate ? account.Id : contact.Id
            );
        
        Opportunity opportunity = getGeneratedOpportunity(recurringDonation.Id);
        opportunity.npsp__Primary_Contact__c = contact.Id;
        update opportunity;
        
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
        setRecurringDonor(recurringDonation, request, contactId);
        recurringDonation.npe03__Amount__c = request.donationAmount;
        recurringDonation.npe03__Open_Ended_Status__c = 'Open';
        
        if (request.dateEstablished != null) {
            recurringDonation.npe03__Date_Established__c =
                request.dateEstablished;
        }
        
        if (!String.isBlank(request.frequency)) {
            recurringDonation.npe03__Installment_Period__c =
                request.frequency;
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
        recurringDonation.Donation_Type__c = ApiConstants.DONATION_SPONSORSHIP;
        recurringDonation.Sponsorship_Type__c = request.sponsorshipType;        
        recurringDonation.Sponsorship_Location__c =
            String.isNotBlank(request.villageSelection) && request.villageSelection.equalsIgnoreCase('Mekelle')
                ? 'Makalle'
                : request.villageSelection;
        recurringDonation.Sponsorship_Preference__c = request.sponsorshipPreference;        
        recurringDonation.Sponsorship_Age_Preference__c = request.age;
        recurringDonation.Sponsorship_ID__c = generateSponsorshipId(
            request,
            contactId
        );
        
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
        if (request.frequency != ApiConstants.FREQUENCY_MONTHLY) {
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

        setRecurringDonor(rd, request, contactId);
        rd.npe03__Amount__c = request.donationAmount;
        rd.npe03__Open_Ended_Status__c = 'Open';
        rd.npe03__Installment_Period__c = request.frequency;

        if (request.dateEstablished != null) {
            rd.npe03__Date_Established__c = request.dateEstablished;
        }

        // Custom fields
        rd.Donation_Id__c = request.recurringUUID;
        rd.npsp__PaymentMethod__c = request.paymentMethod;
        rd.Payment_Type__c = request.paymentMethod;
        rd.Donation_Type__c = 'Recurring Donation';

        return rd;
    }

    private static Opportunity getGeneratedOpportunity(Id recurringDonationId) {
        List<Opportunity> opportunities = [
            SELECT Id, AccountId, npe03__Recurring_Donation__c
            FROM Opportunity
            WHERE npe03__Recurring_Donation__c = :recurringDonationId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (opportunities.isEmpty()) {
            throw new DonationException(
                'NPSP did not create an Opportunity for the Recurring Donation.'
            );
        }

        return opportunities[0];
    }

    private static String generateSponsorshipId(
        DonationRequest request,
        Id donorId
    ) {
        String villageCode = getVillageCode(request.villageSelection);
        Integer sponsorshipCount;

        if (isCorporateDonor(request)) {
            Account lockedAccount = [
                SELECT Id FROM Account WHERE Id = :donorId FOR UPDATE
            ];
            sponsorshipCount = [
                SELECT COUNT()
                FROM npe03__Recurring_Donation__c
                WHERE npe03__Organization__c = :donorId
                AND Donation_Type__c = :ApiConstants.DONATION_SPONSORSHIP
            ];
        } else {
            Contact lockedContact = [
                SELECT Id FROM Contact WHERE Id = :donorId FOR UPDATE
            ];
            sponsorshipCount = [
                SELECT COUNT()
                FROM npe03__Recurring_Donation__c
                WHERE npe03__Contact__c = :donorId
                AND Donation_Type__c = :ApiConstants.DONATION_SPONSORSHIP
            ];
        }

        String sequence = String.valueOf(sponsorshipCount + 1);
        while (sequence.length() < 4) {
            sequence = '0' + sequence;
        }

        return '020-' + villageCode + '-' + sequence;
    }

    private static String getVillageCode(String sponsorshipLocation) {
        Map<String, String> villageCodes = new Map<String, String>{
            'addis ababa' => '502',
            'bahir dar' => '515',
            'gode' => '531',
            'harar' => '518',
            'hawassa' => '509',
            'jimma' => '561',
            'mekelle' => '524',
            'makalle' => '524'
        };
        String normalizedLocation = String.isBlank(sponsorshipLocation)
            ? null
            : sponsorshipLocation.trim().toLowerCase();

        if (!villageCodes.containsKey(normalizedLocation)) {
            throw new DonationValidationException(
                'A supported Sponsorship Location is required.'
            );
        }

        return villageCodes.get(normalizedLocation);
    }

    private static Boolean isCorporateDonor(DonationRequest request) {
        return String.isNotBlank(request.donorType) &&
            request.donorType.equalsIgnoreCase(ApiConstants.DONOR_CORPORATE);
    }

    private static void setRecurringDonor(
        npe03__Recurring_Donation__c recurringDonation,
        DonationRequest request,
        Id donorId
    ) {
        if (isCorporateDonor(request)) {
            recurringDonation.npe03__Organization__c = donorId;
            recurringDonation.Donor_Type__c = ApiConstants.DONOR_CORPORATE;
        } else {
            recurringDonation.npe03__Contact__c = donorId;
            recurringDonation.Donor_Type__c = ApiConstants.DONOR_INDIVIDUAL;
        }
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

    //SFESWCSD-85 case 1
    public void sendSponsorshipWelcomeEmail(
        List<npe03__Recurring_Donation__c> newRecords
    ) {
        Map<Id, Id> targets = buildSponsorshipWelcomeTargets(newRecords);
        if (targets.isEmpty()) {
            return;
        }

        Set<Id> accepted = DLE_EmailDispatchService.sendEmail(
            Utils.WELCOME_EMAIL_COMMUN,
            targets
        );
        System.debug(
            '###sendSponsorshipWelcomeEmail: ' + accepted.size() +
            ' of ' + targets.size() + ' emails accepted'
        );
    }

    @TestVisible
    private static Map<Id, Id> buildSponsorshipWelcomeTargets(
        List<npe03__Recurring_Donation__c> newRecords
    ) {
        Map<Id, Id> targets = new Map<Id, Id>();
        for (npe03__Recurring_Donation__c recurringDonation : newRecords) {
            if (
                recurringDonation.Donation_Type__c == ApiConstants.DONATION_SPONSORSHIP &&
                recurringDonation.npe03__Contact__c != null
            ) {
                targets.put(
                    recurringDonation.npe03__Contact__c,
                    recurringDonation.Id
                );
            }
        }
        return targets;
    }

    //SFESWCSD-85 case 2
    public void createSponsorshipRegistrationTasks(
        List<npe03__Recurring_Donation__c> newRecords
    ) {
        List<User> assignees = [
            SELECT Id
            FROM User
            WHERE Email = 'beza.teklu@sos-ethiopia.org'
            AND IsActive = true
            LIMIT 1
        ];
        if (assignees.isEmpty()) {
            System.debug(
                '###createSponsorshipRegistrationTasks: active assignee not found'
            );
            return;
        }

        Set<Id> contactIds = new Set<Id>();
        for (npe03__Recurring_Donation__c recurringDonation : newRecords) {
            if (
                recurringDonation.Donation_Type__c == ApiConstants.DONATION_SPONSORSHIP &&
                recurringDonation.npe03__Contact__c != null
            ) {
                contactIds.add(recurringDonation.npe03__Contact__c);
            }
        }
        if (contactIds.isEmpty()) {
            return;
        }

        Map<Id, Contact> contactsById = new Map<Id, Contact>([
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE Id IN :contactIds
        ]);
        BusinessHours defaultBusinessHours = [
            SELECT Id
            FROM BusinessHours
            WHERE IsDefault = true
            LIMIT 1
        ];
        Datetime deadline = BusinessHours.add(
            defaultBusinessHours.Id,
            System.now(),
            24L * 60 * 60 * 1000
        );
        List<Task> tasks = buildSponsorshipRegistrationTasks(
            newRecords,
            assignees[0].Id,
            deadline,
            contactsById
        );
        if (!tasks.isEmpty()) {
            insert tasks;
        }
    }

    @TestVisible
    private static List<Task> buildSponsorshipRegistrationTasks(
        List<npe03__Recurring_Donation__c> newRecords,
        Id ownerId,
        Datetime deadline,
        Map<Id, Contact> contactsById
    ) {
        List<Task> tasks = new List<Task>();
        for (npe03__Recurring_Donation__c recurringDonation : newRecords) {
            Contact contact = contactsById.get(
                recurringDonation.npe03__Contact__c
            );
            if (
                recurringDonation.Donation_Type__c != ApiConstants.DONATION_SPONSORSHIP ||
                contact == null
            ) {
                continue;
            }

            String contactName = (
                (String.isBlank(contact.FirstName) ? '' : contact.FirstName + ' ') +
                contact.LastName
            ).trim();
            tasks.add(new Task(
                OwnerId = ownerId,
                Subject = 'Registration Confirmation',
                Description = 'Contact: ' + contactName,
                Type = 'Call',
                WhoId = contact.Id,
                WhatId = recurringDonation.Id,
                ActivityDate = deadline.date(),
                ReminderDateTime = deadline,
                IsReminderSet = true,
                Status = 'Not Started',
                Priority = 'Normal'
            ));
        }
        return tasks;
    }

    //SFESWCSD-85 case 11
    public void sendSponsorshipCancellationEmail(
        List<npe03__Recurring_Donation__c> newRecords,
        Map<Id, npe03__Recurring_Donation__c> oldRecords
    ) {
        Map<Id, Id> targets = buildSponsorshipCancellationTargets(
            newRecords,
            oldRecords
        );
        if (targets.isEmpty()) {
            return;
        }

        Set<Id> accepted = DLE_EmailDispatchService.sendEmail(
            Utils.CANCELLATION_PROCESS,
            targets
        );
        System.debug(
            '###sendSponsorshipCancellationEmail: ' + accepted.size() +
            ' of ' + targets.size() + ' emails accepted'
        );
    }

    @TestVisible
    private static Map<Id, Id> buildSponsorshipCancellationTargets(
        List<npe03__Recurring_Donation__c> newRecords,
        Map<Id, npe03__Recurring_Donation__c> oldRecords
    ) {
        Map<Id, npe03__Recurring_Donation__c> candidatesById =
            new Map<Id, npe03__Recurring_Donation__c>();
        for (npe03__Recurring_Donation__c recurringDonation : newRecords) {
            npe03__Recurring_Donation__c oldRecurringDonation =
                oldRecords.get(recurringDonation.Id);
            Boolean changedToCancellationStatus =
                oldRecurringDonation != null &&
                oldRecurringDonation.npsp__Status__c != recurringDonation.npsp__Status__c &&
                (
                    recurringDonation.npsp__Status__c == 'Closed' ||
                    recurringDonation.npsp__Status__c == 'Lapsed'
                );
            if (
                changedToCancellationStatus &&
                recurringDonation.Donation_Type__c == ApiConstants.DONATION_SPONSORSHIP &&
                String.isNotBlank(recurringDonation.npsp__ClosedReason__c) &&
                recurringDonation.npe03__Contact__c != null
            ) {
                candidatesById.put(recurringDonation.Id, recurringDonation);
            }
        }
        if (candidatesById.isEmpty()) {
            return new Map<Id, Id>();
        }

        Set<Id> recurringDonationIdsWithFuturePledges = new Set<Id>();
        Set<Id> candidateIds = candidatesById.keySet();
        for (Opportunity opportunity : [
            SELECT npe03__Recurring_Donation__c
            FROM Opportunity
            WHERE npe03__Recurring_Donation__c IN :candidateIds
            AND StageName = 'Pledged'
            AND CloseDate > :Date.today()
        ]) {
            recurringDonationIdsWithFuturePledges.add(
                opportunity.npe03__Recurring_Donation__c
            );
        }

        Map<Id, Id> targets = new Map<Id, Id>();
        for (Id recurringDonationId : recurringDonationIdsWithFuturePledges) {
            npe03__Recurring_Donation__c recurringDonation =
                candidatesById.get(recurringDonationId);
            targets.put(
                recurringDonation.npe03__Contact__c,
                recurringDonation.Id
            );
        }
        return targets;
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
