/*String cronTime = Utils.getScheduleCronTime(1, 0, 0, 0, 0, false);
String startTimestamp = Utils.getTimestampFromAddingDays(Date.today(), -1);
String endTimestamp = Utils.getTimestampFromAddingDays(Date.today(), 0);
List<String> rangeDates = new List<String> {startTimestamp, endTimestamp};
DPOReadTransactionBatch btch = new DPOReadTransactionBatch(rangeDates);
btch.numberOfRecords = 10; 
System.schedule('DPOReadTransactionBatch:' + Utils.getRandomNumber(7) + ' / cronTime: ' + cronTime, cronTime, btch);
System.schedule('DPOReadTransactionBatch', new DPOReadTransactionBatch());*/
global class DPOReadTransactionBatch implements Database.Stateful, Schedulable, Database.Batchable<sObject>, Database.AllowsCallouts{
    global DPOHandler dpo = new DPOHandler();
    global List<String> logs = new List<String>();            
    global Map<Id, String> paidPaymentIds = new Map<Id, String>();            
	global Map<Id, String> errorPaidPaymentIds = new Map<Id, String>();            
			
    public DPOReadTransactionBatch(){
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(this);
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        Date todayDate = Date.today();
        Date yesterdayDate = todayDate.addDays(-1);
        Date lastYesterdayDate = todayDate.addDays(-2);
		System.debug('###DPOReadTransactionBatch todayDate:' + todayDate);
        System.debug('###DPOReadTransactionBatch yesterdayDate:' + yesterdayDate);
        System.debug('###DPOReadTransactionBatch lastYesterdayDate:' + lastYesterdayDate);
        return Database.getQueryLocator([SELECT Id, npe01__Payment_Date__c, Transaction_Ref__c, npe01__Opportunity__r.npe03__Recurring_Donation__r.transaction_ID__c, 
                                         			npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.Firstname, 
                                         			npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.Lastname, 
                                         			npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.Phone, 
                                         			npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.Email,
                                         			npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.MailingCountry,
                                         			npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.MailingPostalCode,
                                         			npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.MailingCity,
                                         			npe01__Payment_Amount__c, npe01__Opportunity__r.Currency__c
                                         FROM npe01__OppPayment__c 
                                         WHERE ((npe01__Scheduled_Date__c =: todayDate AND Attempts__c = 0) OR 
                                                (npe01__Scheduled_Date__c =: yesterdayDate AND Attempts__c = 1) OR
                                                (npe01__Scheduled_Date__c =: lastYesterdayDate AND Attempts__c = 2)) AND 
                                         npe01__Paid__c = FALSE AND 
                                         Attempts__c < 3 AND 
                                         (Transaction_Ref__c != '' OR 
                                          npe01__Opportunity__r.npe03__Recurring_Donation__r.transaction_ID__c != '') AND                                         
                                         npe01__Opportunity__r.npe03__Recurring_Donation__r.npsp__Status__c = 'Active']);
    }
    
    //https://justcall.io/hub/number-format/namibia/ code 264 + 8 digits extra
    //Example: NA(+264)812102708 
    global String cleanPhoneNumberCharacters(String phone) {
        if (String.isNotBlank(phone)) { 
            Set<String> invalidCharacters = new Set<String> {'(', ')', '+', 'N', 'A', ' '};
                for (String invalidCharacter : invalidCharacters) {
                    phone = phone.replace(invalidCharacter,'');
                }
            return phone;
        }
        return '';
    }
    
    global void execute(Database.BatchableContext BC, List<sObject> scope) {
        System.debug('####DPOReadTransactionBatch: execute scope.size:' + scope);
        logs = new List<String>();
        paidPaymentIds = new Map<Id, String>();
		errorPaidPaymentIds = new Map<Id, String>();  
        
        if (scope.size() > 0) {
            DPOUtils.setDPOCredentials();
            Map<String, String> resultCodes =  DPOUtils.getResultCodes();
            String urlRedirect = Url.getOrgDomainURL().toString() + '/services/apexrest/InsertDPOPaymentResponse';
			String todayFormat = DPOUtils.getFormattedDateTime(Datetime.Now());
                
            for (sObject pay : scope) {
                npe01__OppPayment__c payObj = (npe01__OppPayment__c)pay;
                System.debug('####DPOReadTransactionBatch: execute payObj:' + payObj);
                Id paymentId = payObj.Id;
                Date paymentDate = payObj.npe01__Payment_Date__c; 
                String paymentTransactionRef = payObj.Transaction_Ref__c;
                //String donationTransactionId = payObj.npe01__Opportunity__r.npe03__Recurring_Donation__r.transaction_ID__c;
                String transactionId = payObj.npe01__Opportunity__r.npe03__Recurring_Donation__r.transaction_ID__c; 
                String contactFirstname = payObj.npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.Firstname; 
                String contactLastname = payObj.npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.Lastname; 
                String contactPhone = cleanPhoneNumberCharacters(payObj.npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.Phone); 
				String contactEmail = payObj.npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.Email;
                String contactCountry = payObj.npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.MailingCountry;
                String contactPostalCode = payObj.npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.MailingPostalCode;
                String contactCity = payObj.npe01__Opportunity__r.npe03__Recurring_Donation__r.npe03__Contact__r.MailingCity;
                
                String subscriptionToken = '';
                String CompanyRef = '';
                contactCountry = Utils.getAlpha2Code(contactCountry);
                Decimal paymentAmount = payObj.npe01__Payment_Amount__c;
                String currencyAmount = payObj.npe01__Opportunity__r.Currency__c;
                if (String.isBlank(currencyAmount)) {
                    currencyAmount = 'ETH';
                }
                
                //STARTING: 1st Step: Creating new Token for subsequence payment
                DPOClasses.TransactionData transactionData = new DPOClasses.TransactionData(paymentAmount, currencyAmount, 0,
				CompanyRef,urlRedirect,'',0,15,'hours',contactFirstname,contactLastname,contactPostalCode,contactCity,contactCountry,contactEmail);
                
                List<DPOClasses.Service> services = new List<DPOClasses.Service>();
                services.add(new DPOClasses.Service(DPOUtils.serviceType, 'Subsequence Payment', todayFormat));
                
                String createTokenRequest = DPOUtils.setCreateTokenRequest(transactionData, services);   
                System.debug('###createTokenRequest 1: ' + createTokenRequest);
                Object objResponse = dpo.getResponseByXML(createTokenRequest, DPOClasses.createTokenResponse.class.getName());
                System.debug('###createTokenRequest 2 objResponse: ' + objResponse);
                DPOClasses.createTokenResponse objCreateToken = (DPOClasses.createTokenResponse)objResponse;
                System.debug('###createTokenRequest 3 objCreateToken: ' + objCreateToken);
                Boolean existsResultCode = false;
                String extraInfoResult = '';
                String result = '';
                
                if (objCreateToken.Result == '000') {                    
                    String transactionToken = objCreateToken.TransToken;
                    //2nd Step: Get subscription token to proceed with 3rd step
                    subscriptionToken = getSubscriptionToken(contactEmail, contactPhone, resultCodes);
                    
                    if (subscriptionToken.contains('subscriptionTokenRequest Error')) {
                        logs.add(subscriptionToken);
                    } else {                        
                        System.debug('###createTokenRequest 4 subscriptionToken: ' + subscriptionToken);
                        
                        //STARTING: 3rd Step: Charging recurring token request
                        String chargeTokenRecurrentRequest = DPOUtils.sendChargeTokenRecurrentRequest(transactionToken, subscriptionToken);      
                        System.debug('###createTokenRequest 5 chargeTokenRecurrentRequest: ' + chargeTokenRecurrentRequest);                    
                        objResponse = dpo.getResponseByXML(chargeTokenRecurrentRequest, DPOClasses.chargeTokenRecurrentResponse.class.getName());
                        System.debug('###createTokenRequest 6 objResponse: ' + objResponse);
                        DPOClasses.chargeTokenRecurrentResponse objChargeTokenRecurrent = (DPOClasses.chargeTokenRecurrentResponse)objResponse;
                        System.debug('###createTokenRequest 7 objChargeTokenRecurrent: ' + objChargeTokenRecurrent);
                        
                        result = objChargeTokenRecurrent.Result;
                        existsResultCode = resultCodes.containsKey(result);
                        System.debug('####DPOReadTransactionBatch: execute result:' + result);
                        System.debug('####DPOReadTransactionBatch: execute existsResultCode:' + existsResultCode);
                        
                        if (result == '000') {
                            //Starting: 4th Step: Verifying token request (if it's already paid)
                            String verifyTokenRequest = DPOUtils.verifyTokenRequest(transactionToken);   
                            System.debug('###createTokenRequest 8a verifyTokenRequest: ' + verifyTokenRequest);
                            Object objResponseVT = dpo.getResponseByXML(verifyTokenRequest, DPOClasses.verifyTokenResponse.class.getName());
                            System.debug('###createTokenRequest 8a objResponseVT: ' + objResponseVT);
                            DPOClasses.verifyTokenResponse objVerifyToken = (DPOClasses.verifyTokenResponse)objResponseVT;
                            System.debug('###createTokenRequest 8a objVerifyToken: ' + objVerifyToken);
                            
                            if (objVerifyToken.Result != '000') {
                                System.debug('###createTokenRequest 8a objVerifyToken Result Unpaid: ' + objVerifyToken.ResultExplanation);                            
                                logs.add('verifyTokenRequest Error:' + verifyTokenRequest + ' / result: ' + objVerifyToken.Result + ' /  objVerifyToken.ResultExplanation: ' +  objVerifyToken.ResultExplanation);
                                //Utils.logJsons('verifyTokenRequest:' + verifyTokenRequest + ' / result: ' + objVerifyToken.Result + ' /  objVerifyToken.ResultExplanation: ' +  objVerifyToken.ResultExplanation, 'Log DPO Transaction', true);
                                result = objVerifyToken.Result;
                        		existsResultCode = resultCodes.containsKey(result);
                                extraInfoResult = (existsResultCode ? ' (' + resultCodes.get(result) + ')' : '');
                                errorPaidPaymentIds.put(payObj.Id, 'Code: ' + result + extraInfoResult + ' / Message: ' + objVerifyToken.ResultExplanation);
                            } else {
                                System.debug('###createTokenRequest 8a objVerifyToken Result Paid: ' + objVerifyToken.ResultExplanation);                            
                                paidPaymentIds.put(payObj.Id, transactionToken);
                            }
                            //Ending: 4th Step: Verifying token request (if it's already paid)                        
                        } else {
                            //'Log DPO Transaction'
                            result = objChargeTokenRecurrent.Result;
                       		existsResultCode = resultCodes.containsKey(result);                                
                            extraInfoResult = (existsResultCode ? ' (' + resultCodes.get(result) + ')' : '');
                            logs.add('chargeTokenRecurrentRequest Error:' + chargeTokenRecurrentRequest + ' / result: ' + result + ' /  objChargeTokenRecurrent.ResultExplanation: ' +  objChargeTokenRecurrent.ResultExplanation);
                            errorPaidPaymentIds.put(payObj.Id, 'Code: ' + result + extraInfoResult + ' / Message: ' + objChargeTokenRecurrent.ResultExplanation);
                        }  
                    }
                    //ENDING: 3rd Step: Charging recurring token request
                } else {
                    result = objCreateToken.Result;
                    existsResultCode = resultCodes.containsKey(result);                                
                    extraInfoResult = (existsResultCode ? ' (' + resultCodes.get(result) + ')' : '');
                    logs.add('createTokenRequest Error:' + createTokenRequest + ' / result: ' + objCreateToken.Result + ' /  objCreateToken.ResultExplanation: ' +  objCreateToken.ResultExplanation);
                    errorPaidPaymentIds.put(payObj.Id, 'Code: ' + result + extraInfoResult + ' / Message: ' + objCreateToken.ResultExplanation);
                }
                //ENDING: 1st Step              
            }            
        }     
        System.debug('####DPOReadTransactionBatch: paidPaymentIds execute :' + paidPaymentIds);
        System.debug('####DPOReadTransactionBatch: errorPaidPaymentIds execute :' + errorPaidPaymentIds);        
    }
    
    global void updatePayments(Map<Id, String> Ids, boolean paid) {
        List<Log__c> detailedLogs = new List<Log__c>();
        
        if (Ids.size() > 0) {
            Set<Id> oppsToDeclineId = new Set<Id>();
            List<npe01__OppPayment__c> oppsToUpdate = [SELECT Id, npe01__Opportunity__c, Transaction_Error_Message__c, Attempts__c, npe01__Payment_Date__c, npe01__Paid__c FROM npe01__OppPayment__c WHERE Id IN : Ids.keySet()];
            
            for (npe01__OppPayment__c oppToUpdate : oppsToUpdate) {
                if (Ids.containsKey(oppToUpdate.Id)) {
                    oppToUpdate.npe01__Payment_Date__c = (paid ? Date.Today() : NULL);
                    oppToUpdate.npe01__Paid__c = paid; 
                    oppToUpdate.Attempts__c = oppToUpdate.Attempts__c + 1;
                    oppToUpdate.Transaction_Error_Message__c = Ids.get(oppToUpdate.Id);
                    
                    if (oppToUpdate.Attempts__c == 3 && !paid) {
                        oppsToDeclineId.add(oppToUpdate.npe01__Opportunity__c);
                    }
                    detailedLogs.add(Utils.logJsons((paid ? 'paid' : 'unpaid') + 'PaymentDetails Id:' + oppToUpdate.npe01__Payment_Date__c + ' / Date: ' + oppToUpdate.npe01__Payment_Date__c + ' / Paid: ' + oppToUpdate.npe01__Paid__c + ' / Attempts: ' + oppToUpdate.Attempts__c + ' / Errors: ' + oppToUpdate.Transaction_Error_Message__c, 'Log Update Payment Transaction', oppToUpdate.npe01__Paid__c));
                }
            }
            UPDATE oppsToUpdate;
            
            List<Opportunity> oppsToDecline = new List<Opportunity>();
            for (Id oppToDecline : oppsToDeclineId) {
                oppsToDecline.add(new Opportunity(Id = oppToDecline, StageName = 'Declined'));
            }
            
            if (!oppsToDecline.isEmpty()) {
                UPDATE oppsToDecline;
            }
        }
        
        if (!detailedLogs.isEmpty()) {
            INSERT detailedLogs;
        }
    }
    
    global void insertErrors(List<String> errors) {
        List<Log__c> logs = new List<Log__c>();
        for (String error : errors) {
            logs.add(Utils.logJsons(error, 'Log DPO Transaction', true));
        }
        INSERT logs;
        
        String body = JSON.serialize(logs, true);
        List<String> emails = new List<String> {'jorge.salcedo@sos-kd.org', 'Nikola.Andonovski@sos-kd.org' };        
        Utils.sendEmailByParams('Errors Logs from DPO Transactions', 'Error description is: ' + body, NULL, NULL, emails, NULL, NULL);
    }
    
    global String getSubscriptionToken(String contactEmail, String contactPhone, Map<String, String> resultCodes) {
        String subscriptionToken = '';
        String error = '';
        if (String.isNotBlank(contactEmail)) {                	
            String subscriptionTokenRequest = DPOUtils.setGetSubscriptionTokenRequest('1', contactEmail);                    
            Object response = dpo.getResponseByXML(subscriptionTokenRequest, DPOClasses.getSubscriptionTokenResponse.class.getName());
            System.debug('####DPOReadTransactionBatch: execute contactEmail response:' + response);
            if (response != NULL && response instanceof DPOClasses.getSubscriptionTokenResponse) {
                DPOClasses.getSubscriptionTokenResponse objResponse = (DPOClasses.getSubscriptionTokenResponse)response;
                if (objResponse.Result == '000') {
                    subscriptionToken = objResponse.SubscriptionToken;
                } else {
                    Boolean existsResultCode = resultCodes.containsKey(objResponse.result);
                    String extraInfoResult = (existsResultCode ? ' (' + resultCodes.get(objResponse.Result) + ')' : '');
                    System.debug('###DPOReadTransactionBatch: Error in getting contact by EmailCode: ' + objResponse.Result + extraInfoResult + ' / Message: ' + objResponse.ResultExplanation);
                    error = 'subscriptionTokenRequest Error:' + subscriptionTokenRequest + ' / result: ' + objResponse.Result + ' /  objCreateToken.ResultExplanation: ' +  objResponse.ResultExplanation;
                } 
            }
        }
        
        System.debug('####DPOReadTransactionBatch: execute contactPhone:' + contactPhone);
        System.debug('####DPOReadTransactionBatch: execute subscriptionToken:' + subscriptionToken);
        
        //Call subscriptionTokenRequests 2nd attempt by phone in case email or subscriptionToken is empty
        if (String.isNotBlank(contactPhone) && String.isBlank(subscriptionToken)) {
            String subscriptionTokenRequest = DPOUtils.setGetSubscriptionTokenRequest('2', contactPhone);
            Object response = dpo.getResponseByXML(subscriptionTokenRequest, DPOClasses.getSubscriptionTokenResponse.class.getName());
            System.debug('####DPOReadTransactionBatch: execute contactPhone response:' + response);
            if (response != NULL && response instanceof DPOClasses.getSubscriptionTokenResponse) {
                DPOClasses.getSubscriptionTokenResponse objResponse = (DPOClasses.getSubscriptionTokenResponse)response;
                if (objResponse.Result == '000') {
                    subscriptionToken = objResponse.SubscriptionToken;
                } else {
                    Boolean existsResultCode = resultCodes.containsKey(objResponse.result);
                    String extraInfoResult = (existsResultCode ? ' (' + resultCodes.get(objResponse.Result) + ')' : '');
                    //System.debug('###DPOReadTransactionBatch: Error in getting contact by PhoneCode: ' + objResponse.Result + extraInfoResult + ' / Message: ' + objResponse.ResultExplanation);
                    error = 'subscriptionTokenRequest Error:' + subscriptionTokenRequest + ' / result: ' + objResponse.Result + ' /  objCreateToken.ResultExplanation: ' +  objResponse.ResultExplanation;
                }                        
            } 
        }
        return String.isBlank(subscriptionToken) ? error : subscriptionToken;
    }
   
    global void finish(Database.BatchableContext BC) {
        System.debug('####DPOReadTransactionBatch: finish');
        
        System.debug('####DPOReadTransactionBatch: paidPaymentIds finish :' + paidPaymentIds);
        updatePayments(paidPaymentIds, true);
        
        System.debug('####DPOReadTransactionBatch: errorPaidPaymentIds finish :' + errorPaidPaymentIds);
        updatePayments(errorPaidPaymentIds, false);
        
        insertErrors(logs);
        
		string importJobId = BC.getJobId(); 
        system.debug('finish: ' + importJobId);
        System.abortJob(importJobId);
    }
}