//NEW VERSION: LATEST CHANGES
@RestResource(urlMapping='/InsertWSData/*')
global class InsertWSData {
    @HttpPost 
    global static void CreateWSTransaction() {
        if (RestContext.request.requestBody != null) {
            String body = RestContext.request.requestBody.ToString().trim();
            system.debug('#### body: ' + body);
            Id transactionId = TransactionService.insertTransaction(body);
            JSONGenerator gen = JSON.createGenerator(true);
            body = body.replace('\"Currency\"', '\"CurrencyAmount\"'); //Conversion for reserve word "Currency"
            List<npe03__Recurring_Donation__c> ltsRecurringDonation = new List<npe03__Recurring_Donation__c>();
            List<Opportunity> ltsOpp = new List<Opportunity>();
            
            try 
            {
                JSONParser parse = JSON.createParser(body);
                WSUtilsV2.WSV2 ws = (WSUtilsV2.WSV2)parse.readValueAs(WSUtilsV2.WSV2.class);
                
                String year;
                String month;
                String day;
                Date myDate;
                String phoneStr= '' + ws.Phone;
                String emailStr = ws.Email;
                String idContact = null; 
                String idAccount = null; 
                String emailFromOrg = null;
                String phoneFromOrg = null;
                Datetime startDatetime;
                Date startDate;
                String validationErrors = '';
                String currencyValue = String.isBlank(ws.CurrencyAmount) ? 'NAD' : ws.CurrencyAmount;
                
                try {
                	startDatetime = Utils.parseDatetime(ws.TransactionDate);    
                     startDate = startDatetime.date();
                }catch(IllegalArgumentException ex) {
                    validationErrors += ex.getMessage() + ' / ';
                }
                
                String companyName = String.isNotBlank(ws.companyName) ? string.escapeSingleQuotes(ws.companyName) : '';                
                String donorType = ((ws.AddressType == 'company' || String.isNotBlank(companyName)) ? 'Corporate' : 'Individual');
                Boolean isCorporate = (donorType.equalsIgnoreCase('corporate'));
                Boolean isOneOffDonation = ws.FormType == 'One-time Donation';
                        
                if (isCorporate && String.isBlank(companyName)) {
                    validationErrors += 'Company Name is missing / ';
                }
                                                             
                if (!Utils.isValidDecimal(ws.Amount, true)) {
                    validationErrors += 'Amount is not valid / ';
                }
                
                //if (!Utils.isValidInteger(ws.PhoneArea) && String.isNotBlank(ws.PhoneArea)) {
                //    validationErrors += 'PhoneArea is not valid / ';
                //}
                
                if (!Utils.isValidEmail(emailStr)) {
                    validationErrors += 'Email is not valid / ';
                }
                
                if (!Utils.isValidPhone(phoneStr)) {
                    validationErrors += 'Phone is not valid / ';
                }
                
                if (String.isBlank(ws.DonationId) && isOneOffDonation) {
                    validationErrors += 'Donation Id is mandatory for One Off Donations / ';
                }
                
                if (String.isNotBlank(validationErrors)) {
                    //gen = Utils.setJSONGenerator(gen, false, validationErrors, '', '', '');
                    TransactionService.updateTransactionErrors(transactionId, validationErrors);
                    gen = Utils.setJSONGeneratorSimple(gen, false, validationErrors);                                
                    RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
                    return;
                }
                
                String paymentType = (String.isBlank(ws.PaymentType) ? '' : ws.PaymentType);                    
                Decimal amount = String.isBlank(ws.Amount) ? 0 : Decimal.valueOf(ws.Amount);
                emailStr = string.escapeSingleQuotes(emailStr);
                phoneStr = ws.PhoneArea+phoneStr;                
                phoneStr = string.escapeSingleQuotes(phoneStr);
                    
                if (String.isBlank(paymentType)) { //First Transaction
                    System.debug('###First Transaction');
                    List<Contact> searchListPhone = new List<Contact>();
                    //searchListPhone = [SELECT Id, Phone, Email FROM Contact WHERE Phone =: phoneStr];
                    emailStr = string.escapeSingleQuotes(emailStr);
                    phoneStr = string.escapeSingleQuotes(phoneStr);
                    searchListPhone = [SELECT Id, npe01__WorkPhone__c, MobilePhone, npe01__WorkEmail__c, npe01__HomeEmail__c FROM Contact WHERE npe01__WorkPhone__c =: phoneStr OR MobilePhone =: phoneStr OR npe01__WorkEmail__c =: emailStr OR npe01__HomeEmail__c =: emailStr];
                     
                    system.debug('###First Transaction phoneStr: ' + phoneStr);
                    system.debug('###First Transaction searchListPhone: ' + searchListPhone);
                    
                    if (!searchListPhone.isEmpty()) {
                        for (Contact cc : searchListPhone) {
                            if (isCorporate && (cc.npe01__WorkPhone__c == phoneStr || cc.npe01__WorkEmail__c == emailStr)) {
                                idContact = cc.Id;
                                phoneFromOrg = cc.npe01__WorkPhone__c;
                                emailFromOrg = cc.npe01__WorkEmail__c;
                            }
                            else if (!isCorporate && (cc.MobilePhone == phoneStr || cc.npe01__HomeEmail__c == emailStr)) {
                                idContact = cc.Id;
                                phoneFromOrg = cc.MobilePhone;
                                emailFromOrg = cc.npe01__HomeEmail__c;
                            }       
                        }
                    }
                    
                    Contact c = new Contact();
                    
                    if (String.isNotBlank(idContact)){
                        c.Id = idContact;
                        //TODO: needs to check in case of corporate
                        if (phoneFromOrg != phoneStr) {
                            c.OtherPhone = phoneStr;
                        }
                        if (emailFromOrg != emailStr) {
                            c.npe01__AlternateEmail__c = ws.Email;
                        }
                    } else {
                        c.npe01__Preferred_Email__c = (isCorporate ? 'Work' : 'Personal');
                        c.npe01__PreferredPhone__c = (isCorporate ? 'Work' : 'Mobile');
                        
                        if (isCorporate) {
                            c.npe01__WorkPhone__c = phoneStr;
                            c.npe01__WorkEmail__c = ws.Email;
                        } else {
                            c.MobilePhone = phoneStr;
                            c.npe01__HomeEmail__c = ws.Email;
                        }
                    }
                    
                    if (Utils.isValidPicklistValue('Contact', 'Salutation', ws.Salutation)) {
                        c.Salutation = ws.Salutation;    
                    } else {
                        String defaultvalue = Utils.defaultPicklistValue('Contact', 'Salutation');
                        if (String.isNotBlank(defaultvalue)) {
                            c.Salutation = defaultvalue;
                        }                    
                    }
                    
                    c.FirstName = ws.FirstName;
                    c.LastName = ws.LastName;
                    c.Newsletter_Subscription__c = ((String.isNotBlank(ws.Newsletter) && ws.Newsletter.toLowerCase() == 'true') ? true : false);				
                    
                    if (String.isNotBlank(ws.AddressLine1) || Test.isRunningTest()){
                        c.MailingStreet = ws.AddressLine1;
                        c.MailingCity = ws.City;
                        c.MailingState = ws.Region;
                        c.MailingCountry = ws.Country;
                        //getGeocodeAccuracy
                        //c.MailingZip = ws.Zip;	https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_system_Address.htm
                    }
                    
                    Boolean isNewContact = false;
                    if (c.Id == null) {
                        INSERT c;
                        idContact = c.Id;
                        isNewContact = true;
                    }
                    
                    Account ca = null;
                    
                    if (isCorporate) {
                        ca = getAccountByCompanyName(companyName);
                        
                        if (ca == NULL) {
                            ca = manageAccount(ca, c, ws, companyName);    
                        } 
                        ca.npe01__One2OneContact__c = idContact;                
                        UPSERT ca;
                        idAccount = ca.Id;
                        c.Company__c = ws.CompanyName;                
                        c.npsp__Primary_Affiliation__c = ca.Id;
                    }                
                    
                    if (String.isNotBlank(ws.FacerId) && isNewContact) {
                        List<Other_Participation__c> lstFacer = new List<Other_Participation__c> ([SELECT Contact__c FROM Other_Participation__c WHERE Facer_Code__c = :ws.FacerId]);
                        if (lstFacer.size() > 0) {
                            c.Facer__c = lstFacer.get(0).Contact__c;
                        }
                    }
                    
                    if (String.isNotBlank(ws.FacerLocationId) && isNewContact) {
                        List<Location__c> newlocations = [SELECT Id FROM Location__c WHERE Location_ID__c =: ws.FacerLocationId];
                        if (newlocations != null && !newlocations.isEmpty()) {
                            c.Location__c = newlocations[0].Id;
                        }
                    }
                    
                    if (String.isNotBlank(c.Facer__c) && String.isNotBlank(c.Location__c)) {
                    	c.Source__c = 'F2F';
                    }
                    
                    Boolean errors = false;
                    system.debug('###First Transaction before creating Contact');
                    try {
                        UPSERT c;            
                        idContact = c.Id; 
                        errors = false;                     
                    } catch(DMLException e){
                        errors = true;
                        system.debug('#### error c:' + e.getMessage());
                        //gen = Utils.setJSONGenerator(gen, false, e.getMessage(), '', '', '');
                        TransactionService.updateTransactionErrors(transactionId, e.getMessage());
                        gen = Utils.setJSONGeneratorSimple(gen, false, e.getMessage());
                        RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
                        return;
                    }
                    system.debug('###First Transaction after creating Contact:' + c);
                    system.debug('###First Transaction errors:' + errors);
                        
                    if (isCorporate && ca != NULL && String.isNotBlank(idContact)) {
                        ca.npe01__One2OneContact__c = idContact;                
                        UPSERT ca;
                    } 
                    
                    if (!errors) {
                        String installmentPeriod = (String.isBlank(ws.Frequency) ? '' : ws.Frequency); //one-off/monthly/annually    
                        
                        if (installmentPeriod.equalsIgnoreCase('annual')) {
                            installmentPeriod = 'Yearly';
                        }
                        Boolean isRecurringDonation = ws.FormType == 'Recurring Donation';    
                        Boolean isSponsorship = ws.FormType == 'Sponsorship';
                        
                        system.debug('###First Transaction isOneOffDonation:' + isOneOffDonation);
                        system.debug('###First Transaction isRecurringDonation:' + isRecurringDonation);
                        if (isRecurringDonation || isSponsorship) {
                            List<npe03__Recurring_Donation__c> existsSameDonationId = [SELECT Id FROM npe03__Recurring_Donation__c WHERE Donation_ID__c =: ws.DonationId];
                        	system.debug('###First Transaction existsSameDonationId:' + existsSameDonationId);    
                            if (existsSameDonationId.isEmpty()) {
                                npe03__Recurring_Donation__c rd = new npe03__Recurring_Donation__c();
                                rd.npsp__Day_of_Month__c = Utils.lastDayOfMonth();
                                rd.Sponsorship_Category__c = convertSponsorship(ws.Preference);
                                rd.Sponsorship_Type__c = ws.DonationType;
                                rd.Donation_ID__c = ws.DonationId;
                                //rd.transaction_ID__c = ws.ReferenceId;
                                if (isRecurringDonation) {
                                	rd.npsp__RecurringType__c = 'Open';
                                }
                                
                                if (installmentPeriod.equalsIgnoreCase('monthly')){
                                    //rd.npe03__Open_Ended_Status__c = 'Open';
                                    //rd.npe03__Installments__c = Utils.numberOfInstallmentsOnCommitedDonation;     
                                    installmentPeriod = 'Monthly';
                                } else if (installmentPeriod.equalsIgnoreCase('anually')){
                                    //rd.npe03__Open_Ended_Status__c = 'Open';
                                    //rd.npe03__Installments__c = 1;     
                                    installmentPeriod = 'Yearly';
                                } 
                                rd.Donor_Type__c = donorType;
                                rd.Donation_Type__c = ws.FormType;
                                rd.transaction_ID__c = ws.TransactionID;
                                rd.npe03__Installment_Period__c = installmentPeriod;
                                String campaignNameRelated = null;
                                
                                if (String.isNotBlank(ws.facerID)) {
                                    List<Facer_Campaign__c> facerCampaignRelated = [SELECT Campaign_Name__c, Online_Campaign_Name__c FROM Facer_Campaign__c WHERE Facer_ID__c =: ws.facerID];
                                    
                                    if (!facerCampaignRelated.isEmpty() && String.isNotBlank(paymentType)) {
                                        campaignNameRelated = (paymentType == 'Online' ? facerCampaignRelated[0].Online_Campaign_Name__c : facerCampaignRelated[0].Campaign_Name__c);
                                    }
                                    
                                    List<Other_Participation__c> lstFacer = [SELECT Contact__c FROM Other_Participation__c WHERE Facer_Code__c = :ws.facerID];
                                    if (!lstFacer.isEmpty()) {
                                        rd.Facer__c = lstFacer.get(0).Contact__c;
                                    }
                                }
                                
                                List<Campaign> cs = new List<Campaign>();
                                if (String.isNotBlank(campaignNameRelated)){
                                    cs = [SELECT Id FROM Campaign WHERE Name =: campaignNameRelated];                            
                                } else if (String.isNotBlank(ws.campaignID)) {
                                    cs = [SELECT Id FROM Campaign WHERE Campaign_ID__c =: ws.campaignID];
                                }                        
                                
                                if (!cs.isEmpty()){
                                    rd.npe03__Recurring_Donation_Campaign__c = cs.get(0).Id;
                                }                            
                                
                                if (String.isNotBlank(ws.FacerLocationId)) {
                                    List<Location__c> locations = [SELECT Id FROM Location__c WHERE Location_ID__c = :ws.FacerLocationId];
                                    
                                    if (!locations.isEmpty()) {
                                        rd.Location__c = locations[0].Id;
                                    }
                                }
                                
                                if (String.isNotBlank(ws.FacerId) && String.isNotBlank(ws.FacerLocationId) && String.isBlank(rd.npe03__Recurring_Donation_Campaign__c)) {
                                    rd.npe03__Recurring_Donation_Campaign__c = getCampaignDefault();
                                }
                                
                                rd.Transaction_ID__c = ws.TransactionId;
                                rd.npe03__Amount__c = amount;
                                rd.npe03__Schedule_Type__c = 'Multiply By';
                                
                                if (isCorporate) {
                                	rd.npe03__Organization__c = idAccount;    
                                    //rd.npe03__Contact__c = idContact;    TODO: to confirm
                                } else {
                                    rd.npe03__Contact__c = idContact;    
                                }                                
                                
                                if (startDate <> null) {
                                    rd.npe03__Date_Established__c = startDate;
                                }
                                
                                ltsRecurringDonation.add(rd);
                            } else {
                            	//gen = Utils.setJSONGenerator(gen, false, 'Recurring Donation Id already exists:"' + ws.DonationId + '"', '', '', '');    
                                gen = Utils.setJSONGeneratorSimple(gen, false, 'Recurring Donation Id already exists:"' + ws.DonationId + '"');
                                TransactionService.updateTransactionErrors(transactionId, 'Recurring Donation Id already exists:"' + ws.DonationId + '"');
                                RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
                        		return;
                            }  
                        } else if (isOneOffDonation) {
                            system.debug('###First Transaction isOneOffDonation:' + isOneOffDonation);    
                            List<Opportunity> existsSameDonationId = [SELECT Id FROM Opportunity WHERE Donation_ID__c =: ws.DonationId];
                            system.debug('###First Transaction existsSameDonationId:' + existsSameDonationId);    
                            if (existsSameDonationId.isEmpty()) {
                                Opportunity opp = new Opportunity();
                                opp.Currency__c = currencyValue;
                                //opp.Transaction_ID__c = ws.TransactionId;
                                //opp.npe03__Schedule_Type__c = 'Multiply By';
                                //opp.npe03__Installment_Period__c = installmentPeriod;
                                opp.StageName = 'Pledged';
                                opp.Amount = amount;
                                opp.npsp__Primary_Contact__c = idContact;
                                opp.Donor_Type__c = donorType;
                                opp.Donation_Type__c = ws.FormType;
                                opp.Donation_ID__c = ws.DonationId; 
                                opp.CloseDate = startDatetime.date();
                                opp.Name = 'Opportunity ' + ws.DonationId;
                                
                                if (String.isNotBlank(ws.FacerId) && String.isNotBlank(ws.FacerLocationId) && String.isBlank(ws.CampaignId)) {
                                    opp.CampaignId = getCampaignDefault();
                                }                                
                                
                                if (startDate <> null) {
                                    opp.npsp__Grant_Contract_Date__c = startDate;
                                }
                                if (isCorporate) {
                                	opp.AccountId = idAccount;    
                                } else {
                                    opp.npsp__Primary_Contact__c = idContact;    
                                } 
                                ltsOpp.add(opp);
                            } else {
                            	//gen = Utils.setJSONGenerator(gen, false, 'One-Off Donation Id already exists:"' + ws.DonationId + '"', '', '', '');    
                                gen = Utils.setJSONGeneratorSimple(gen, false, 'One-Off Donation Id already exists:"' + ws.DonationId + '"');
                                TransactionService.updateTransactionErrors(transactionId, 'One-Off Donation Id already exists:"' + ws.DonationId + '"');
                                RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
                        		return;
                            }    
                        } 
                        
                        Boolean errorsRD = false;
                        
                        try {
                            system.debug('###First Transaction ltsRecurringDonation:' + ltsRecurringDonation);    
                            system.debug('###First Transaction ltsOpp:' + ltsOpp);    
                            if (!ltsRecurringDonation.isEmpty()){
                                INSERT ltsRecurringDonation;
                                errorsRD = false;
                                List<Opportunity> oppsRelated = [SELECT Id, CampaignId, Donation_ID__c, Currency__c, Donor_Type__c, Donation_Type__c FROM Opportunity WHERE npe03__Recurring_Donation__c =: ltsRecurringDonation[0].Id];
                                
                                for (Opportunity opp : oppsRelated) {
                                	opp.Donor_Type__c = donorType;  
                                    opp.Donation_ID__c = ws.DonationId; 
                                    opp.Donation_Type__c = ws.FormType;
                                    opp.Currency__c = currencyValue;
                                    opp.Donation_ID__c = ws.DonationId; 
                                    if (String.isNotBlank(ws.FacerId) && String.isNotBlank(ws.FacerLocationId) && String.isBlank(ws.CampaignId)) {
                                        opp.CampaignId = getCampaignDefault();
                                    } 
                                }
                                
                                UPDATE oppsRelated;
                                
                                String name = [SELECT Name FROM npe03__Recurring_Donation__c WHERE Id =: ltsRecurringDonation[0].Id].Name;
                                //gen = Utils.setJSONGenerator(gen, true, '', name, '', 'DonationID');
                                gen = Utils.setJSONGeneratorSimple(gen, true, 'DonationID:"' + name + '" was created.');
                                RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
                        		return;
                            }
                            if (!ltsOpp.isEmpty()){
                                INSERT ltsOpp;
                                errorsRD = false;
                                String name = [SELECT Name FROM Opportunity WHERE Id =: ltsOpp[0].Id].Name;
                                //gen = Utils.setJSONGenerator(gen, true, '', name, '', 'DonationID');
                                gen = Utils.setJSONGeneratorSimple(gen, true, 'DonationID:"' + name + '" was created.');
                                RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
                        		return;
                            } 
                            if (ltsOpp.isEmpty() && ltsRecurringDonation.isEmpty()) {
                                //gen = Utils.setJSONGenerator(gen, false, 'Donation was not registered', '', '', '');    
                                gen = Utils.setJSONGeneratorSimple(gen, false, 'Donation was not registered');
                                TransactionService.updateTransactionErrors(transactionId, 'Donation was not registered');
                                RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
                        		return;
                            }
                        } catch(DMLException e){
                            system.debug('#### error rd');
                            errorsRD = true;
                            //gen = Utils.setJSONGenerator(gen, false, e.getMessage(), '', '', '');
                            gen = Utils.setJSONGeneratorSimple(gen, false, e.getMessage());
                            TransactionService.updateTransactionErrors(transactionId, e.getMessage());
                            RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
                        	return;
                        }
                    }                
                } else { //Second Transaction based on "Donation Id"
                    system.debug('###Second Transaction:');    
                    
                    List<npe01__OppPayment__c> oppPayments = [SELECT Id, Name, npe01__Paid__c, npe01__Scheduled_Date__c, npe01__Payment_Date__c, npe01__Written_Off__c, npe01__Opportunity__r.npe03__Recurring_Donation__c,
                                                              npe01__Opportunity__c, npsp__Card_Expiration_Month__c, npsp__Card_Expiration_Year__c, npsp__Card_Last_4__c, Credit_Card_Number__c, Credit_Card_Holder__c,
                                                              npe01__Payment_Method__c, Transaction_Ref__c
                                                              FROM npe01__OppPayment__c
                                                              WHERE npe01__Opportunity__r.Donation_ID__c =: ws.DonationId OR 
                                                              npe01__Opportunity__r.npe03__Recurring_Donation__r.Donation_ID__c =: ws.DonationId //TODO: Should be implemented for RDs?
                                                              ORDER BY npe01__Scheduled_Date__c];                    
					
                    List<npe03__Recurring_Donation__c> rdToUpdate = new List<npe03__Recurring_Donation__c>();
                    
                    system.debug('###Second Transaction oppPayments:' + oppPayments);    
                    if (!oppPayments.isEmpty() && String.isNotBlank(ws.DonationId)) {
                        if (String.isNotBlank(ws.ReferenceId)) {
                            rdToUpdate = [SELECT Id, Transaction_ID__c FROM npe03__Recurring_Donation__c WHERE Id =: oppPayments[0].npe01__Opportunity__r.npe03__Recurring_Donation__c];
                        }
                        
                        if(paymentType == 'Credit Card') {
                            oppPayments[0].npsp__Card_Expiration_Month__c = getYear(ws.CreditCardExpiry);
                            oppPayments[0].npsp__Card_Expiration_Year__c = getMonth(ws.CreditCardExpiry);
                            oppPayments[0].npsp__Card_Last_4__c = getLast4Digits(ws.CreditCardNumber);
                            oppPayments[0].Credit_Card_Number__c = ws.CreditCardNumber;
                            oppPayments[0].Credit_Card_Holder__c = ws.CreditCardHolder;
                        }
                        //oppPayments[0].npsp__Gateway_Payment_ID__c =  ws.DonationId;
                        if (String.isBlank(oppPayments[0].npe01__Opportunity__r.npe03__Recurring_Donation__c)) {
                            if (paymentType == 'DPO') {
                                paymentType = 'Credit Card'; 
                            }
                        }
                        oppPayments[0].Transaction_Ref__c = ws.ReferenceId;
                        oppPayments[0].npe01__Payment_Method__c = paymentType;
                        oppPayments[0].npe01__Payment_Date__c =  system.now().date();
                        oppPayments[0].npe01__Paid__c = true;
                        oppPayments[0].npe01__Written_Off__c = false;
                        oppPayments[0].npe01__Scheduled_Date__c = startDatetime.date();
                        
                        //Opportunity opp = new Opportunity();
                        //opp.id = oppPayments[0].npe01__Opportunity__c;
                        //update opp;
                        update oppPayments[0];
                        gen = Utils.setJSONGeneratorSimple(gen, true, 'DonationID:"' + ws.DonationId + '" was paid.');
                        RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
                        
                        if (!rdToUpdate.isEmpty()) {
                            if (String.isBlank(rdToUpdate[0].Transaction_ID__c) && String.isNotBlank(ws.ReferenceId)) {
                                rdToUpdate[0].Transaction_ID__c = ws.ReferenceId;
                                UPDATE rdToUpdate;
                            }
                        }
                        return;
                    } else {
                        gen = Utils.setJSONGeneratorSimple(gen, false, 'Payment by Donation Id does not exists:"' + ws.DonationId + '"');
                        TransactionService.updateTransactionErrors(transactionId, 'Payment by Donation Id does not exists:"' + ws.DonationId + '"');
                        //gen = Utils.setJSONGenerator(gen, false, 'Payment by Donation Id does not exists:"' + ws.DonationId + '"', '', '', '');    
                        RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
                        return;
                    }
                }                
            } catch(Exception e){
                system.debug('#### error general');
                system.debug('#### error general:'+e.getMessage());
                TransactionService.updateTransactionErrors(transactionId, e.getMessage());
                //gen = Utils.setJSONGenerator(gen, false, e.getMessage(), '', '', '');
                gen = Utils.setJSONGeneratorSimple(gen, false, e.getMessage());                        
            }
            RestContext.response.responseBody = Blob.valueOf(gen.getAsString());
            return;
        }
    }
    
    public static String getYear(String dateCardExpiration) {
        if (dateCardExpiration.length() == 6) {
            return dateCardExpiration.substring(2, 4);
        }
        return '';
    }
    
    public static String getMonth(String dateCardExpiration) {
        if (dateCardExpiration.length() == 6) {
            return dateCardExpiration.substring(0, 2);
        }
        return '';
    }    
    
    public static String getLast4Digits(String dateCardNumber){
        if (dateCardNumber.length() > 4) {
            return dateCardNumber.right(4);
        }
        return '';
    }
    
    public static Task createTask(Id contactId) {
        Task t1 = new Task();
        t1.OwnerId = Utils.getUserToReportFalsePaymentStatus(); 
        t1.Subject = 'Donation Unsucessful';
        t1.WhoId = contactId;
        t1.ActivityDate = Date.today().addDays(3);
        t1.Status = 'In Progress';
        t1.Priority = 'Normal';
        return t1;
    }
    
    public static Account getAccountByCompanyName(String companyName) {
        if (String.isNotBlank(companyName)) {
            List<Account> accounts = [SELECT Id, Name, npe01__One2OneContact__c, Phone, accountSource,Email__c,BillingStreet, Type, RecordTypeId  FROM Account WHERE Name =: companyName];
            if (!accounts.isEmpty()) {
                return accounts[0];
            }
        }
        return null;
    }
    
    public static String convertSponsorship(String value) {
        if (String.isBlank(value)) 
            return null;
        
        if (value == 'Stationery') {
            return 'Stationary';
        } else if (value == 'SchoolFees') {
            return 'School Fees';
        }
        
        return value;
    }
    
    public static Account manageAccount(Account currentAccount, Contact currentContact, WSUtilsV2.WSV2 ws, String companyName) {
        String typeName = '';
        String recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Household Account').getRecordTypeId();
        if (String.isNotBlank(ws.CompanyName)) {
            typeName = 'Corporate';
            recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization').getRecordTypeId();
        }
        System.debug('manageAccount:' + recordTypeId);
        if (currentAccount == null && typeName == 'Corporate') {
            currentAccount = new Account(Name = companyName, npe01__One2OneContact__c = currentContact.id, RecordTypeId = recordTypeId);
            if (!String.isBlank(typeName)) {
                currentAccount.Type = typeName; 
            }
            if (!String.isBlank(ws.Phone)) {
                currentAccount.Phone = ws.Phone; 
            }
            if (!String.isBlank(ws.email)) {
                currentAccount.Email__c = ws.email;
            }
            if (!String.isBlank(ws.AddressLine1)) {
                currentAccount.BillingStreet = ws.AddressLine1;
            }
            System.debug('insert currentAccount:' + typeName + currentAccount);
            insert currentAccount;
        } else if (currentAccount != null){
            currentAccount.RecordTypeId = recordTypeId;
            if (currentAccount.npe01__One2OneContact__c == null) {
                currentAccount.npe01__One2OneContact__c = currentContact.id;
            }
            if (!String.isBlank(typeName)) {
                currentAccount.Type = typeName; 
            }
            if (!String.isBlank(ws.phone)) {
                currentAccount.Phone = ws.phone; 
            }
            if (!String.isBlank(ws.email)) {
                currentAccount.Email__c = ws.email;
            }
            if (!String.isBlank(ws.AddressLine1)) {
                currentAccount.BillingStreet = ws.AddressLine1;
            }
            update currentAccount;
            System.debug('update currentAccount:' + typeName + currentAccount);
        }
        return currentAccount;
    }
    
    public static Id getCampaignDefault() {
        List<Campaign> campaignDefault =  [SELECT Id FROM Campaign WHERE Name = 'F2F Campaign'];
        if (!campaignDefault.isEmpty()) {
            return campaignDefault[0].Id;
        }
        return NULL;
    }
}