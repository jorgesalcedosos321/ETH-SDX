public class TransactionService {
    public static Id insertTransaction(String jsonText) {
        Transaction__c txn = new Transaction__c();
        txn.Json__c = jsonText;
        insert txn;
        return txn.Id;
    }
    
    public static void updateTransactionErrors(Id transactionId, String errors) {
        List<Transaction__c> txs = [SELECT Id, Errors__c, Has_Errors__c FROM Transaction__c WHERE Id =: transactionId];
        
        if (!txs.isEmpty()) {
            txs[0].Errors__c = errors;
            txs[0].Has_Errors__c = true;
        	UPDATE txs;        
        }
    }
    
    // Method to get today's transactions
    public static List<Transaction__c> getTodaysTransactions() {
        return [SELECT Id, Json__c FROM Transaction__c WHERE CreatedDate = TODAY];
    }
}