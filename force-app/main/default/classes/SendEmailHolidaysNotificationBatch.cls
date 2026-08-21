//System.schedule('SendEmailHolidaysNotificationBatch Birthday', '0 0 10 * * ?', new SendEmailHolidaysNotificationBatch(true));
//System.schedule('SendEmailHolidaysNotificationBatch Holidays', '0 0 10 * * ?', new SendEmailHolidaysNotificationBatch(false));
global class SendEmailHolidaysNotificationBatch implements Database.Batchable<SObject>, Schedulable, Database.Stateful { //SFESWCSD-40
    global Boolean isBirthday;
    global Integer testCase = 0;
    global String testEmail = '';
    //global List<Messaging.SingleEmailMessage> mails;
	global SendEmailHolidaysNotificationBatch(Boolean isBirthday){
        this.isBirthday = isBirthday;
        System.debug('###SendEmailHolidaysNotificationBatch constructor');
    }

    global void execute(SchedulableContext sc) {
        System.debug('###SendEmailHolidaysNotificationBatch execute');
        Database.executeBatch(this, 90);
    }

    public List<SObject> start(Database.BatchableContext BC ){
        System.debug('###SendEmailHolidaysNotificationBatch start isBirthday:' + isBirthday);
        if (isBirthday) {
            Integer currentDay = Date.today().day();
            Integer currentMonth = Date.today().month();
            return [SELECT Id, Email, FirstName FROM Contact WHERE npsp__Do_Not_Contact__c = FALSE AND HasOptedOutOfEmail = FALSE AND Email <> ''  AND CALENDAR_MONTH(Birthdate) =: currentMonth AND DAY_IN_MONTH(Birthdate) =: currentDay];
        } else {
            if (testCase > 0 && testCase < 6) {
            	return [SELECT Id, Email, FirstName FROM Contact WHERE npsp__Do_Not_Contact__c = FALSE AND HasOptedOutOfEmail = FALSE AND Email =: testEmail];                    
            } 
            return [SELECT Id, Email, FirstName FROM Contact WHERE npsp__Do_Not_Contact__c = FALSE AND HasOptedOutOfEmail = FALSE AND Email <> ''];                                
        }
    }

    public void execute(Database.BatchableContext BC, List<Contact> scope){
        System.debug('###SendEmailHolidaysNotificationBatch execute scope:' + scope);
        if (scope == NULL || scope.isEmpty()) {            
        	return;    
        }
        
        EmailTemplate currentEmailTemplate = NULL;
        Set<String> emailTemplateNames = new Set<String>{'Birthday Email','International Women\'s Day','Day of the Namibian Child','Day of the African Child','International Youth Day','Christmas Email'};
            List<EmailTemplate> emailTemplates = new List<EmailTemplate>();
		
        if (!Test.isRunningTest()) {
            emailTemplates = [SELECT Id, Name, Subject, HtmlValue, Body FROM EmailTemplate WHERE Name IN : emailTemplateNames];
        } else {
            emailTemplates = new List<EmailTemplate>{
                new EmailTemplate(Name='Birthday Email', Subject='Happy Birthday {{Recipient.FirstName}}', Body='Hi {{{Recipient.FirstName}}}', HtmlValue=null, DeveloperName='Birthday_Email', TemplateType='custom'),
                    new EmailTemplate(Name='International Women\'s Day', Subject='Happy Women\'s Day', Body='Hi {{{Recipient.FirstName}}}', HtmlValue=null, DeveloperName='IWD_Email', TemplateType='custom'),
                    new EmailTemplate(Name='Day of the Namibian Child', Subject='Namibian Child Day', Body='Hi {{{Recipient.FirstName}}}', HtmlValue=null, DeveloperName='Namibian_Child', TemplateType='custom'),
                    new EmailTemplate(Name='Day of the African Child', Subject='African Child Day', Body='Hi {{{Recipient.FirstName}}}', HtmlValue=null, DeveloperName='African_Child', TemplateType='custom'),
                    new EmailTemplate(Name='International Youth Day', Subject='Youth Day', Body='Hi {{{Recipient.FirstName}}}', HtmlValue=null, DeveloperName='Youth_Day', TemplateType='custom'),
                    new EmailTemplate(Name='Christmas Email', Subject='Merry Christmas', Body='Hi {{{Recipient.FirstName}}}', HtmlValue=null, DeveloperName='Christmas_Email', TemplateType='custom')
                    };
		}
        
        Id orgWideEmailAddressId = Utils.getOrgWideEmailAddress();
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        
        System.debug('###SendEmailHolidaysNotificationBatch execute emailTemplates:' + emailTemplates);
        if (isBirthday) {
            for (Contact con : scope) {
                currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Birthday Email');
                if (currentEmailTemplate != NULL) {                
                    String body = currentEmailTemplate.HtmlValue == null ? currentEmailTemplate.Body : currentEmailTemplate.HtmlValue;
                    String subject = currentEmailTemplate.Subject;
                    String email = con.Email;
                    body = body.replace('{{{Recipient.FirstName}}}', con.FirstName); 
                    Messaging.SingleEmailMessage mail = Utils.addParamsToEmails(con.Id, NULL, email, orgWideEmailAddressId, body, subject);
                    mails.add(mail);
                }
            }
        } else {
            Integer currentDay = Date.today().day();
            Integer currentMonth = Date.today().month();
            System.debug('###SendEmailHolidaysNotificationBatch execute currentDay:' + currentDay);
            System.debug('###SendEmailHolidaysNotificationBatch execute currentMonth:' + currentMonth);
            
            for (Contact con : scope) {
                if (testCase == 1 || (currentDay == 8 && currentMonth == 3)) {
                	currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'International Women\'s Day');                    
                } else if (testCase == 2 || (currentDay == 28 && currentMonth == 9)) {
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Day of the Namibian Child');
                } else if (testCase == 3 || (currentDay == 16 && currentMonth == 6)) {
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Day of the African Child');
                } else if (testCase == 4 || (currentDay == 12 && currentMonth == 8)) {
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'International Youth Day');
                }  else if (testCase == 5 || (currentDay == 25 && currentMonth == 12)) {
                    currentEmailTemplate = Utils.getEmailTemplateByName(emailTemplates, 'Christmas Email');
                }
                
                if (currentEmailTemplate != NULL) {                
                    String body = currentEmailTemplate.HtmlValue == null ? currentEmailTemplate.Body : currentEmailTemplate.HtmlValue;
                    String subject = currentEmailTemplate.Subject;
                    String email = con.Email;
                    body = body.replace('{{{Recipient.FirstName}}}', con.FirstName); 
                    Messaging.SingleEmailMessage mail = Utils.addParamsToEmails(con.Id, NULL, email, orgWideEmailAddressId, body, subject);
                    mails.add(mail);
                }
            }
        }
        
        System.debug('###SendEmailHolidaysNotificationBatch execute mails:' + mails);
        try {
            if (!mails.isEmpty()) {
                Utils.sendEmails(mails); 
            }
        }catch(Exception ex) {
            System.debug('###SendEmailHolidaysNotificationBatch execute errors:' + ex.getMessage());
        }
        System.debug('###SendEmailHolidaysNotificationBatch execute mails:' + mails);
    }
        
    public void finish(Database.BatchableContext BC) {            
    }
}