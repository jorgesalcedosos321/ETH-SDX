public class Utils {
    public static String emailAddressOrgWide = 'info@sos-namibia.org';
    public static String emailTemplateThankYouEmail = 'Thank You Email';
    public static String emailTemplateWelcomeEmail = 'Welcome Email';
    public static String emailTemplateHappyBirthdayEmail = 'Happy Birthday Email';
    
    public static Integer amountRecordsInDPOTransactions = 50;
    public static Integer numberOfInstallmentsOnCommitedDonation = 12;
    public static String userBAToNotify = 'Andonovski Nikola';
    public static String dtFormat = 'yyyy-MM-dd';
    public static String[] userToNotifyJSONTransaction = new String[] { 'jorge.salcedo@sos-kd.org' };
        
	public static List<String> usersToNotifyWSErrors = new List<String> { 'jorge.salcedo@sos-kd.org','nikola.andonovski@sos-kd.org' };
           
    
    //SFESWCSD-91 SFESWCSD-86 SFESWCSD-85
    public static final String ANNIVERSARY_EMAIL_1 = 'ANNIVERSARY_EMAIL_1';
    public static final String BIRTHDAY_EMAIL = 'BIRTHDAY_EMAIL';
    public static final String CANCELLATION_PROCESS = 'CANCELLATION_PROCESS';
    public static final String END_OF_YEAR_REPORT_P = 'END_OF_YEAR_REPORT_P';
    public static final String LOYALTY_CALL_AFTER_6 = 'LOYALTY_CALL_AFTER_6';
    public static final String MID_YEAR_REPORT_PDF = 'MID_YEAR_REPORT_PDF';
    public static final String ONE_TIME_DONORS_LE = 'ONE_TIME_DONORS_LE';
    public static final String ONE_TIME_DONORS_TH = 'ONE_TIME_DONORS_TH';
    public static final String PAYMENT_CONFIRMATION = 'PAYMENT_CONFIRMATION';
    public static final String REMINDER_1 = 'REMINDER_1';
    public static final String REMINDER_2 = 'REMINDER_2';
    public static final String REMINDER_3 = 'REMINDER_3';
    public static final String THANK_YOU_EMAIL_AFTER_12 = 'THANK_YOU_EMAIL_AFTER_12';
    public static final String THANK_YOU_EMAIL_AFTER_2 = 'THANK_YOU_EMAIL_AFTER_2';
    public static final String THANK_YOU_EMAIL_AFTER_3 = 'THANK_YOU_EMAIL_AFTER_3';
    public static final String THANK_YOU_EMAIL_AFTER_4 = 'THANK_YOU_EMAIL_AFTER_4';
    public static final String THANK_YOU_EMAIL_AFTER_6 = 'THANK_YOU_EMAIL_AFTER_6';
    public static final String WELCOME_EMAIL_COMMUN = 'WELCOME_EMAIL_COMMUN';
    public static final String WELCOME_THE_NEW_DONO = 'WELCOME_THE_NEW_DONO';
    
    
    public static String lastDayOfMonth() {
        Date tomorrowDate = Date.today().addDays(1);
        if (tomorrowDate.day() == 1) {
	        return 'Last Day Of Month';
        } 
        return Date.today().day() + '';
    }
    
    
    public static Boolean isValidPicklistValue(String objectApiName, String fieldApiName, String valueToCheck) {
        // Describe the object and field
        // Get the Object Describe Result
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
        
        if (objType == null) {
            System.debug('Invalid object API name: ' + objectApiName);
            return false;
        }
        
        // Get the DescribeResult for the object
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        
        // Check if the field exists in the object
        if (!objDescribe.fields.getMap().containsKey(fieldApiName)) {
            System.debug('Field does not exist: ' + fieldApiName);
            return false;  // Exit early if the field doesn't exist
        }
        
        // If the field exists, get its describe result
        Schema.DescribeFieldResult fieldResult = objDescribe.fields.getMap().get(fieldApiName).getDescribe();        
        
        // Get all valid picklist values
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        
        // Check if the given value exists in the picklist
        for (Schema.PicklistEntry entry : picklistValues) {
            if (entry.getValue() == valueToCheck) {
                return true;
            }
        }
        return false;
    }
    
    public static String defaultPicklistValue(String objectApiName, String fieldApiName) {
        // Describe the object and field
        // Get the Object Describe Result
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
        
        if (objType == null) {
            System.debug('Invalid object API name: ' + objectApiName);
            return '';
        }
        
        // Get the DescribeResult for the object
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        
        // Check if the field exists in the object
        if (!objDescribe.fields.getMap().containsKey(fieldApiName)) {
            System.debug('Field does not exist: ' + fieldApiName);
            return '';  // Exit early if the field doesn't exist
        }
        
        // If the field exists, get its describe result
        Schema.DescribeFieldResult fieldResult = objDescribe.fields.getMap().get(fieldApiName).getDescribe();        
        
        // Get all valid picklist values
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
        
        // Check if the given value exists in the picklist
        for (Schema.PicklistEntry entry : picklistValues) {
            return entry.getValue();
        }
        return '';
    }
    
    
    public static Boolean isValidEmail(String email) {
        // Define the email regex pattern
        String emailPattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        
        // Check if the email matches the pattern
        return Pattern.matches(emailPattern, email);
    }
    
    public static Boolean isValidPhone(String phoneNumber) {
        // Regular Expression to match phone number formats (with optional country code)
        String phonePattern = '^(\\+\\d{1,3}[- ]?)?\\(?\\d{1,4}\\)?[- ]?\\d{1,4}[- ]?\\d{1,4}$';
        
        // Check if the phone number matches the regex pattern
        return Pattern.matches(phonePattern, phoneNumber);
    }
    
    public static Boolean isValidInteger(String input) {
        try {
            Integer.valueOf(input); // Try converting to an Integer
            return true;
        } catch (Exception e) {
            return false; // Not a valid integer
        }
    }
    
    public static Boolean isValidDecimal(String input, boolean skipEmptyOrZeroValue) {
        try {
            Decimal.valueOf(input); // Try converting to a Decimal
            return (Decimal.valueOf(input) > 0);
        } catch (Exception e) {
            if (skipEmptyOrZeroValue) {
                if (String.isBlank(input) || input == '0') {
                    return true;
                }
            }
            return false; // Not a valid Decimal
        }
    }
    
    
    public static Date getDateFromString(String dateEstablished) {
        String[] info = dateEstablished.split('-');
        if (info.size() == 3) {
            try {
                return Date.newInstance(Integer.valueOf(info[0]), Integer.valueOf(info[1]), Integer.valueOf(info[2]));    
            } catch(Exception ex) {
                System.debug('####getDateFromString: ' + dateEstablished);  
            }
            
        }
        return Date.today();
    }
    
    public static Datetime parseDatetime(String dateString) {
        if (dateString == null || dateString.length() != 14 || !dateString.isNumeric()) {
            throw new IllegalArgumentException('Invalid date string format. Expected yyyyMMddHHmmss');
        }
        
        try {
            Integer year = Integer.valueOf(dateString.substring(0, 4));
            Integer month = Integer.valueOf(dateString.substring(4, 6));
            Integer day = Integer.valueOf(dateString.substring(6, 8));
            Integer hour = Integer.valueOf(dateString.substring(8, 10));
            Integer minute = Integer.valueOf(dateString.substring(10, 12));
            Integer second = Integer.valueOf(dateString.substring(12, 14));
            
            return Datetime.newInstanceGmt(year, month, day, hour, minute, second);
        } catch (Exception e) {
            throw new IllegalArgumentException('Error parsing date: ' + e.getMessage());
        }
    }
    
    
    public static Id getUserToReportFalsePaymentStatus() {
        List<User> users = [SELECT Id FROM User WHERE NAME =: userBAToNotify];
        
        for (User currentUser : users) {
            return currentUser.Id;
        }
        return UserInfo.getUserId(); //'0059E00000AvOlHQAV'; ////Jelena sandbox
    }
    
    public static Map<String, String> getPickListValues(String objectName, String fieldName) {
        Map<String, String> result = new Map<String, String>();
        Schema.SObjectType objSobjectType = Schema.getGlobalDescribe().get(objectName) ;
        Schema.DescribeSObjectResult objDescribeSobject = objSobjectType.getDescribe() ;
        Map<String,Schema.SObjectField> fields = objDescribeSobject.fields.getMap() ;
        Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for( Schema.PicklistEntry pickListVal : ple){
            result.put(pickListVal.getLabel(),pickListVal.getValue());
        }
        return result;
    }
    
    public static String getScheduleCronTime(Integer minutes, Integer hours, Integer days, Integer months, Integer years, boolean runSeveralTimes){
        Datetime dateToday = Datetime.Now(); 
        String scheduleTime = '';
        
        if (years > 0) {
            dateToday = dateToday.addYears(years);			
        }
        
        if (months > 0) {
            dateToday = dateToday.addMonths(months);			
        }
        
        if (days > 0) {
            dateToday = dateToday.addDays(days);			
        }
        
        if (hours > 0) {
            dateToday = dateToday.addHours(hours);			
        }
        
        if (minutes > 0) {
            dateToday = dateToday.addMinutes(minutes);			
        }
        
        System.debug('Now:' + dateToday);
        scheduleTime = '? ' + ((years == 0 && runSeveralTimes) ? '?' : dateToday.Year() + '');
        system.debug('Year:' + dateToday.Year());
        scheduleTime = ((months == 0 && runSeveralTimes) ? '? ' : dateToday.Month() + ' ') + scheduleTime;
        system.debug('Months:' + dateToday.Month());
        scheduleTime = ((days == 0 && runSeveralTimes) ? '? ' : dateToday.Day() + ' ') + scheduleTime;
        system.debug('Days:' + dateToday.Day());
        scheduleTime = ((hours == 0 && runSeveralTimes) ? '? ' : dateToday.Hour() + ' ') + scheduleTime;
        system.debug('Hour:' + dateToday.Hour());
        scheduleTime = ((minutes == 0 && runSeveralTimes) ? '? ' : dateToday.Minute() + ' ') + scheduleTime;
        system.debug('Minute:' + dateToday.Minute());
        scheduleTime = '0 ' + scheduleTime;
        System.debug('scheduleTime:' + scheduleTime);
        return scheduleTime;
    }
    
    public static Map<String, String> replaceEmailTemplateParams(String orgPhone, String recipientName) {
        Map<String, String> params = new Map<String, String>();
        if (!String.isBlank(orgPhone))
            params.put('{{{Organization.Phone}}}', orgPhone);
        if (!String.isBlank(recipientName))
            params.put('{{{Recipient.Name}}}', recipientName);
        return params;
    }
    
    public static String getRandomNumber(Integer lengthNumber) {
        final integer STRING_LENGTH = lengthNumber;
        final double MIN = Math.pow(10,STRING_LENGTH -1); //Returns 100
        final double MAX = Math.pow(10,STRING_LENGTH) - 1; // Returns 999
        return String.valueOf(Math.Round(Math.Random() * (MAX-MIN) + MIN));
    }      
    
    public static String getTimestampFromAddingDays(Date myDate, Integer sumDays) {
        Time myTime = Time.newInstance(0, 0, 0, 0);
        myDate = myDate.addDays(sumDays);
        return (DateTime.newInstance(myDate, myTime).getTime() / 1000) + '';        
    }
    
    public static void sendEmailByParams(String subject, String body, Id whatId, Id targetObjectId, List<String> emails, String fileName, Blob blobFile) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if (targetObjectId != null)
            mail.setTargetObjectId(targetObjectId);
        
        if (whatId != null)
            mail.setWhatId(whatId);
        
        System.debug('#### sendEmailByParams 0:' + emails);
        mail.setToAddresses(emails);
        mail.setUseSignature(true);
        mail.setBccSender(false);
        mail.setSaveAsActivity(true);   
        
        Id orgWideEmailAddressId = getOrgWideEmailAddress();
        if (orgWideEmailAddressId <> null) {             
            mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
        }        
        
        if (blobFile != NULL) {
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName(fileName);
            efa.setBody(blobFile);
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] {efa});
        }
        
        mail.setHtmlBody(body);
        mail.setSubject(subject);
        
        try {
            System.debug('#### sendEmailByParams 1');
            Messaging.SendEmailResult [] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
            System.debug('#### sendEmailByParams 2');
        } catch (Exception e) {
            System.debug('#### sendEmailByParams error ' + e.getMessage());
        }
    }
    
    public static void sendEmailByTemplate(String emailTemplateName, Map<String, String> paramsToReplace, Id whatId,  Id targetObjectId, List<String> emails) {
        List<EmailTemplate> templates = [Select Id, Subject, HtmlValue, body from EmailTemplate where Name =: emailTemplateName];
        
        String subject = '';
        String body = '';
        
        if (templates.size() > 0) {
            body = templates[0].HtmlValue == null ? templates[0].Body : templates[0].HtmlValue;
            subject = templates[0].Subject;
        } else {
            System.debug('####sendEmailByTemplate template not exists');
            return;
        }
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        if (targetObjectId != null)
            mail.setTargetObjectId(targetObjectId);
        
        if (whatId != null)
            mail.setWhatId(whatId);
        
        System.debug('#### sendEmailByParams 0:' + emails);
        mail.setToAddresses(emails);
        mail.setUseSignature(false);
        mail.setBccSender(false);
        mail.setSaveAsActivity(true);   
        
        Id orgWideEmailAddressId = getOrgWideEmailAddress();
        if (orgWideEmailAddressId <> null) {             
            mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
        }
        
        for (String param : paramsToReplace.keySet()) {
            body = body.replace(param, paramsToReplace.get(param));
        } 
        
        mail.setHtmlBody(body);
        mail.setSubject(subject);        
        
        try {
            System.debug('#### sendEmailByTemplate 1: ' + mail);
            Messaging.SendEmailResult [] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
            System.debug('#### sendEmailByTemplate 2');
        } catch (Exception e) {
            System.debug('####sendEmailByTemplate error ' + e.getMessage());
        }
    }
    
    public static Id getOrgWideEmailAddress(){
        OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where Address =: emailAddressOrgWide ];
        if ( owea.size() > 0 ) {    
            return owea.get(0).Id;
        }
        return null;
    }
    
    public static JSONGenerator setJSONGenerator(JSONGenerator gen, boolean isSuccess, String errorMessage, String recordId, String description, String recordIdField) {
        //gen.writeStartArray();
        //gen.writeStartObject();
        //gen.writeFieldName('SalesforceFeedback');
        gen.writeStartObject();
        if (String.isNotBlank(errorMessage)) {
            gen.writeStringField('error',  errorMessage);    
            gen.writeStringField('success',  'false');    
            gen.writeStringField('recordId',  '');    
        } else {
            gen.writeStringField('error',  '');    
            gen.writeStringField('success',  'true');    
            if (!String.isBlank(description)) {         
                gen.writeStringField('recordId',  description + ' ' + (String.isNotBlank(recordIdField) ? recordIdField + ': ' : 'DonationID: ') + recordId);   
            } else {                
                gen.writeStringField('recordId',  (String.isNotBlank(recordIdField) ? recordIdField + ': ' : 'DonationID: ') + recordId);
            }
        }
        gen.writeEndObject();
        //gen.writeEndObject();
        //gen.writeEndArray();
        return gen;
    }
    
    public static JSONGenerator setJSONGeneratorSimple(JSONGenerator gen, boolean isSuccess, String message) {
        gen.writeStartObject();
        gen.writeStringField('error',  (!isSuccess ? message : ''));    
        gen.writeStringField('success',  isSuccess + '');    
        gen.writeStringField('recordId',  (isSuccess ? message : ''));    
        gen.writeEndObject();
        return gen;
    }
    
    public static Task createNotification(String subject, String taskSubtype, Id whoId, Id whatId, Date activityDate, Date reminderDate, Id userOwnerId, String status, String priority) {
        Task t1 = new Task();
        t1.OwnerId = userOwnerId;
        if(Test.isRunningTest()){
            t1.OwnerId = UserInfo.getUserId();
        }
        
        t1.Subject = subject;//;
        
        if (whoId <> null) {
            t1.WhoId = whoId; //rd.npe03__Contact__c;
        }
        
        if (whatId <> null) {
            t1.WhatId = whatId; //rd.Id;
        }
        
        t1.Type = (taskSubtype == null ? 'Call' : taskSubtype);
        t1.ActivityDate = (activityDate == null) ? System.today().addDays(3) : activityDate;
        t1.ReminderDateTime = (reminderDate == null) ? System.now() : reminderDate;
        t1.IsReminderSet = true;
        
        t1.Status = String.isNotBlank(status) ? status : 'In Progress';
        t1.Priority = String.isNotBlank(status) ? priority : 'Normal';
        return t1;
    }
    
    public static Boolean isSandbox(){
        if (Url.getOrgDomainURL().toString().contains('sandbox')) return true;
        else return false;
    }    
    
    public static void printQueryDebug(String queryToExecute) {
        Integer maxLength = 400;
        if (queryToExecute.length() > maxLength) {
            boolean cut = true;
            Integer round = 0;
            while(cut) {
                Integer maxPosition = queryToExecute.length() < ((round * maxLength) + maxLength) ? queryToExecute.length() : (round * maxLength) + maxLength;
                String subquery = queryToExecute.substring(round * maxLength, maxPosition);
                System.debug('####queryToExecute subquery ' + round + ':' + subquery);                          
                round++;
                if (round * maxLength >= queryToExecute.length()) {
                    cut = false;
                }
            }            
        } else {
            System.debug('####queryToExecute:' + queryToExecute);        
        }
    }
    
    public static String getBaseUrlForFiles() {
        return URL.getOrgDomainURL().toExternalForm().replace('.my.salesforce.', '.file.force.');
    }
    
    //How to call: String urlLink = getDownloadableUrl(oppPay.Id);
    public static String getDownloadableUrl(Id recordId) {
        // Step 1: Find the conversation record
        List<ContentDocumentLink> condoc = [SELECT ContentDocument.Id, ContentDocument.Title, ContentDocument.FileType FROM ContentDocumentLink WHERE LinkedEntityId =: recordId ORDER BY SystemModstamp DESC];
        String baseUrl = getBaseUrlForFiles();
        if (!condoc.isEmpty()) {
            // Step 2: Check if a ContentDistribution record already exists for the ContentDocumentId
            Id cdId = condoc[0].ContentDocument.Id;
            List<ContentDistribution> existingDistribution = [SELECT Id, ContentDownloadUrl FROM ContentDistribution WHERE ContentDocumentId =: cdId];
            System.debug('###getDownloadableUrl cdId:' + cdId);
            System.debug('###getDownloadableUrl existingDistribution:' + existingDistribution);
            if (!existingDistribution.isEmpty()) {
                System.debug('###getDownloadableUrl found link:');
                // If the ContentDistribution record exists, return the existing downloadable URL
                System.debug('###getDownloadableUrl existingDistribution[0].ContentDownloadUrl:' + existingDistribution[0].ContentDownloadUrl);
                String urlToSend = existingDistribution[0].ContentDownloadUrl.replace(baseUrl, '');
                return urlToSend.removeStart('/');
            } else {
                System.debug('###getDownloadableUrl not found link:');                
                ContentVersion cv = [SELECT Id from ContentVersion WHERE ContentDocumentId =: cdId];
                System.debug('###getDownloadableUrl cv:' + cv);
                ContentDistribution newDistribution = new ContentDistribution();
                newDistribution.Name = 'Test';
                newDistribution.ContentVersionId = cv.id;
                newDistribution.PreferencesAllowViewInBrowser= true;
                newDistribution.PreferencesLinkLatestVersion=true;
                newDistribution.PreferencesNotifyOnVisit=false;
                newDistribution.PreferencesPasswordRequired=false;
                newDistribution.PreferencesAllowOriginalDownload= true;
                insert newDistribution;                
                
                // Fetch the newly created ContentDistribution record to get the downloadable URL
                newDistribution = [SELECT Id, ContentDownloadUrl FROM ContentDistribution WHERE Id =: newDistribution.Id LIMIT 1];
                System.debug('###getDownloadableUrl newDistribution:' + newDistribution);
                // Return the newly created public downloadable URL
                String urlToSend = newDistribution.ContentDownloadUrl.replace(baseUrl, '');
                return urlToSend.removeStart('/');
            }    
        } 
        return null;
    }
    
    private static final Map<String, String> countryAlpha2Map = new Map<String, String>{
        'afghanistan' => 'AF',
            'albania' => 'AL',
            'algeria' => 'DZ',
            'andorra' => 'AD',
            'angola' => 'AO',
            'antigua and barbuda' => 'AG',
            'argentina' => 'AR',
            'armenia' => 'AM',
            'australia' => 'AU',
            'austria' => 'AT',
            'azerbaijan' => 'AZ',
            'bahamas' => 'BS',
            'bahrain' => 'BH',
            'bangladesh' => 'BD',
            'barbados' => 'BB',
            'belarus' => 'BY',
            'belgium' => 'BE',
            'belize' => 'BZ',
            'benin' => 'BJ',
            'bhutan' => 'BT',
            'bolivia' => 'BO',
            'bosnia and herzegovina' => 'BA',
            'botswana' => 'BW',
            'brazil' => 'BR',
            'brunei' => 'BN',
            'bulgaria' => 'BG',
            'burkina faso' => 'BF',
            'burundi' => 'BI',
            'cambodia' => 'KH',
            'cameroon' => 'CM',
            'canada' => 'CA',
            'cape verde' => 'CV',
            'central african republic' => 'CF',
            'chad' => 'TD',
            'chile' => 'CL',
            'china' => 'CN',
            'colombia' => 'CO',
            'comoros' => 'KM',
            'congo (brazzaville)' => 'CG',
            'congo (kinshasa)' => 'CD',
            'costa rica' => 'CR',
            'croatia' => 'HR',
            'cuba' => 'CU',
            'cyprus' => 'CY',
            'czech republic' => 'CZ',
            'denmark' => 'DK',
            'djibouti' => 'DJ',
            'dominica' => 'DM',
            'dominican republic' => 'DO',
            'ecuador' => 'EC',
            'egypt' => 'EG',
            'el salvador' => 'SV',
            'equatorial guinea' => 'GQ',
            'eritrea' => 'ER',
            'estonia' => 'EE',
            'eswatini' => 'SZ',
            'ethiopia' => 'ET',
            'fiji' => 'FJ',
            'finland' => 'FI',
            'france' => 'FR',
            'gabon' => 'GA',
            'gambia' => 'GM',
            'georgia' => 'GE',
            'germany' => 'DE',
            'ghana' => 'GH',
            'greece' => 'GR',
            'grenada' => 'GD',
            'guatemala' => 'GT',
            'guinea' => 'GN',
            'guinea-bissau' => 'GW',
            'guyana' => 'GY',
            'haiti' => 'HT',
            'honduras' => 'HN',
            'hungary' => 'HU',
            'iceland' => 'IS',
            'india' => 'IN',
            'indonesia' => 'ID',
            'iran' => 'IR',
            'iraq' => 'IQ',
            'ireland' => 'IE',
            'israel' => 'IL',
            'italy' => 'IT',
            'jamaica' => 'JM',
            'japan' => 'JP',
            'jordan' => 'JO',
            'kazakhstan' => 'KZ',
            'kenya' => 'KE',
            'kiribati' => 'KI',
            'korea, north' => 'KP',
            'korea, south' => 'KR',
            'kosovo' => 'XK',
            'kuwait' => 'KW',
            'kyrgyzstan' => 'KG',
            'laos' => 'LA',
            'latvia' => 'LV',
            'lebanon' => 'LB',
            'lesotho' => 'LS',
            'liberia' => 'LR',
            'libya' => 'LY',
            'liechtenstein' => 'LI',
            'lithuania' => 'LT',
            'luxembourg' => 'LU',
            'madagascar' => 'MG',
            'malawi' => 'MW',
            'malaysia' => 'MY',
            'maldives' => 'MV',
            'mali' => 'ML',
            'malta' => 'MT',
            'marshall islands' => 'MH',
            'mauritania' => 'MR',
            'mauritius' => 'MU',
            'mexico' => 'MX',
            'micronesia' => 'FM',
            'moldova' => 'MD',
            'monaco' => 'MC',
            'mongolia' => 'MN',
            'montenegro' => 'ME',
            'morocco' => 'MA',
            'mozambique' => 'MZ',
            'myanmar' => 'MM',
            'namibia' => 'NA',
            'nauru' => 'NR',
            'nepal' => 'NP',
            'netherlands' => 'NL',
            'new zealand' => 'NZ',
            'nicaragua' => 'NI',
            'niger' => 'NE',
            'nigeria' => 'NG',
            'north macedonia' => 'MK',
            'norway' => 'NO',
            'oman' => 'OM',
            'pakistan' => 'PK',
            'palau' => 'PW',
            'palestine' => 'PS',
            'panama' => 'PA',
            'papua new guinea' => 'PG',
            'paraguay' => 'PY',
            'peru' => 'PE',
            'philippines' => 'PH',
            'poland' => 'PL',
            'portugal' => 'PT',
            'qatar' => 'QA',
            'romania' => 'RO',
            'russia' => 'RU',
            'rwanda' => 'RW',
            'saint kitts and nevis' => 'KN',
            'saint lucia' => 'LC',
            'saint vincent and the grenadines' => 'VC',
            'samoa' => 'WS',
            'san marino' => 'SM',
            'sao tome and principe' => 'ST',
            'saudi arabia' => 'SA',
            'senegal' => 'SN',
            'serbia' => 'RS',
            'seychelles' => 'SC',
            'sierra leone' => 'SL',
            'singapore' => 'SG',
            'slovakia' => 'SK',
            'slovenia' => 'SI',
            'solomon islands' => 'SB',
            'somalia' => 'SO',
            'south africa' => 'ZA',
            'south sudan' => 'SS',
            'spain' => 'ES',
            'sri lanka' => 'LK',
            'sudan' => 'SD',
            'suriname' => 'SR',
            'sweden' => 'SE',
            'switzerland' => 'CH',
            'syria' => 'SY',
            'taiwan' => 'TW',
            'tajikistan' => 'TJ',
            'tanzania' => 'TZ',
            'thailand' => 'TH',
            'timor-leste' => 'TL',
            'togo' => 'TG',
            'tonga' => 'TO',
            'trinidad and tobago' => 'TT',
            'tunisia' => 'TN',
            'turkey' => 'TR',
            'turkmenistan' => 'TM',
            'tuvalu' => 'TV',
            'uganda' => 'UG',
            'ukraine' => 'UA',
            'united arab emirates' => 'AE',
            'united kingdom' => 'GB',
            'united states' => 'US',
            'uruguay' => 'UY',
            'uzbekistan' => 'UZ',
            'vanuatu' => 'VU',
            'vatican city' => 'VA',
            'venezuela' => 'VE',
            'vietnam' => 'VN',
            'yemen' => 'YE',
            'zambia' => 'ZM',
            'zimbabwe' => 'ZW'
            };
                
                public static String getAlpha2Code(String countryName) {
                    if (String.isBlank(countryName)) return null;
                    String key = countryName.trim().toLowerCase();
                    return countryAlpha2Map.get(key);
                }
    
    public static Log__c logJsons(String descr, String typeR, boolean error) {
        Log__c newLog = new Log__c();
        newLog.Description__c = descr;
        newLog.Error__c = error;
        newLog.Type__c = typeR;
        return newLog; 
    }
    
    
    
    public static Messaging.SingleEmailMessage addParamsToEmails(Id contactId, Id opportunityId, String email, Id orgWideEmailAddressId, String body, String subject) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        if (contactId != null)
            mail.setTargetObjectId(contactId);
        
        if (opportunityId != null)
            mail.setWhatId(opportunityId);
        
        mail.setToAddresses(new List<String> {email});
        mail.setUseSignature(false);
        mail.setBccSender(false);
        mail.setSaveAsActivity(true);   
        
        if (orgWideEmailAddressId <> null) {             
            mail.setOrgWideEmailAddressId(orgWideEmailAddressId);
        }
        
        mail.setHtmlBody(body);
        mail.setSubject(subject); 
        return mail;
    }
    
    public static void sendEmails(Messaging.SingleEmailMessage[] mails) {
        try {
            System.debug('####sendEmailNotification email 1: ' + mails);
            Messaging.SendEmailResult [] r = Messaging.sendEmail(mails, false);
            System.debug('####sendEmailNotification email 2');
        } catch (Exception e) {
            System.debug('####sendEmailNotification email error ' + e.getMessage());
        }
    }
    
    public static EmailTemplate getEmailTemplateByName(List<EmailTemplate> ets, String name) {
        for (EmailTemplate et : ets) {
            if (et.Name == name) {
                return et;
            }
        }
        return NULL;
    }
}