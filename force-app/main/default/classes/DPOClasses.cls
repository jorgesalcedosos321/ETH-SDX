public class DPOClasses {
    
    public class verifyTokenRequest {
        public String CompanyToken { get; set; }
        public String Request { get; set; }
        public String TransactionToken { get; set; }
    }
    
    public class verifyTokenResponse {
        public String Result { get; set; }
        public String ResultExplanation { get; set; }
        public String CustomerName { get; set; }
        public String CustomerCredit { get; set; }
        public String TransactionApproval { get; set; }
        public String TransactionCurrency { get; set; }
        public String TransactionAmount { get; set; }
        public String FraudAlert { get; set; }
        public String FraudExplnation { get; set; }
        public String TransactionNetAmount { get; set; }
        public String TransactionSettlementDate { get; set; }
        public String TransactionRollingReserveAmount { get; set; }
        public String TransactionRollingReserveDate { get; set; }
        public String CustomerPhone { get; set; }
        public String CustomerCountry { get; set; }
        public String CustomerAddress { get; set; }
        public String CustomerCity { get; set; }
        public String CustomerZip { get; set; }
        public String MobilePaymentRequest { get; set; }
        public String AccRef { get; set; }
        public verifyTokenResponse(Dom.XMLNode node) {
            this.Result = getNodeValue(node, 'Result');
            this.ResultExplanation = getNodeValue(node, 'ResultExplanation');
            this.CustomerName = getNodeValue(node, 'CustomerName');
            this.CustomerCredit = getNodeValue(node, 'CustomerCredit');
            this.TransactionApproval = getNodeValue(node, 'TransactionApproval');
            this.TransactionCurrency = getNodeValue(node, 'TransactionCurrency');
            this.TransactionAmount = getNodeValue(node, 'TransactionAmount');
            this.FraudAlert = getNodeValue(node, 'FraudAlert');
            this.FraudExplnation = getNodeValue(node, 'FraudExplnation');
            this.TransactionNetAmount = getNodeValue(node, 'TransactionNetAmount');
            this.TransactionSettlementDate = getNodeValue(node, 'TransactionSettlementDate');
            this.TransactionRollingReserveAmount = getNodeValue(node, 'TransactionRollingReserveAmount');
            this.TransactionRollingReserveDate = getNodeValue(node, 'TransactionRollingReserveDate');
            this.CustomerPhone = getNodeValue(node, 'CustomerPhone');
            this.CustomerCountry = getNodeValue(node, 'CustomerCountry');
            this.CustomerAddress = getNodeValue(node, 'CustomerAddress');
            this.CustomerCity = getNodeValue(node, 'CustomerCity');
            this.CustomerZip = getNodeValue(node, 'CustomerZip');
            this.MobilePaymentRequest = getNodeValue(node, 'MobilePaymentRequest');
            this.AccRef = getNodeValue(node, 'AccRef');
        }
    }
    
    public class createTokenRequest {
        public String CompanyToken { get; set; }
        public String Request { get; set; }
        public TransactionData TransactionData { get; set; }
        public List<Service> Services { get; set; }
    }    

    public class createTokenResponse {        
        public String Result { get; set; }
        public String ResultExplanation { get; set; }
        public String TransToken { get; set; }
        public String TransRef { get; set; }
        public List<Allocation> Allocations { get; set; }
        public createTokenResponse(Dom.XMLNode node) {
            this.Result = getNodeValue(node, 'Result');
            this.ResultExplanation = getNodeValue(node, 'ResultExplanation');
            this.TransToken = getNodeValue(node, 'TransToken');
            this.TransRef = getNodeValue(node, 'TransRef');
        } 
    }
    
    public class getSubscriptionTokenRequest {
        public String CompanyToken { get; set; }
        public String Request { get; set; }
        public String SearchCriteria { get; set; }
        public String SearchCriteriaValue { get; set; }
    }
    
    public class getSubscriptionTokenResponse {
        public String Result { get; set; }
        public String ResultExplanation { get; set; }
        public String SubscriptionToken { get; set; }
        public String CustomerToken { get; set; }
        public getSubscriptionTokenResponse(Dom.XMLNode node) {
            this.Result = getNodeValue(node, 'Result');
            this.ResultExplanation = getNodeValue(node, 'ResultExplanation');
            this.SubscriptionToken = getNodeValue(node, 'SubscriptionToken');
            this.CustomerToken = getNodeValue(node, 'CustomerToken');
        }            
    }
    
    // Helper method to get node value
    private static String getNodeValue(Dom.XMLNode node, String tagName) {
        Dom.XMLNode child = node.getChildElement(tagName, null);
        return child != null ? child.getText() : null;
    }
    
    public class chargeTokenRecurrentRequest {
        public String CompanyToken { get; set; }
        public String Request { get; set; }
        public String TransactionToken { get; set; }
        public String subscriptionToken { get; set; }
   }
    
    public class chargeTokenRecurrentResponse {
        public String Result { get; set; }
        public String ResultExplanation { get; set; }
        public chargeTokenRecurrentResponse(Dom.XMLNode node) {
            this.Result = getNodeValue(node, 'Result');
            this.ResultExplanation = getNodeValue(node, 'ResultExplanation');
        }     
    }

    public class Allocations {
    	public List<Allocation> Allocation { get; set; }
    }
    
    public class Allocation {
        public String AllocationID { get; set; }
        public String AllocationCode { get; set; }        
    }
    
    public class TransactionData {
    	public Decimal PaymentAmount { get; set; }
        public String PaymentCurrency { get; set; }
        public String CompanyRef { get; set; }
        public String RedirectURL { get; set; }
        public String BackURL { get; set; }
        public Integer CompanyRefUnique { get; set; }
        public Integer PTL { get; set; }
        public String PTLtype { get; set; }
        public String customerFirstName { get; set; }
        public String customerLastName { get; set; }
        public String customerZip { get; set; }
        public String customerCity { get; set; }
        public String customerCountry { get; set; }
        public String customerEmail { get; set; }
        public Integer AllowRecurrent { get; set; }
        
        // Constructor
        public TransactionData(Decimal PaymentAmount,String PaymentCurrency,Integer AllowRecurrent,
                               String CompanyRef,String RedirectURL,String BackURL,Integer CompanyRefUnique,Integer PTL,String PTLtype,
                               String customerFirstName,String customerLastName,String customerZip,String customerCity,String customerCountry,String customerEmail) {
            this.PaymentAmount = PaymentAmount;
            this.PaymentCurrency = PaymentCurrency;
            this.AllowRecurrent = AllowRecurrent;
            this.CompanyRef = CompanyRef;
            this.RedirectURL = RedirectURL;
            this.BackURL = BackURL;
            this.CompanyRefUnique = CompanyRefUnique;
            this.PTL = PTL;
            this.PTLtype = PTLtype;
            this.customerFirstName = customerFirstName;
            this.customerLastName = customerLastName;
            this.customerZip = customerZip;
            this.customerCity = customerCity;
            this.customerCountry = customerCountry;
            this.customerEmail = customerEmail;
        }
    }
        
	public class Services {
    	public List<Service> Service { get; set; }
    }
        
    public class Service {
    	public Integer ServiceType { get; set; }
        public String ServiceDescription { get; set; }
        public String ServiceDate { get; set; }
        // Constructor
        public Service(Integer serviceType, String serviceDescription, String serviceDate) {
            this.ServiceType = serviceType;
            this.ServiceDescription = serviceDescription;
            this.ServiceDate = serviceDate;
        }
    }
}