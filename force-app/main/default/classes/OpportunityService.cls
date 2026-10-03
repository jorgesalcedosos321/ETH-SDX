/**
* @File Name : OpportunityService.cls
* @Description : Implements methods to be used in the handler
* @Author : Jorge Salcedo
* @Last Modified By : Jorge Salcedo
* @Last Modified On : November 18, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 18, 2024 |   | Initial Version
**/

public class OpportunityService implements IOpportunityService {

    //SFESWCSD-91 queue that owns the loyalty / welcome call Tasks
    @TestVisible private static String DONOR_CALLS_QUEUE = 'Donations_Calls';

    //SFESWCSD-91 former individual assignees of the loyalty / welcome call Tasks
    @TestVisible private static final String TASK_ASSIGNEE_YONAS_EMAIL = 'Yonas.Hailu@sos-ethiopia.org';
    @TestVisible private static final String TASK_ASSIGNEE_BEZA_EMAIL = 'beza.teklu@sos-ethiopia.org';

    //SFESWCSD-113
    public void setFirstOpportunityCloseDate(List<Opportunity> newRecords) {
        Map<Id, Opportunity> firstOppByRdId = new Map<Id, Opportunity>();
        for (Opportunity newRecord : newRecords) {
            Id rdId = newRecord.npe03__Recurring_Donation__c;
            if (rdId == NULL) {
                continue;
            }
            Opportunity current = firstOppByRdId.get(rdId);
            if (current == NULL || (newRecord.CloseDate != NULL && (current.CloseDate == NULL || newRecord.CloseDate < current.CloseDate))) {
                firstOppByRdId.put(rdId, newRecord);
            }
        }

        if (firstOppByRdId.isEmpty()) {
            return;
        }

        //SFESWCSD-113 An RD with previous opportunities already has its first one, keep its earliest CloseDate as reference
        Map<Id, Date> firstDateByRdId = new Map<Id, Date>();
        for (AggregateResult ar : [SELECT npe03__Recurring_Donation__c rdId, MIN(CloseDate) firstDate FROM Opportunity WHERE npe03__Recurring_Donation__c IN : firstOppByRdId.keySet() GROUP BY npe03__Recurring_Donation__c]) {
            firstDateByRdId.put((Id) ar.get('rdId'), (Date) ar.get('firstDate'));
        }

        Set<Id> newFirstOppIds = new Set<Id>();
        for (npe03__Recurring_Donation__c rd : [SELECT Id, npe03__Date_Established__c FROM npe03__Recurring_Donation__c WHERE Id IN : firstOppByRdId.keySet()]) {
            if (!firstDateByRdId.containsKey(rd.Id)) {
                Opportunity firstOpp = firstOppByRdId.get(rd.Id);
                if (rd.npe03__Date_Established__c != NULL) {
                    firstOpp.CloseDate = rd.npe03__Date_Established__c;
                }
                newFirstOppIds.add(rd.Id);
                firstDateByRdId.put(rd.Id, firstOpp.CloseDate);
            }
        }

        //SFESWCSD-113 Any other opportunity falling in the same month as the first one moves to the next month
        for (Opportunity newRecord : newRecords) {
            Id rdId = newRecord.npe03__Recurring_Donation__c;
            Date firstDate = rdId != NULL ? firstDateByRdId.get(rdId) : NULL;
            Boolean isNewFirst = rdId != NULL && newFirstOppIds.contains(rdId) && firstOppByRdId.get(rdId) === newRecord;
            if (firstDate != NULL && !isNewFirst && newRecord.CloseDate != NULL && newRecord.CloseDate.year() == firstDate.year() && newRecord.CloseDate.month() == firstDate.month()) {
                newRecord.CloseDate = newRecord.CloseDate.addMonths(1);
            }
        }
    }

    /**
     * Creates a donation Opportunity.
     */
    //SFESWCSD-92
    /**
     * Creates a standard donation Opportunity.
     */
    public static Opportunity createDonation(
        DonationRequest request,
        Id accountId,
        Id contactId
    ) {
        Opportunity opportunity = buildDonationOpportunity(
            request,
            accountId
        );
        opportunity.npsp__Primary_Contact__c = contactId;
        insert opportunity;
        return opportunity;
    }

    /**
     * Creates a sponsorship Opportunity.
     */
    public static Opportunity createSponsorship(
        DonationRequest request,
        Id accountId,
        Id recurringDonationId
    ) {
        Opportunity opportunity = buildSponsorshipOpportunity(
            request,
            accountId,
            recurringDonationId
        );
        insert opportunity;
        return opportunity;
    }

    /**
     * Donation Opportunity.
     */
    public static Opportunity buildDonationOpportunity(
        DonationRequest request,
        Id accountId
    ) {

        Opportunity opp = new Opportunity();

        opp.AccountId = accountId;
        opp.Name = buildOpportunityName(request);
        opp.StageName = ApiConstants.STAGE_PLEDGED;
        opp.CloseDate = Date.today();
        opp.Amount = request.donationAmount;

        Id campaignId = CampaignService.getCampaignId(request);

        if (campaignId != null) {
            opp.CampaignId = campaignId;
        }

        // TODO
        // RecordType = Donation
        return opp;

    }

    /**
     * Sponsorship Opportunity.
     */
    public static Opportunity buildSponsorshipOpportunity(
        DonationRequest request,
        Id accountId,
        Id recurringDonationId
    ) {
        Opportunity opp = new Opportunity();

        opp.AccountId = accountId;
        opp.Name = buildOpportunityName(request);
        opp.StageName = ApiConstants.STAGE_PLEDGED;
        opp.CloseDate = Date.today();
        opp.Amount = request.donationAmount;

        Id campaignId = CampaignService.getCampaignId(request);

        if (campaignId != null) {
            opp.CampaignId = campaignId;
        }

        // TODO
        // RecordType = Sponsorship

        // Custom fields
        // opp.Sponsorship_ID__c = request.sponsorshipId;
        //opp.Sponsorship_Type__c = request.sponsorshipType;
        opp.npe03__Recurring_Donation__c = recurringDonationId;
		return opp;
    }

    public static String buildOpportunityName(
        DonationRequest request
    ) {
        if (request.donorType != null &&
            request.donorType.equalsIgnoreCase(ApiConstants.DONOR_CORPORATE) &&
            !String.isBlank(request.accountName)) {
            return request.accountName + ' Donation';
        }

        if (!String.isBlank(request.firstName)
            && !String.isBlank(request.lastName)) {

            return request.firstName +
                ' ' +
                request.lastName +
                ' Donation';

        }
        return 'Donation';
    }
    
    public void setDefaultValuesForRDOpportunity(List<Opportunity> newRecords) {
		Set<Id> rdIds = new Set<Id>();

		for (Opportunity newRecord : newRecords) {
			if (String.isNotBlank(newRecord.npe03__Recurring_Donation__c) && newRecord.npsp__Recurring_Donation_Installment_Number__c > 1) {
				rdIds.add(newRecord.npe03__Recurring_Donation__c);
			}
		}

        List<Opportunity> firstOppsRelated = [SELECT Id, npe03__Recurring_Donation__c, CampaignId, Donation_ID__c, Currency__c, Donor_Type__c, Donation_Type__c FROM Opportunity WHERE npe03__Recurring_Donation__c IN : rdIds AND npsp__Recurring_Donation_Installment_Number__c = 1];
		
        for (Opportunity newRecord : newRecords) {
			for (Opportunity opp : firstOppsRelated) {
				if (opp.npe03__Recurring_Donation__c == newRecord.npe03__Recurring_Donation__c) {
                    newRecord.Donor_Type__c = opp.Donor_Type__c;  
                    newRecord.Donation_ID__c = opp.Donation_ID__c ; 
                    newRecord.Donation_Type__c = opp.Donation_Type__c;
                    newRecord.Currency__c = opp.Currency__c;
                    newRecord.Donation_ID__c = opp.Donation_ID__c; 
                    newRecord.CampaignId = opp.CampaignId;
				}
			}
        }        
    }
    
	public void setOpportunityTypeByRDRT(List<Opportunity> newRecords) {
		Set<Id> rdIds = new Set<Id>();

		for (Opportunity newRecord : newRecords) {
			if (!rdIds.contains(newRecord.npe03__Recurring_Donation__c)) {
				rdIds.add(newRecord.npe03__Recurring_Donation__c);
			}
		}

		List<npe03__Recurring_Donation__c> rdData = [SELECT Id, npe03__Organization__c, Donor_Type__c, Donation_Type__c, npe03__Contact__c FROM npe03__Recurring_Donation__c WHERE Id IN : rdIds];

        for (Opportunity newRecord : newRecords) {
			boolean isIndividual = false;
			for (npe03__Recurring_Donation__c rd : rdData) {
				if (rd.Id == newRecord.npe03__Recurring_Donation__c) {
					isIndividual = rd.npe03__Organization__c == null && rd.npe03__Contact__c != null;
                    if (newRecord.npe03__Recurring_Donation__c != null) {
                        newRecord.Donor_Type__c = rd.Donor_Type__c;
                        newRecord.Donation_Type__c = rd.Donation_Type__c;
                    }
				}
			}
            if (newRecord.npe03__Recurring_Donation__c != null) {
            	newRecord.Type = isIndividual ? 'Individual Committed' : 'Corporate Committed';                
            }
        }        
    }
    
    /*public void setGivingStatusForClosedWon(List<Opportunity> newRecords) {
        Set<Id> contactIds = new Set<Id>();
        for (Opportunity newRecord : newRecords) {
            if (!contactIds.contains(newRecord.npsp__Primary_Contact__c)) {
            	contactIds.add(newRecord.npsp__Primary_Contact__c);    
            }            
        }
        
        List<Contact> conts = [SELECT Id, Giving_Status__c FROM Contact WHERE Id IN : contactIds];
		Map<String, Integer> contactsClosedWonOpps = new Map<String, Integer>();
        AggregateResult[] groupedResults = [SELECT Count(Id), npsp__Primary_Contact__c FROM Opportunity WHERE npsp__Primary_Contact__c IN : contactIds AND StageName = 'Closed Won' GROUP BY npsp__Primary_Contact__c];
        
        for (AggregateResult ar : groupedResults)  {
            String contactId = (ar.get('npsp__Primary_Contact__c') + '');
            Integer total = Integer.valueOf(ar.get('expr0'));
            contactsClosedWonOpps.put(contactId, total);
        }
        
        Boolean isUpdated = false;
            
		for (Contact cont : conts) {
            Integer total = 0;
            if (contactsClosedWonOpps.containsKey(cont.Id)) {
                total = contactsClosedWonOpps.get(cont.Id);
            }
            String result = (total > 0) ? 'Donor' : 'Prospect';
            if (cont.Giving_Status__c != result) {
                cont.Giving_Status__c = result;
                isUpdated = true;    
            }
		}
        
        if (isUpdated) {
            UPDATE conts;
        }
    }*/

    //SFESWCSD-86
    //Changed by Marina excel 07092026
    public void sendOneTimeDonorThankYouEmail(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords) {
        Map<Id, Id> targets = buildOneTimeDonorThankYouTargets(newRecords, oldRecords);

        if (!targets.isEmpty()) {
            Set<Id> accepted = DLE_EmailDispatchService.sendEmail(
                Utils.ONE_TIME_DONORS_TH,
                targets
            );
            System.debug('###sendOneTimeDonorThankYouEmail: ' + accepted.size()
                + ' of ' + targets.size() + ' emails accepted');
        }
    }

    @TestVisible
    private static Map<Id, Id> buildOneTimeDonorThankYouTargets(
        List<Opportunity> newRecords,
        Map<Id, Opportunity> oldRecords
    ) {
        Map<Id, Id> targets = new Map<Id, Id>();
        
        for (Opportunity opportunity : newRecords) {
            Boolean stageChangedToClosedWon = (oldRecords == null && opportunity.StageName == 'Closed Won') || (oldRecords != NULL && oldRecords.get(opportunity.Id) != null && oldRecords.get(opportunity.Id).StageName != opportunity.StageName && opportunity.StageName == 'Closed Won');
            if (opportunity.Donation_Type__c == 'One-time Donation' && stageChangedToClosedWon) {
                Id contactId = opportunity.npsp__Primary_Contact__c != null
                    ? opportunity.npsp__Primary_Contact__c
                    : opportunity.ContactId;
                if (contactId != null) {
                    targets.put(contactId, opportunity.Id);
                }   
            }
        }
        return targets;
    }
    
    public void setOpportunityTypeWithNoRD(List<Opportunity> newRecords) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity newRecord : newRecords) {
            if (!accountIds.contains(newRecord.AccountId)) {
            	accountIds.add(newRecord.AccountId);    
            }            
        }
        
        List<Account> accs = [SELECT Id, RecordType.Name FROM Account WHERE Id IN : accountIds];
        
		for (Opportunity newRecord : newRecords) {
            Boolean isIndividual = false;
            for (Account acc : accs) {
                if (acc.Id == newRecord.AccountId && acc.RecordType.Name == 'Household Account') {
            		isIndividual = true;
                }
            }
            
            if (newRecord.npe03__Recurring_Donation__c == null) {
                newRecord.Type = isIndividual ? 'Individual One-off' : 'Corporate One-off';
            } 
		}     
    }

    public void checkOpportunitiesWithNoRDToNotify(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords) {
        Map<Id, Id> oppConIds = new Map<Id, Id>();
		Set<Id> contactIds = new Set<Id>();
		for (Opportunity newRecord : newRecords) {
			if (oldRecords == null && newRecord.Donation_Type__c != 'One-time Donation' && newRecord.npe03__Recurring_Donation__c == NULL && newRecord.StageName == 'Closed Won' && (newRecord.Type == 'Individual Committed' || newRecord.Type == 'Individual One-off')) {
				oppConIds.put(newRecord.Id, newRecord.ContactId);
			}
			if (oldRecords != null && newRecord.Donation_Type__c != 'One-time Donation' && newRecord.npe03__Recurring_Donation__c == NULL && newRecord.StageName == 'Closed Won' && oldRecords.get(newRecord.Id).StageName <> newRecord.StageName && newRecord.StageName == 'Closed Won' && (newRecord.Type == 'Individual Committed' || newRecord.Type == 'Individual One-off')) {
				oppConIds.put(newRecord.Id, newRecord.ContactId);
			}
		}
        
        if (oppConIds.size() == 0)
            return;
        
        for (Id oppRdId : oppConIds.keySet()) {
            if (!contactIds.contains(oppConIds.get(oppRdId))) {
                contactIds.add(oppConIds.get(oppRdId));
            }
        }
        
        if (contactIds.isEmpty())
            return;
        
        List<Contact> conts = [SELECT Id, Account.Phone, Name, npe01__Preferred_Email__c, npe01__HomeEmail__c, npe01__WorkEmail__c, npe01__AlternateEmail__c FROM Contact WHERE Id IN : contactIds]; 
        
        for (Id opportunityId : oppConIds.keySet()) {
            Id contactId = oppConIds.get(opportunityId);
            Contact con = getContactById(conts, contactId);
            String emailToSend = '';
            
            if (con != NULL)
                emailToSend = con.npe01__Preferred_Email__c == 'Personal' ? con.npe01__HomeEmail__c : con.npe01__Preferred_Email__c == 'Work' ? con.npe01__WorkEmail__c : con.npe01__Preferred_Email__c == 'Alternate' ?  con.npe01__AlternateEmail__c : '';
            
            if (con == null || String.isBlank(emailToSend)) 
                continue;
                    
            Map<String, String> params = Utils.replaceEmailTemplateParams(con.Account.Phone, con.Name);
            Utils.sendEmailByTemplate(Utils.emailTemplateThankYouEmail, params, opportunityId, con.Id, new List<String>{emailToSend});
        }
    }

    //SFESWCSD-85 case 3
    public void sendPaymentConfirmationEmail(
        List<Opportunity> newRecords,
        Map<Id, Opportunity> oldRecords
    ) {
        Map<Id, Id> targets = buildPaymentConfirmationTargets(
            newRecords,
            oldRecords
        );
        if (targets.isEmpty()) {
            return;
        }

        Set<Id> accepted = DLE_EmailDispatchService.sendEmail(
            Utils.PAYMENT_CONFIRMATION,
            targets
        );
        System.debug(
            '###sendPaymentConfirmationEmail: ' + accepted.size() +
            ' of ' + targets.size() + ' emails accepted'
        );
    }

    @TestVisible
    private static Map<Id, Id> buildPaymentConfirmationTargets(
        List<Opportunity> newRecords,
        Map<Id, Opportunity> oldRecords
    ) {
        Map<Id, Id> targets = new Map<Id, Id>();
        for (Opportunity opportunity : newRecords) {
            Opportunity oldOpportunity = oldRecords.get(opportunity.Id);
            if (
                oldOpportunity == null ||
                oldOpportunity.StageName == 'Closed Won' ||
                opportunity.StageName != 'Closed Won' ||
                opportunity.Donation_Type__c != 'One-time Donation'
            ) {
                continue;
            }

            Boolean isFirstRecurringInstallment =
                opportunity.npe03__Recurring_Donation__c != null &&
                opportunity.npsp__Recurring_Donation_Installment_Number__c == 1;
            Boolean isNonRecurring =
                opportunity.npe03__Recurring_Donation__c == null;
            if (!isNonRecurring && !isFirstRecurringInstallment) {
                continue;
            }

            Id contactId = opportunity.npsp__Primary_Contact__c != null
                ? opportunity.npsp__Primary_Contact__c
                : opportunity.ContactId;
            if (contactId != null) {
                targets.put(contactId, opportunity.Id);
            }
        }
        return targets;
    }
    
	//SELECT Id, Name FROM EmailTemplate ORDER BY CreatedDate DESC
    public void sendEmailNotificationForInstallments(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords) { //SFESWCSD-40
        Set<Id> oppIds = new Set<Id>();
		for (Opportunity newRecord : newRecords) {
            boolean isChanged = (newRecord.Donor_Type__c != oldRecords.get(newRecord.Id).Donor_Type__c || newRecord.StageName != oldRecords.get(newRecord.Id).StageName || newRecord.Donation_Type__c != oldRecords.get(newRecord.Id).Donation_Type__c);
            boolean isAptToNotify = (newRecord.StageName == 'Closed Won' && newRecord.Donation_Type__c == 'Recurring Donation' && newRecord.Donor_Type__c  == 'Individual');
            System.debug('###sendEmailNotificationForInstallments isChanged:' + isChanged);
            System.debug('###sendEmailNotificationForInstallments isAptToNotify:' + isAptToNotify);
            if (isChanged && isAptToNotify) {
                oppIds.add(newRecord.Id);
            }
		}
        
        System.debug('###sendEmailNotificationForInstallments oppIds:' + oppIds);
        if (oppIds.isEmpty())
            return;
        
        List<Opportunity> oppsToNotify = [SELECT Id, npe03__Recurring_Donation__r.npe03__Total_Paid_Installments__c, npsp__Primary_Contact__c, npsp__Primary_Contact__r.Email, npsp__Primary_Contact__r.FirstName FROM Opportunity WHERE Id IN : oppIds AND npe03__Recurring_Donation__r.npe03__Installment_Period__c  = 'Monthly' AND npsp__Primary_Contact__r.Email <> ''];
        Set<String> emailTemplateNames = new Set<String>{'Welcome the new donor CG','Thank You Email','Welcome Email','Referral Ask Email','Impact Email','Upgrade Email','One Year Thank You Email'};
		List<EmailTemplate> emailTemplates = new List<EmailTemplate>();
        
        if (!Test.isRunningTest()) {
            emailTemplates = [SELECT Id, Name, Subject, HtmlValue, Body FROM EmailTemplate WHERE Name IN : emailTemplateNames];
        } else {
            emailTemplates = new List<EmailTemplate>{
                    new EmailTemplate(Name='Welcome the new donor CG', Subject='Thanks!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
                    new EmailTemplate(Name='Thank You Email', Subject='Thanks!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
                    new EmailTemplate(Name='Welcome Email', Subject='Welcome!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
                    new EmailTemplate(Name='Referral Ask Email', Subject='Refer someone!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
                    new EmailTemplate(Name='Impact Email', Subject='Your impact!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
                    new EmailTemplate(Name='Upgrade Email', Subject='Upgrade now!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom'),
                    new EmailTemplate(Name='One Year Thank You Email', Subject='1 Year Thanks!', Body='Hi {{{Recipient.FirstName}}}', TemplateType='custom')
                    };
        }
        
        Id orgWideEmailAddressId = Utils.getOrgWideEmailAddress();

        System.debug('###sendEmailNotificationForInstallments oppsToNotify:' + oppsToNotify);
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
            
        for (Opportunity oppToNotify : oppsToNotify) {
            EmailTemplate currentEmailTemplate = NULL;
            Id contactId = oppToNotify.npsp__Primary_Contact__c;
            Id opportunityId = oppToNotify.Id;
            Integer totalPaidInstallments = Integer.ValueOf(oppToNotify.npe03__Recurring_Donation__r.npe03__Total_Paid_Installments__c);
        	System.debug('###sendEmailNotificationForInstallments totalPaidInstallments:' + totalPaidInstallments);
            
            switch on totalPaidInstallments {
                when 1 {
                    //currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Thank You Email');
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Welcome the new donor CG');
                }
                when 2 {
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Welcome Email');
                }
                when 4 {
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Referral Ask Email');
                }
                when 6 {
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Impact Email');
                }
                when 10 {
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Upgrade Email');
                }
                when 12 {
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'One Year Thank You Email');
                }
            }
            
            System.debug('###sendEmailNotificationForInstallments currentEmailTemplate:' + currentEmailTemplate);
            if (currentEmailTemplate != NULL) {                
                String body = currentEmailTemplate.HtmlValue == null ? currentEmailTemplate.Body : currentEmailTemplate.HtmlValue;
                String subject = currentEmailTemplate.Subject;
                String email = oppToNotify.npsp__Primary_Contact__r.Email;
                body = body.replace('{{{Recipient.FirstName}}}', oppToNotify.npsp__Primary_Contact__r.FirstName);                
                
                Messaging.SingleEmailMessage mail = Utils.addParamsToEmails(contactId, opportunityId, email, orgWideEmailAddressId, body, subject);
                mails.add(mail);
            }
        }
        
        if (!mails.isEmpty()) {
            Utils.sendEmails(mails);
        }
    }
    
    public void closeRecurringDonationWhenOpportunityIsCloseLost(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords) {
        Set<Id> rdIds = new Set<Id>();
        for (Opportunity newRecord : newRecords) {
            if (newRecord.StageName != oldRecords.get(newRecord.Id).StageName && newRecord.StageName == 'Closed Lost' && newRecord.npe03__Recurring_Donation__c != NULL) {
                rdIds.add(newRecord.npe03__Recurring_Donation__c);
            }
        }
        System.debug('closeRecurringDonationWhenOpportunityIsCloseLost rdIds:' + rdIds);
        if (!rdIds.isEmpty()) {
            List<npe03__Recurring_Donation__c> rdsToUpdate = new List<npe03__Recurring_Donation__c>();
            for (Id rdId : rdIds) {
                rdsToUpdate.add(new npe03__Recurring_Donation__c(Id = rdId, npsp__Status__c = 'Closed'));
            }
            System.debug('closeRecurringDonationWhenOpportunityIsCloseLost rdsToUpdate:' + rdsToUpdate);
            UPDATE rdsToUpdate;            
        }
    }
    
    public Opportunity isThreeConsecutivesDeclinedOpps(Id oppId, Id rdId, List<Opportunity> oppsToNotify) {
        for (Integer i=0; i<oppsToNotify.size(); i++) {            
            Opportunity currentOpp = oppsToNotify[i];
            if (currentOpp.Id == oppId && i >= 2) {
                Opportunity firstOpp = oppsToNotify[i-2];
                Opportunity secondOpp = oppsToNotify[i-1];
                System.debug('isThreeConsecutivesDeclinedOpps currentOpp:' + currentOpp);
                System.debug('isThreeConsecutivesDeclinedOpps firstOpp:' + firstOpp);
                System.debug('isThreeConsecutivesDeclinedOpps secondOpp:' + secondOpp);
                if (firstOpp.stageName == 'Declined' && secondOpp.stageName == 'Declined' && currentOpp.stageName == 'Declined' && 
                    firstOpp.npe03__Recurring_Donation__c == secondOpp.npe03__Recurring_Donation__c && secondOpp.npe03__Recurring_Donation__c == currentOpp.npe03__Recurring_Donation__c) 
                {
                    return currentOpp;
                }
            }
        }
        return NULL;
    }
    
    public void sendEmailNotificationForThreeDeclinedOpps(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecords) { //SFESWCSD-40
        Set<Id> rdIds = new Set<Id>();
        Map<Id, Id> oppRdIds = new Map<Id, Id>();
		for (Opportunity newRecord : newRecords) {
            boolean isChanged = (newRecord.StageName != oldRecords.get(newRecord.Id).StageName && newRecord.StageName == 'Declined' && newRecord.npe03__Recurring_Donation__c != NULL);
            if (isChanged) {
                rdIds.add(newRecord.npe03__Recurring_Donation__c);
                oppRdIds.put(newRecord.Id, newRecord.npe03__Recurring_Donation__c);
            }
		}
        
        System.debug('###sendEmailNotificationForThreeDeclinedOpps rdIds:' + rdIds);
        System.debug('###sendEmailNotificationForThreeDeclinedOpps oppRdIds:' + oppRdIds);
        if (rdIds.isEmpty())
            return;
        
        List<Opportunity> oppsToNotify = [SELECT Id, npe03__Recurring_Donation__c, npsp__Primary_Contact__c, npsp__Primary_Contact__r.Email, npsp__Primary_Contact__r.FirstName, StageName FROM Opportunity WHERE npe03__Recurring_Donation__c IN : rdIds AND npsp__Primary_Contact__r.Email <> '' ORDER BY npe03__Recurring_Donation__c, CreatedDate];
        Set<String> emailTemplateNames = new Set<String>{'Reactivation Email'};
		List<EmailTemplate> emailTemplates = [SELECT Id, Name, Subject, HtmlValue, Body FROM EmailTemplate WHERE Name IN : emailTemplateNames];
        Id orgWideEmailAddressId = Utils.getOrgWideEmailAddress();

        System.debug('###sendEmailNotificationForThreeDeclinedOpps oppsToNotify:' + oppsToNotify);
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
            
        for (Id oppId : oppRdIds.keySet()) {
            Opportunity oppToNotify = isThreeConsecutivesDeclinedOpps(oppId, oppRdIds.get(oppId), oppsToNotify);
            System.debug('###sendEmailNotificationForThreeDeclinedOpps oppToNotify:' + oppToNotify);
            if (oppToNotify == NULL) {
                continue;
            }
            
            EmailTemplate currentEmailTemplate = NULL;
            Id contactId = oppToNotify.npsp__Primary_Contact__c;
            Id opportunityId = oppToNotify.Id;
            currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Reactivation Email');
            
            System.debug('###sendEmailNotificationForThreeDeclinedOpps currentEmailTemplate:' + currentEmailTemplate);
            if (currentEmailTemplate != NULL) {                
                String body = currentEmailTemplate.HtmlValue == null ? currentEmailTemplate.Body : currentEmailTemplate.HtmlValue;
                String subject = currentEmailTemplate.Subject;
                String email = oppToNotify.npsp__Primary_Contact__r.Email;
                body = body.replace('{{{Recipient.FirstName}}}', oppToNotify.npsp__Primary_Contact__r.FirstName);                
                
                Messaging.SingleEmailMessage mail = Utils.addParamsToEmails(contactId, opportunityId, email, orgWideEmailAddressId, body, subject);
                mails.add(mail);
            }
        }
        System.debug('###sendEmailNotificationForThreeDeclinedOpps mails:' + mails);
        if (!mails.isEmpty()) {
            Utils.sendEmails(mails);
        }
    }    

     //SFESWCSD-91
    public void sendSuccessfulPaymentMilestoneEmails(
        List<Opportunity> newRecords,
        Map<Id, Opportunity> oldRecords
    ) {
        Map<String, Map<Id, Id>> targetsByTemplate =
            buildSuccessfulPaymentMilestoneTargets(newRecords, oldRecords);

        System.debug('###sendSuccessfulPaymentMilestoneEmails targetsByTemplate:' + targetsByTemplate);
        for (String templateKey : targetsByTemplate.keySet()) {
            Map<Id, Id> targets = targetsByTemplate.get(templateKey);
            Set<Id> accepted = DLE_EmailDispatchService.sendEmail(
                templateKey,
                targets
            );
            System.debug(
                '###sendSuccessfulPaymentMilestoneEmails ' + templateKey +
                ': ' + accepted.size() + ' of ' + targets.size() +
                ' emails accepted'
            );
        }
    }

    @TestVisible
    private static Map<String, Map<Id, Id>> buildSuccessfulPaymentMilestoneTargets(
            List<Opportunity> newRecords,
            Map<Id, Opportunity> oldRecords
        ) {
        Map<Integer, String> templatesByPaymentCount = new Map<Integer, String>{
            1 => Utils.WELCOME_THE_NEW_DONO,
            2 => Utils.THANK_YOU_EMAIL_AFTER_2,
            3 => Utils.THANK_YOU_EMAIL_AFTER_3,
            4 => Utils.THANK_YOU_EMAIL_AFTER_4,
            6 => Utils.THANK_YOU_EMAIL_AFTER_6,
            12 => Utils.THANK_YOU_EMAIL_AFTER_12
        };

        Map<String, Map<Id, Id>> targetsByTemplate = new Map<String, Map<Id, Id>>();
        Map<Id, Id> rdIdsToCheck = new Map<Id, Id>();

        for (Opportunity opp : newRecords) {
            Opportunity oldOpp = (oldRecords != NULL && oldRecords.get(opp.Id) != NULL) ? oldRecords.get(opp.Id) : NULL;
            Boolean changeStagenameOpp = opp.npe03__Recurring_Donation__c != NULL && opp.npsp__Primary_Contact__c != NULL && opp.StageName == ApiConstants.STAGE_CLOSED_WON;

            if (oldOpp != NULL)
                changeStagenameOpp = oldOpp.StageName != opp.StageName;
                
            if (changeStagenameOpp) {
                rdIdsToCheck.put(opp.npe03__Recurring_Donation__c, opp.Id);
            }
        }

        // Contact details are queried here once and reused by buildDonorCallTasks (SFESWCSD-91)
        Map<Id, npe03__Recurring_Donation__c> rdById = new Map<Id, npe03__Recurring_Donation__c>([
            SELECT Id, npe03__Contact__c, npe03__Contact__r.FirstName, npe03__Contact__r.LastName,
                npe03__Contact__r.Phone, npe03__Contact__r.Email
            FROM npe03__Recurring_Donation__c
            WHERE Id IN :rdIdsToCheck.keySet()
        ]);
        Map<Id, Id> contactIdByRdId = new Map<Id, Id>();
        for (npe03__Recurring_Donation__c rdToCheck : rdById.values()) {
            contactIdByRdId.put(rdToCheck.Id, rdToCheck.npe03__Contact__c);
        }

        List<Opportunity> rdPayments = queryPaymentsByRdIds(rdIdsToCheck.keySet());

        Set<Id> sixConsecutivesRD = new Set<Id>();
        Set<Id> firstPaymentRD = new Set<Id>();
        // Milestone emails already sent per RD (templateKey|rdId), so they are not sent twice
        Set<String> alreadySentMilestones = querySentMilestoneEmailKeys(
            rdIdsToCheck.keySet(),
            new Set<String>(templatesByPaymentCount.values())
        );

        for (Id rdId : rdIdsToCheck.keySet()) {
            // Consecutive Closed Won run that contains the Opportunity that triggered this check
            Integer consecutivePayments = getConsecutiveTotalPaidNumberByRdsAndStatus(
                rdId,
                rdIdsToCheck.get(rdId),
                rdPayments,
                ApiConstants.STAGE_CLOSED_WON
            );

            String templateKey = templatesByPaymentCount.get(consecutivePayments);

            //SFESWCSD-91
            if (String.isNotBlank(templateKey) &&
                !alreadySentMilestones.contains(templateKey + '|' + String.valueOf(rdId))) {
                // Loyalty call task only the first time the 6-payment email is due
                if (consecutivePayments == 6) {
                    sixConsecutivesRD.add(rdId);
                }
                // Welcome task only the first time the welcome email is due (first payment)
                if (consecutivePayments == 1) {
                    firstPaymentRD.add(rdId);
                }
                if (!targetsByTemplate.containsKey(templateKey)) {
                    targetsByTemplate.put(templateKey, new Map<Id, Id>());
                }
                targetsByTemplate.get(templateKey).put(
                    contactIdByRdId.get(rdId),
                    rdId
                );
            }
        }

        //SFESWCSD-91
        buildDonorCallTasks(rdById, sixConsecutivesRD, firstPaymentRD);

        return targetsByTemplate;
    }

    // Reads DLE_Email_Log__c (written by DLE_EmailDispatchService) and returns 'eventKey|rdId' for every
    // milestone email already sent successfully. One query, read-only. Failed sends do not count.
    //SFESWCSD-91
    @TestVisible
    private static Set<String> querySentMilestoneEmailKeys(
        Set<Id> rdIds,
        Set<String> eventKeys
    ) {
        Set<String> sentKeys = new Set<String>();
        if (rdIds == null || rdIds.isEmpty() || eventKeys == null || eventKeys.isEmpty()) {
            return sentKeys;
        }

        Set<String> rdIdStrings = new Set<String>();
        for (Id rdId : rdIds) {
            rdIdStrings.add(String.valueOf(rdId));
        }

        for (DLE_Email_Log__c emailLog : [
            SELECT Event_Key__c, What_Id__c
            FROM DLE_Email_Log__c
            WHERE What_Id__c IN :rdIdStrings
            AND Event_Key__c IN :eventKeys
            AND Status__c = 'Sent'
        ]) {
            sentKeys.add(emailLog.Event_Key__c + '|' + emailLog.What_Id__c);
        }
        return sentKeys;
    }

    // One Call Task owned by the Donations_Calls queue per Recurring Donation and subject, carrying the
    // donor contact details. Creates the six-payment loyalty tasks and the first-payment welcome tasks
    // through DLE_TaskService (which also bell-notifies the queue members), so the queue is queried once.
    // DLE_TaskService takes one subject/contact per call, so it is called once per task; it checks the
    // DML row limit itself and never throws. The Recurring Donations (with Contact FirstName, LastName,
    // Phone and Email) come already queried from the caller, so no extra query on them.
    // If the queue does not exist in the org nothing is created and the Opportunity save is not blocked.
    //SFESWCSD-91
    @TestVisible
    private static void buildDonorCallTasks(
        Map<Id, npe03__Recurring_Donation__c> rdById,
        Set<Id> loyaltyRecurringDonations,
        Set<Id> welcomeRecurringDonations
    ) {
        Set<Id> allRecurringDonations = new Set<Id>(loyaltyRecurringDonations);
        allRecurringDonations.addAll(welcomeRecurringDonations);
        if (allRecurringDonations.isEmpty()) {
            return;
        }

        List<Group> queues = [SELECT Id FROM Group WHERE DeveloperName = :DONOR_CALLS_QUEUE AND Type = 'Queue' LIMIT 1];
        if (queues.isEmpty()) {
            System.debug('###buildDonorCallTasks: queue ' + DONOR_CALLS_QUEUE + ' not found');
            return;
        }
        Id queueId = queues[0].Id;

        for (Id rdId : allRecurringDonations) {
            npe03__Recurring_Donation__c recurringDonation = rdById.get(rdId);
            if (recurringDonation == null || recurringDonation.npe03__Contact__c == null) {
                continue;
            }
            
            String description =
                'First Name: ' + (recurringDonation.npe03__Contact__r.FirstName == null ? '' : (recurringDonation.npe03__Contact__r.FirstName)) + '\n' +
                'Last Name: ' + (recurringDonation.npe03__Contact__r.LastName == null ? '' : (recurringDonation.npe03__Contact__r.LastName)) + '\n' +
                'Phone: ' + (recurringDonation.npe03__Contact__r.Phone == null ? '' : (recurringDonation.npe03__Contact__r.Phone)) + '\n' +
                'Email: ' + (recurringDonation.npe03__Contact__r.Email == null ? '' : (recurringDonation.npe03__Contact__r.Email));
                
            List<String> subjects = new List<String>();
            if (loyaltyRecurringDonations.contains(recurringDonation.Id)) {
                subjects.add('Loyalty call after 6 payments');
            }
            if (welcomeRecurringDonations.contains(recurringDonation.Id)) {
                subjects.add('Welcome the new donor CG');
            }

            for (String subject : subjects) {
                DLE_TaskService.Request req = new DLE_TaskService.Request();
                req.ownerIds    = new Set<Id>{ queueId };
                req.subject     = subject;
                req.whoId       = recurringDonation.npe03__Contact__c;
                req.whatId      = recurringDonation.Id;
                req.dueDate     = Date.today(); 
                req.priority    = 'Normal';
                req.taskSubtype = 'Call';
                req.description = description;                        
                DLE_TaskService.TaskResult result = DLE_TaskService.createTasks(req);
                if (result.failedCount > 0) {
                    System.debug('###buildDonorCallTasks: task not created for RD ' + rdId + ': ' + result.errors);
                }
            }
        }
    }

    // Returns every Opportunity (any stage) of the given Recurring Donations, ordered per RD from the
    // newest to the oldest installment, so getConsecutiveTotalPaidNumberByRdsAndStatus can detect breaks
    // in the run. Ordered by CreatedDate (NPSP creates installments in sequence) and not by CloseDate:
    // Closed Won moves CloseDate to today while Missed keeps its scheduled date, which would hide the gaps.
    //SFESWCSD-91
    @TestVisible
    private static List<Opportunity> queryPaymentsByRdIds(Set<Id> rdIds) {
        return [
            SELECT Id, npe03__Recurring_Donation__c, StageName
            FROM Opportunity
            WHERE npe03__Recurring_Donation__c IN :rdIds
            ORDER BY npe03__Recurring_Donation__c, CreatedDate DESC, CloseDate DESC
        ];
    }

    // Returns how many Opportunities of the given Recurring Donation have StageName equal to the status
    // sent, in any order (not restricted to consecutive ones), provided oppIdToCheck is one of them.
    // Uses the already queried list, no SOQL. Returns 0 when oppIdToCheck is not in that status.
    //SFESWCSD-91
    @TestVisible
    private static Integer getTotalPaidNumberByRdsAndStatus(
        Id rdId,
        Id oppIdToCheck,
        List<Opportunity> payments,
        String status
    ) {
        if (rdId == null || oppIdToCheck == null || String.isBlank(status) || payments == null) {
            return 0;
        }

        Integer total = 0;
        Boolean hasOppToCheck = false;
        for (Opportunity opp : payments) {
            if (opp.npe03__Recurring_Donation__c != rdId || opp.StageName != status) {
                continue;
            }
            total++;
            if (opp.Id == oppIdToCheck) {
                hasOppToCheck = true;
            }
        }
        return hasOppToCheck ? total : 0;
    }

    // Returns the length of the run of consecutive Opportunities of the given Recurring Donation whose
    // StageName equals the status sent AND that contains oppIdToCheck. Uses the already queried
    // (ordered) list, no SOQL. Returns 0 when oppIdToCheck is not in the RD sequence or is not in that status.
    //SFESWCSD-91
    @TestVisible
    private static Integer getConsecutiveTotalPaidNumberByRdsAndStatus(
        Id rdId,
        Id oppIdToCheck,
        List<Opportunity> payments,
        String status
    ) {
        if (rdId == null || oppIdToCheck == null || String.isBlank(status) || payments == null) {
            return 0;
        }

        Integer streak = 0;
        Boolean runHasOppToCheck = false;
        for (Opportunity opp : payments) {
            if (opp.npe03__Recurring_Donation__c != rdId) {
                continue;
            }
            if (opp.StageName == status) {
                streak++;
                if (opp.Id == oppIdToCheck) {
                    runHasOppToCheck = true;
                }
            } else {
                if (runHasOppToCheck) {
                    return streak;
                }
                streak = 0;
            }
        }
        return runHasOppToCheck ? streak : 0;
    }

    public Contact getContactById(List<Contact> conts, Id contactId) {
        for (Contact cont : conts) {
            if (cont.Id == contactId)  {
                return cont;
            }
        }
        return null;
    }
}