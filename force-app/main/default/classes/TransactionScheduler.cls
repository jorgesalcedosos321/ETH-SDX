//System.schedule('Daily Transaction Job', '0 0 23 * * ?', new TransactionScheduler());
global class TransactionScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        List<Transaction__c> transactions = TransactionService.getTodaysTransactions();

        if (transactions.isEmpty()) {
            return;
        }

        // Collect JSON data
        List<String> jsonList = new List<String>();
        for (Transaction__c txn : transactions) {
            jsonList.add(txn.Json__c);
        }

        // Convert to JSON
        String finalJson = JSON.serialize(jsonList);
        
        // Create text file
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFilename('transactions.json');
        attachment.setBody(Blob.valueOf(finalJson));
        attachment.setContentType('application/json');

        // Send email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(Utils.userToNotifyJSONTransaction);
        mail.setSubject('Daily Transactions JSON');
        mail.setPlainTextBody('Attached is the JSON file containing today’s transactions.');
        mail.setFileAttachments(new Messaging.EmailFileAttachment[] {attachment});
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail});
        } catch(Exception ex) {            
        }
        // Delete today's transactions
        delete transactions;
    }
}