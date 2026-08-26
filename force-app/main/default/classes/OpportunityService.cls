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
			if (oldRecords == null && newRecord.npe03__Recurring_Donation__c == NULL && newRecord.StageName == 'Closed Won' && (newRecord.Type == 'Individual Committed' || newRecord.Type == 'Individual One-off')) {
				oppConIds.put(newRecord.Id, newRecord.ContactId);
			}
			if (oldRecords != null && newRecord.npe03__Recurring_Donation__c == NULL && newRecord.StageName == 'Closed Won' && oldRecords.get(newRecord.Id).StageName <> newRecord.StageName && newRecord.StageName == 'Closed Won' && (newRecord.Type == 'Individual Committed' || newRecord.Type == 'Individual One-off')) {
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
        Set<String> emailTemplateNames = new Set<String>{'Thank You Email','Welcome Email','Referral Ask Email','Impact Email','Upgrade Email','One Year Thank You Email'};
		List<EmailTemplate> emailTemplates = new List<EmailTemplate>();
        
        if (!Test.isRunningTest()) {
            emailTemplates = [SELECT Id, Name, Subject, HtmlValue, Body FROM EmailTemplate WHERE Name IN : emailTemplateNames];
        } else {
            emailTemplates = new List<EmailTemplate>{
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
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Thank You Email');
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
    
    public Contact getContactById(List<Contact> conts, Id contactId) {
        for (Contact cont : conts) {
            if (cont.Id == contactId)  {
                return cont;
            }
        }
        return null;
    }
}
