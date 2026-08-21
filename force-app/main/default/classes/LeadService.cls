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