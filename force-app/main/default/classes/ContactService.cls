public with sharing class ContactService {
    /**
     * Creates or updates a Contact.
     */
    //SFESWCSD-92
    public static Contact createOrUpdate(DonationRequest request) {
        return createOrUpdate(request, null);
    }

    public static Contact createOrUpdate(
        DonationRequest request,
        Id accountId
    ) {
        Contact contact = findContact(request);

        if (contact == null) {
            contact = buildContact(request);
            contact.AccountId = accountId;
            insert contact;
        } else {
            updateContact(contact, request);
            if (accountId != null) {
                contact.AccountId = accountId;
            }
            update contact;
        }

        return [
            SELECT Id, AccountId, FirstName, LastName, Email, Phone
            FROM Contact
            WHERE Id = :contact.Id
            LIMIT 1
        ];
    }

    /**
     * Searches for an existing Contact.
     */
    private static Contact findContact(DonationRequest request) {

        List<Contact> contacts = [
            SELECT Id,
                   AccountId,
                   FirstName,
                   LastName,
                   Email,
                   Phone
            FROM Contact
            WHERE (FirstName = :request.firstName AND LastName = :request.lastName AND Email = :request.email) OR 
                  (FirstName = :request.firstName AND LastName = :request.lastName AND Phone = :request.phone)
        ];

        return contacts.isEmpty()
            ? null
            : contacts[0];
    }

    /**
     * Builds a new Contact.
     */
    private static Contact buildContact(DonationRequest request) {

        Contact contact = new Contact();

        contact.Salutation = request.salutation;
        contact.FirstName = request.firstName;
        contact.LastName = request.lastName;
        contact.Email = request.email;
        contact.Phone = request.phone;
        contact.Birthdate = request.birthday;

        contact.MailingStreet = request.mailingStreet;
        contact.MailingCity = request.city;
        contact.MailingState = request.mailingState;
        contact.MailingPostalCode = request.mailingPostalCode;
        contact.MailingCountry = request.country;

        contact.HasOptedOutOfEmail = request.emailOptOut;

        return contact;
    }

    /**
     * Updates an existing Contact.
     */
    private static void updateContact(
        Contact contact,
        DonationRequest request
    ) {

        contact.Salutation = request.salutation;
        contact.FirstName = request.firstName;
        contact.LastName = request.lastName;
        contact.Email = request.email;
        contact.Phone = request.phone;
        contact.Birthdate = request.birthday;

        contact.MailingStreet = request.mailingStreet;
        contact.MailingCity = request.city;
        contact.MailingState = request.mailingState;
        contact.MailingPostalCode = request.mailingPostalCode;
        contact.MailingCountry = request.country;

        contact.HasOptedOutOfEmail = request.emailOptOut;
    }
    
    public static void setEmailField(List<Contact> contacts) {
        for (Contact con : contacts) {
            String emailToSend = con.npe01__Preferred_Email__c == 'Personal' ? con.npe01__HomeEmail__c : con.npe01__Preferred_Email__c == 'Work' ? con.npe01__WorkEmail__c : con.npe01__Preferred_Email__c == 'Alternate' ?  con.npe01__AlternateEmail__c : '';
            con.Email = emailToSend; 
        }
    }
    
	public static void calculateHouseholdMembersInAccount(List<Contact> contacts) {
        Set<Id> accounts = new Set<Id>();
        for (Contact cons : contacts) {
            if (cons.AccountId != NULL) {
             	 accounts.add(cons.AccountId);  
            }
        }
        
        for (Id accountId : accounts) {            
            Integer counting = [SELECT Count() FROM Contact WHERE AccountId =: accountId AND IsDeleted = false];            
            Account currentAccounts = [SELECT Id, npsp__Number_of_Household_Members__c FROM Account WHERE Id =: accountId LIMIT 1]; 
            currentAccounts.npsp__Number_of_Household_Members__c = counting;
            UPDATE currentAccounts;
        }
    }

    public static void sendBirthdayCard(List<Contact> newRecords, Map<Id, Contact> oldRecords) {
        Date dateToday = Date.Today(); 
        for (Contact newRecord : newRecords) {
            if(newRecord.Birthdate != null){
                System.debug('sendBirthdayCard newRecord:' + newRecord);
                Map<String, String> params = Utils.replaceEmailTemplateParams(null, newRecord.FirstName + ' ' + newRecord.LastName);
                if (oldRecords == null && newRecord.Birthdate.Month() == dateToday.Month() &&  newRecord.Birthdate.Day() == dateToday.Day()) {                
                    String emailToSend = newRecord.npe01__Preferred_Email__c == 'Personal' ? newRecord.npe01__HomeEmail__c : newRecord.npe01__Preferred_Email__c == 'Work' ? newRecord.npe01__WorkEmail__c : newRecord.npe01__Preferred_Email__c == 'Alternate' ?  newRecord.npe01__AlternateEmail__c : '';
                    Utils.sendEmailByTemplate(Utils.emailTemplateHappyBirthdayEmail, params, null, newRecord.Id, new List<String> {emailToSend});
                } else if (oldRecords != null && newRecord.Birthdate <> oldRecords.get(newRecord.Id).Birthdate && newRecord.Birthdate.Month() == dateToday.Month() &&  newRecord.Birthdate.Day() == dateToday.Day()) {
                    String emailToSend = newRecord.npe01__Preferred_Email__c == 'Personal' ? newRecord.npe01__HomeEmail__c : newRecord.npe01__Preferred_Email__c == 'Work' ? newRecord.npe01__WorkEmail__c : newRecord.npe01__Preferred_Email__c == 'Alternate' ?  newRecord.npe01__AlternateEmail__c : '';
                    Utils.sendEmailByTemplate(Utils.emailTemplateHappyBirthdayEmail, params, null, newRecord.Id, new List<String> {emailToSend});				                
                }
            }
        }
    }
    //IMplementing happy birthday if birthday is different and today
}
