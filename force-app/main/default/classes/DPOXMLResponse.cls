public class DPOXMLResponse {     
    public String Result;     
    public String ResultExplanation;     
    public List<DPOTransaction> Transactions;     
    public DPOXMLResponse() {
        Transactions = new List<DPOTransaction>();     
    }     
    public class DPOTransaction {         
        public String TransactionBookRef;         
        public Decimal TransactionAmount;         
        public String TransactionCurrency;         
        public Integer TransactionCityId;         
        public String TransactionPhone;         
        public String TransactionPhonePrefix;        
        public String TransactionRef;         
        public Datetime TransactionPaymentDate;         
        public String TransactionCardType;         
        public String TransactionUserName;         
        public String TransactionApprovalNumber;         
        public List<String> TransactionServiceDescriptions;         
        public String TransactionCustomerPhone;         
        public String TransactionCustomerEmail;         
        public String TransactionCustomerName;         
        public DPOTransaction() {             
            TransactionServiceDescriptions = new List<String>();         
        }     
    } 
}