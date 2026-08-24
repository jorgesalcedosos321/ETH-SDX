/**
* @File Name : LeadService.cls
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

public with sharing class LeadService {
    /**
     * Searches for an existing lead.
     */
    private static Lead findlead(DonationRequest request) {

        List<Lead> leads = [
            SELECT Id,
                   FirstName,
                   LastName,
                   Email,
                   Phone
            FROM Lead
            WHERE (FirstName = :request.firstName AND LastName = :request.lastName AND Email = :request.email) OR 
                  (FirstName = :request.firstName AND LastName = :request.lastName AND Phone = :request.phone)
        ];

        return leads.isEmpty()
            ? null
            : leads[0];
    }

    /**
     * Builds a new lead.
     */
    private static Lead buildLead(DonationRequest request) {

        Lead lead = new Lead();

        lead.Salutation = request.salutation;
        lead.FirstName = request.firstName;
        lead.LastName = request.lastName;
        lead.Email = request.email;
        lead.Phone = request.phone;
        lead.Birthdate__c = request.birthday;

        lead.Mailing__Street__s = request.mailingStreet;
        lead.Mailing__City__s = request.mailingCity;
        //lead.Mailing__Country__s = request.mailingCountry;

        lead.HasOptedOutOfEmail = request.emailOptOut;

        return lead;
    }

    public static void setDefaultCompanyNameIfEmpty(List<Lead> newLeads) {
        for (Lead newLead : newLeads) {
            if (newLead.Company == NULL || newLead.Company == '' || newLead.Company == '-') {
                newLead.Company = 'No company registered.';
            }             
        }
    }
    
	/*public static void convertLeadIntoContact(Lead currentLead) {
		//, RecordTypeId = RecordTypeUtils.getRecordTypeId('Account','Organization')
		Account newAccount = new Account(name = currentLead.Company,  Phone = currentLead.MobilePhone);
		insert newAccount;

		Contact newContact = new Contact();
        newContact.AccountId = newAccount.Id; 
		newContact.Email = currentLead.Email;
		newContact.MobilePhone = currentLead.MobilePhone;
		newContact.FirstName = currentLead.FirstName;
		newContact.LastName = currentLead.LastName;
		newContact.Salutation = currentLead.Salutation;
		newContact.Phone = currentLead.Phone;
		newContact.GenderIdentity = currentLead.GenderIdentity;
		
		INSERT newContact;
    }

	public static void createOpportunity(Id contactId, Id accountId, String donationType, Decimal amount, Date closeDate) {
		//donationType == 'One-Off' or 'Committed'
		Opportunity opp = new Opportunity();
		opp.closeDate = closeDate;
		opp.Amount = amount;
		opp.ContactId = contactId;
		opp.AccountId = accountId;
		opp.RecordTypeId = RecordTypeUtils.getRecordTypeId('Opportunity', donationType);
		insert opp;
    }*/
}