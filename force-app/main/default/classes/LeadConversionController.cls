/**
* @File Name : LeadConversionController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 16, 2024
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 16, 2024 |   | Initial Version
**/
public with sharing class LeadConversionController {

    public Lead lead { get; set; }
	public Boolean createOpportunity { get; set; }
    public String message { get; set; }

    // Constructor to initialize the Lead object
    public LeadConversionController(ApexPages.StandardController stdController) {
		System.debug('constructor');
        this.lead = (Lead)stdController.getRecord();
		System.debug('constructor:' + this.lead);
        createOpportunity = true;  // Default to create opportunity
    }
    
    @AuraEnabled
    public static List<RecordType> getOpportunityRTs() {
    	return [SELECT Id, Name FROM RecordType WHERE SobjectType='Opportunity'];
    }
    
	@AuraEnabled
    public static String convertLeadById(String leadId, Boolean createOpps, String oppRT) {
		System.debug('convertLead 1');
        try {
            // Retrieve the Lead record
            Lead leadToConvert = [SELECT Id, Salutation, FirstName, LastName, Email, Phone, LeadSource, Street, City, State, PostalCode, Country, Company, Title, Preferred_Communication_Method__c, Industry, Website  
                                  FROM Lead WHERE Id = :leadId LIMIT 1];
			System.debug('convertLead 2');
            // Convert the Lead using the standard LeadConvert process
            Database.LeadConvert leadConvert = new Database.LeadConvert();
            leadConvert.setLeadId(leadToConvert.Id);
            //LeadStatus convertStatus = [SELECT Id, ApiName FROM LeadStatus WHERE IsConverted=true LIMIT 1];
            leadConvert.setConvertedStatus('Closed - Converted');
            leadConvert.setDoNotCreateOpportunity(!createOpps);  // Adjust based on your requirements

            // Perform the conversion
            Savepoint sp = Database.setSavepoint();
            
			try {
                System.debug('leadConvert:' + leadConvert);
                Database.LeadConvertResult result = Database.convertLead(leadConvert);
    			System.debug('leadConvert2:' + result);
                // Return success or failure message
                if (result.isSuccess()) {
                    String error = '';
                    Id accountId = result.getAccountId();
                    Id contactId = result.getContactId();
                    Id relatedPersonAccountId = result.getRelatedPersonAccountId();
                    
                    if (createOpps) {
                        Id opportunityId = result.getOpportunityId();
                        Opportunity currentOpp = [SELECT Id, Name, RecordTypeId, RecordType.Name FROM Opportunity WHERE Id =: opportunityId LIMIT 1];
                        if (currentOpp.RecordTypeId != oppRT) {
                            RecordType rtToChange = [SELECT Id, Name FROM RecordType WHERE SobjectType='Opportunity' AND Id =: oppRT LIMIT 1];
                            currentOpp.RecordTypeId = oppRT;
                            currentOpp.Name = currentOpp.Name.Replace(currentOpp.RecordType.Name, rtToChange.Name);
                            UPDATE currentOpp;
                        }
                    }
                    
                    Contact newContact = [SELECT Id, Salutation, FirstName, LastName, Email, MobilePhone, Source__c, npe01__Primary_Address_Type__c, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, Company__c, Title, Preferred_Communication_Method__c FROM Contact WHERE Id =: contactId LIMIT 1];
                    newContact.Salutation = leadToConvert.Salutation;
                    newContact.FirstName = leadToConvert.FirstName;
                    newContact.LastName = leadToConvert.LastName; 
                    newContact.Email = leadToConvert.Email; 
                    newContact.MobilePhone = leadToConvert.Phone;
                    
                    Map<String, String> sourceContactPicklistValues = Utils.getPickListValues('Contact', 'Source__c');
                    if (sourceContactPicklistValues.containsKey(leadToConvert.LeadSource)) {
                        newContact.Source__c = leadToConvert.LeadSource;    
                    } else {
                        //error = 'Contact Source value "' + leadToConvert.LeadSource + '" not exists.';
                    }				
                    newContact.npe01__Primary_Address_Type__c = 'Home';
                    newContact.MailingStreet = leadToConvert.Street;
                    newContact.MailingCity = leadToConvert.City;
                    newContact.MailingState = leadToConvert.State;
                    newContact.MailingPostalCode = leadToConvert.PostalCode;
                    newContact.MailingCountry = leadToConvert.Country;
                    newContact.Company__c = leadToConvert.Company;
                    newContact.Title = leadToConvert.Title;
                    Map<String, String> pcmContactPicklistValues = Utils.getPickListValues('Contact', 'Preferred_Communication_Method__c');
                    System.debug('leadToConvert pcmContactPicklistValues:' + pcmContactPicklistValues);
                    System.debug('leadToConvert Preferred_Communication_Method__c:' + leadToConvert.Preferred_Communication_Method__c);
                    if (pcmContactPicklistValues.containsKey(leadToConvert.Preferred_Communication_Method__c)) {
                        System.debug('leadToConvert pcmContactPicklistValues: setting value');
                        newContact.Preferred_Communication_Method__c = leadToConvert.Preferred_Communication_Method__c;
                    } else {
                        //error += 'Contact Preferred Communication Method value "' + leadToConvert.LeadSource + '" not exists.';
                    }	
                    
                    UPDATE newContact;
    				System.debug('leadToConvert newContact:' + newContact);
                    Account newAccount = [SELECT Id, Name, Industry, Website, AccountSource, Mailing_Address__c, Mailing_Address__StateCode__s, Mailing_Address__City__s, Mailing_Address__Street__s, Mailing_Address__PostalCode__s, Mailing_Address__CountryCode__s FROM Account WHERE Id =: accountId LIMIT 1];
                    newAccount.Name = leadToConvert.LastName + ' Household';
                    newAccount.Mailing_Address__Street__s = leadToConvert.Street;
                    newAccount.Mailing_Address__City__s = leadToConvert.City;
                    newAccount.Mailing_Address__StateCode__s = leadToConvert.State;
                    newAccount.Mailing_Address__PostalCode__s = leadToConvert.PostalCode;
                    newAccount.Mailing_Address__CountryCode__s = leadToConvert.Country;
                    newAccount.RecordTypeID = RecordTypeUtils.getRecordTypeId('Account', 'Household Account');                    
                    UPDATE newAccount;
                    
                    DELETE [SELECT Id, npe5__Organization__c FROM npe5__Affiliation__c WHERE npe5__Contact__c =: newContact.Id];
                        
                	if (!String.isBlank(leadToConvert.Company) && !leadToConvert.Company.contains('No company')) {
                        newAccount = new Account();
                        newAccount.Name = leadToConvert.Company;
                        newAccount.Industry = leadToConvert.Industry;
                        newAccount.Website = leadToConvert.Website;
                        Map<String, String> sourceAccountPicklistValues = Utils.getPickListValues('Account', 'AccountSource');
                        if (sourceAccountPicklistValues.containsKey(leadToConvert.LeadSource)) {
                            newAccount.AccountSource = leadToConvert.LeadSource;    
                        } else {
                            //error += 'Account Source value "' + leadToConvert.LeadSource + '" not exists.';
                        }	
                        newAccount.RecordTypeID = RecordTypeUtils.getRecordTypeId('Account', 'Organization');
                        INSERT newAccount;
                        
                        npe5__Affiliation__c aff = new npe5__Affiliation__c();
                        aff.npe5__Contact__c = newContact.Id;
                        aff.npe5__Organization__c = newAccount.Id;
                        aff.npe5__Primary__c = true;
                        INSERT aff;                        
                    }
                    return 'Lead convertion was done successfully! ' + error + ' .Please wait to redirect the page.';
                } else {
                    return 'Error: ' + result.getErrors()[0].getMessage();
                }
            }catch(Exception e){
                // An exception was caught. We need to revert back to our Savepoint
                // This will rollback all successful changes. So, if opps saved successfully
                // and then quotes failed, the opps will be rolled back as well
                Database.rollback(sp);
            
                // Add the error to the page for the user to see
                return 'Error: ' + e.getMessage();
            }
			//return 'success';
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            // Catch and return error if something goes wrong
            return 'Error: ' + e.getMessage();
        }
        //return null;
    }

	 @AuraEnabled
    public static Lead getLeadData(String leadId) {
        try {
            // Query the Lead record based on the provided Lead ID
            Lead lead = [SELECT Id, Salutation, FirstName, LastName, Email, Phone, LeadSource, Company 
                         FROM Lead WHERE Id = :leadId LIMIT 1];
            
            // Return the Lead record to the Aura component
            return lead;
        } catch (Exception e) {
            // Return a custom error message if something goes wrong
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
}