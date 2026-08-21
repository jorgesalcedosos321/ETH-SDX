public class DPOHandler {
    /*
    https://docs.dpopay.com/api/index.html#tag/Basic-Transaction-Operations/operation/createToken
    DPOHandler dpo = new DPOHandler();
    String startTimestamp = '1730482585';
    String endTimestamp = '1731346585';        
    Integer records = 50;
    Integer offSet = 0;      
    DPOXMLResponse res = dpo.getTransactionsOneDayAgo(records,offSet);
    System.debug('res:' + res);*/
    public DPOHandler() {
        DPOUtils.setDPOCredentials();    
    }
    
    public Object getResponseByXML(String xmlRequest, String className) {
        String xmlResponse = getConnectionAndRequestWithAPI(xmlRequest);
        return DPOUtils.convertXMLResponseToClass(xmlResponse, className);
    }
    
    public String getConnectionAndRequestWithAPI(String xmlRequest) {
        String body = '';
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(DPOUtils.apiEndPointPaymentUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/xml');
        req.setBody(xmlRequest);
        
        if (!Test.isRunningTest()) {
            HTTPResponse res = http.send(req);
            body = res.getBody();
        } else {
            body = xmlResponseSample();
        }
        return body;
    }
    
    public void saveDPOTransactionValuesToPayment(DPOXMLResponse res) {
        //TODO: which values to be saved?
        if (res.Transactions.size() > 0) {
            Set<String> payRefs = new Set<String>();

            for (DPOXMLResponse.DPOTransaction tran : res.Transactions) {            
                if (!payRefs.contains(tran.TransactionRef)) {
                    payRefs.add(tran.TransactionRef);
                }                
            }

            List<npe01__OppPayment__c> pays = [SELECT Id, npe01__Payment_Amount__c, npe01__Payment_Date__c, Transaction_Book_Ref__c, Transaction_Ref__c, Transaction_Approval_Number__c FROM npe01__OppPayment__c WHERE Transaction_Ref__c IN : payRefs];

            for (DPOXMLResponse.DPOTransaction tran : res.Transactions) {
                npe01__OppPayment__c pay = getTransactionByCode(pays, tran.TransactionRef);
                if (pay == null) {
                    continue;
                }

                pay.npe01__Payment_Amount__c = tran.TransactionAmount;
                pay.npe01__Payment_Date__c = Date.newInstance(tran.TransactionPaymentDate.Year(), tran.TransactionPaymentDate.Month(), tran.TransactionPaymentDate.Day());
                pay.Transaction_Book_Ref__c = tran.TransactionBookRef;
                pay.Transaction_Ref__c = tran.TransactionRef;
                pay.Transaction_Approval_Number__c = tran.TransactionApprovalNumber;
            }
        }
        /*TransactionPaymentDate
        TransactionCardType
        TransactionPhone
        TransactionPhonePrefix
        TransactionServiceDescription => ServiceDescription*/
    }  

    //TOBE
    public npe01__OppPayment__c getTransactionByCode(List<npe01__OppPayment__c> pays, String tranRef) {
        for (npe01__OppPayment__c pay : pays) {
            if (pay.Transaction_Ref__c == tranRef) {
                return pay;
            }
        } 
        return null;
    }
    
    public DPOXMLResponse getTransactionsOneDayAgo(Integer records, Integer offSet, String startTimestamp, String endTimestamp) {
        //String startTimestamp = Utils.getTimestampFromAddingDays(Date.today(), -1);
        //String endTimestamp = Utils.getTimestampFromAddingDays(Date.today(), 0);
        System.debug('####getTransactionsOneDayAgo 0');
        String xmlRequest = DPOUtils.setDPORequest(DPOUtils.companyToken, startTimestamp, endTimestamp, records, offSet);
        System.debug('####getTransactionsOneDayAgo 1:' + xmlRequest);
        String xmlResponse = getConnectionAndRequestWithAPI(xmlRequest);
        System.debug('####getTransactionsOneDayAgo 2:' + xmlResponse);
        DPOXMLResponse response = DPOUtils.getDPOTransactionObjectByXML(xmlResponse);
        System.debug('####getTransactionsOneDayAgo 3');
		return response;
    }

    public String xmlResponseSample() {
        return '<?xml version="1.0" encoding="utf-8"?><API3G><Result>000</Result><ResultExplanation>Records found</ResultExplanation><Transactions><Transaction><TransactionBookRef>2798</TransactionBookRef><TransactionAmount>1.00</TransactionAmount><TransactionCurrency>KES</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>0706970265</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62212516</TransactionRef><TransactionPaymentDate>2024-11-05 09:00:49</TransactionPaymentDate><TransactionCardType>Mobile</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>SK58NICJ10</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>Tutor Subscription</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>2800</TransactionBookRef><TransactionAmount>1.00</TransactionAmount><TransactionCurrency>KES</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>0706970265</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62213253</TransactionRef><TransactionPaymentDate>2024-11-05 09:20:30</TransactionPaymentDate><TransactionCardType>Mobile</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>SK58NL2PXY</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>Parent Subscription</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>804</TransactionBookRef><TransactionAmount>268.00</TransactionAmount><TransactionCurrency>UGX</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>773326714</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62225326</TransactionRef><TransactionPaymentDate>2024-11-05 14:48:20</TransactionPaymentDate><TransactionCardType>Mobile</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>29147515537</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>Relaxed Fit Joggers</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>22224</TransactionBookRef><TransactionAmount>5718.00</TransactionAmount><TransactionCurrency>TZS</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>758914212</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62308491</TransactionRef><TransactionPaymentDate>2024-11-07 10:51:55</TransactionPaymentDate><TransactionCardType>Mobile</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>BK70FCD9ZA6</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>Business Course 1</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>WV3O8N</TransactionBookRef><TransactionAmount>1.00</TransactionAmount><TransactionCurrency>XOF</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>2250768306204</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62309019</TransactionRef><TransactionPaymentDate>2024-11-07 11:15:48</TransactionPaymentDate><TransactionCardType>Mobile</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>MP241107.1115.A88656</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>Shopping</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>PCI TEST</TransactionBookRef><TransactionAmount>1.00</TransactionAmount><TransactionCurrency>KES</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone/><TransactionPhonePrefix/><TransactionRef>R62320877</TransactionRef><TransactionPaymentDate>2024-11-07 17:40:01</TransactionPaymentDate><TransactionCardType>Mobile</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>SK78YSOI04</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>LAMB STIR FRY (500g)</ServiceDescription><ServiceDescription>SALMON FRY (300g)</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>20241108103525554876</TransactionBookRef><TransactionAmount>18.35</TransactionAmount><TransactionCurrency>NGN</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>7047800174</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62339383</TransactionRef><TransactionPaymentDate>2024-11-08 10:37:44</TransactionPaymentDate><TransactionCardType>USSD</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber/><TransactionServiceDescription><ServiceDescription>Save card details</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>20241108105728261726</TransactionBookRef><TransactionAmount>18.38</TransactionAmount><TransactionCurrency>NGN</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>7047800174</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62339945</TransactionRef><TransactionPaymentDate>2024-11-08 10:59:07</TransactionPaymentDate><TransactionCardType>USSD</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber/><TransactionServiceDescription><ServiceDescription>Save card details</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>20241108110859276949</TransactionBookRef><TransactionAmount>18.38</TransactionAmount><TransactionCurrency>NGN</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>7047800174</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62340297</TransactionRef><TransactionPaymentDate>2024-11-08 11:11:32</TransactionPaymentDate><TransactionCardType>USSD</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber/><TransactionServiceDescription><ServiceDescription>Save card details</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>22245</TransactionBookRef><TransactionAmount>2.00</TransactionAmount><TransactionCurrency>USD</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>758914212</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62360690</TransactionRef><TransactionPaymentDate>2024-11-09 05:54:17</TransactionPaymentDate><TransactionCardType>PayPal</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>19079384CL860112A</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>Business Course 1</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>2661</TransactionBookRef><TransactionAmount>518.00</TransactionAmount><TransactionCurrency>UGX</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>00256743514131</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62381978</TransactionRef><TransactionPaymentDate>2024-11-09 22:13:14</TransactionPaymentDate><TransactionCardType>Mobile</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>112505703379</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>Casual Cheap Canvas Slip On Shoes</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>651</TransactionBookRef><TransactionAmount>5.00</TransactionAmount><TransactionCurrency>GHS</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>0547917074</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62386802</TransactionRef><TransactionPaymentDate>2024-11-10 07:09:07</TransactionPaymentDate><TransactionCardType>Mobile</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>47244783028</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>Vintage Animal Hoodie Sweatshirt</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>241111wvlfkXgGLe</TransactionBookRef><TransactionAmount>0.81</TransactionAmount><TransactionCurrency>EUR</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>971000000</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62424519</TransactionRef><TransactionPaymentDate>2024-11-11 14:19:07</TransactionPaymentDate><TransactionCardType>Mastercard</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>4444444419</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>Transports</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction><Transaction><TransactionBookRef>241111dWLiFthCDg</TransactionBookRef><TransactionAmount>1.10</TransactionAmount><TransactionCurrency>EUR</TransactionCurrency><TransactionCityId>0</TransactionCityId><TransactionPhone>971000000</TransactionPhone><TransactionPhonePrefix/><TransactionRef>R62427557</TransactionRef><TransactionPaymentDate>2024-11-11 16:21:55</TransactionPaymentDate><TransactionCardType>Mastercard</TransactionCardType><TransactionUserName>System</TransactionUserName><TransactionApprovalNumber>4444444421</TransactionApprovalNumber><TransactionServiceDescription><ServiceDescription>Transports</ServiceDescription></TransactionServiceDescription><TransactionCustomerPhone/><TransactionCustomerEmail/><TransactionCustomerName> </TransactionCustomerName></Transaction></Transactions></API3G>';
    }
}