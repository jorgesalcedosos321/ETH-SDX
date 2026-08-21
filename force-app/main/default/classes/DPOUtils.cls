public class DPOUtils {
    //API Documentation: https://docs.dpopay.com/api/index.html#tag/Basic-Transaction-Operations
    public static String apiPaymentURL = '';
    public static String apiEndPointPaymentUrl = '';
    public static String apiLastEndPointPaymentUrl = '';
	public static String companyToken = ''; //Provided By Dan
    public static Integer serviceType = 0; //Provided By Dan
    public static String rootXMLTag = 'API3G';
    
    public static void setDPOCredentials() {
        createTestData();
        DPO__c dpoCredentials = DPO__c.getInstance(UserInfo.getUserId());
        //List<DPO__c> dpoCredentials = DPO__c.getall().values();
        if (dpoCredentials != NULL) {
            apiEndPointPaymentUrl = dpoCredentials.apiEndPointPaymentUrl__c;
            apiLastEndPointPaymentUrl = dpoCredentials.apiLastEndPointPaymentUrl__c;
            apiPaymentURL = dpoCredentials.apiPaymentURL__c;
            companyToken = dpoCredentials.companyToken__c;
            serviceType = Integer.valueOf(dpoCredentials.serviceType__c);    
        }
    }
    
    public static void createTestData() {
        if (Test.isRunningTest()) {
            DPO__c dpoCredentials = DPO__c.getInstance(UserInfo.getUserId());
            if (String.isBlank(dpoCredentials.apiEndPointPaymentUrl__c)) {
                DPO__c setting = new DPO__c();
                setting.apiEndPointPaymentUrl__c = 'https://secure.3gdirectpay.com/API/v6/';
                setting.apiLastEndPointPaymentUrl__c = 'https://secure.3gdirectpay.com/API/v6/';
                setting.apiPaymentURL__c = 'https://secure.3gdirectpay.com/payv3.php?ID=token';
                setting.companyToken__c = 'B3F59BE7-0756-420E-BB88-1D98E7A6B040';
                setting.serviceType__c = '85325';
                insert setting; 
            }
        }
    }
    
    // Function to validate and return Date from a string
    public static Date validateAndConvertToDate(String dateStr) {
        // Check if the string is not null and has the expected length of 8 characters
        if (dateStr != null && dateStr.length() == 8) {
            try {
                // Attempt to parse the string into a Date object
                Integer year = Integer.valueOf(dateStr.substring(0, 4));
                Integer month = Integer.valueOf(dateStr.substring(4, 6));
                Integer day = Integer.valueOf(dateStr.substring(6, 8));

                // Create a Date object using the parsed values
                Date result = Date.newInstance(year, month, day);

                // Return the Date object
                return result;
            } catch (Exception e) {
                // If any error occurs during parsing, return null
                System.debug('Error while parsing the date string: ' + e.getMessage());
                return null;
            }
        } else {
            // If the string is null or not the expected length, return null
            return null;
        }
    }
        
    // Function to validate and return DateTime from a string
    public static DateTime validateAndConvertToDateTime(String dateTimeStr) {
        // Check if the string is not null and has the expected length of 14 characters
        if (dateTimeStr != null && dateTimeStr.length() == 14) {
            try {
                // Attempt to parse the string into a DateTime object
                Integer year = Integer.valueOf(dateTimeStr.substring(0, 4));
                Integer month = Integer.valueOf(dateTimeStr.substring(4, 6));
                Integer day = Integer.valueOf(dateTimeStr.substring(6, 8));
                Integer hour = Integer.valueOf(dateTimeStr.substring(8, 10));
                Integer minute = Integer.valueOf(dateTimeStr.substring(10, 12));
                Integer second = Integer.valueOf(dateTimeStr.substring(12, 14));

                // Create a DateTime object using the parsed values
                DateTime result = DateTime.newInstance(year, month, day, hour, minute, second);

                // Return the DateTime object
                return result;
            } catch (Exception e) {
                // If any error occurs during parsing, return null
                System.debug('Error while parsing the datetime string: ' + e.getMessage());
                return null;
            }
        } else {
            // If the string is null or not the expected length, return null
            return null;
        }
    }
    
    public static String getXMLFromJson(String jsonString, List<String> specialLevels) {
        Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(jsonString);	// Parse JSON into a map
        String xmlString = '<?xml version="1.0" encoding="UTF-8"?>\n<' + rootXMLTag + '>\n';
        
        for (String key : jsonMap.keySet()) {	// Convert each field to XML format
            String content = String.valueOf(jsonMap.get(key));
            if (specialLevels != NULL && specialLevels.contains(key)) {
                xmlString += '<' + key + '>';
                System.debug('specialLevels content:' + content);
        		Map<String, Object> jsonSubMap = (Map<String, Object>)JSON.deserializeUntyped(content);        
                for (String subkey : jsonSubMap.keySet()) {
                    String subcontent = String.valueOf(jsonSubMap.get(subkey));
                    xmlString += '  <' + subkey + '>' + subcontent + '</' + subkey + '>\n';
                }
                xmlString += '</' + key + '>';
            } else {
            	xmlString += '  <' + key + '>' + content  + '</' + key + '>\n';
            }
        }
        
        return xmlString + '</' + rootXMLTag + '>';
    }
    
    public static String convertJSON(String jsonString, boolean SkipEmptyValues) {
        String xmlString = '<?xml version="1.0" encoding="UTF-8"?>\n<' + rootXMLTag + '>\n';
        Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(jsonString);
        return xmlString + buildXmlFromMap('', jsonMap, SkipEmptyValues) + '</' + rootXMLTag + '>';
    }

    private static String buildXmlFromMap(String rootName, Object node, boolean SkipEmptyValues) {
        String xml = '';
        
        if (node instanceof Map<String, Object>) {
            if (String.isNotBlank(rootName))
            	xml += '<' + rootName + '>';
            Map<String, Object> mapNode = (Map<String, Object>) node;
            for (String key : mapNode.keySet()) {
                xml += buildXmlFromMap(key, mapNode.get(key), SkipEmptyValues);
            }
            if (String.isNotBlank(rootName))
                xml += '</' + rootName + '>';

        } else if (node instanceof List<Object>) {
            List<Object> listNode = (List<Object>) node;
            for (Object item : listNode) {
                xml += buildXmlFromMap(rootName, item, SkipEmptyValues);
            }

        } else {
            // Primitive value
            String newValue = String.valueOf(node);
            
            if (!SkipEmptyValues || (SkipEmptyValues && String.isNotBlank(newValue)))
            	xml += '<' + rootName + '>' + newValue + '</' + rootName + '>';
        }

        return xml;
    }
    
    public static String verifyTokenRequest(String token) { //setCheckPaymentTransactionRequest
        DPOClasses.verifyTokenRequest req = new DPOClasses.verifyTokenRequest();
        req.CompanyToken = companyToken;
        req.Request = 'verifyToken';
        req.TransactionToken = token;
        
        String jsonStr = JSON.serialize(req);
        return getXMLFromJson(jsonStr, null);
    }
    
    public static String getFormattedDateTime(DateTime dt) {
        return dt.format('yyyy/MM/dd HH:mm');
    }

    // Optional: Shortcut to get current date/time formatted
    public static String getCurrentFormattedDateTime() {
        return getFormattedDateTime(DateTime.now());
    }
    
    public static String setCreateTokenRequest(DPOClasses.TransactionData transactionData, List<DPOClasses.Service> services) {
        DPOClasses.createTokenRequest req = new DPOClasses.createTokenRequest();
        req.CompanyToken = companyToken;
        req.Request = 'createToken';
        req.TransactionData = transactionData;
        req.Services = services;
        
        String jsonStr = JSON.serialize(req);
        System.debug('jsonStr:'+jsonStr);
        jsonStr = jsonStr.replace('"TransactionData"', '"Transaction"');
        System.debug('jsonStr New:'+jsonStr);
        //return getXMLFromJson(jsonStr, new List<String> {'Transaction', 'Services'});
        String jsonConverted = convertJSON(jsonStr, true);
        jsonConverted = jsonConverted.replace('<Services>', '<Services><Service>').replace('</Services>', '</Service></Services>');
        List<String> jsonList = splitByLength(jsonConverted, 80);
        for (String json : jsonList) {
            System.debug('json print:' + json);
        }
        return jsonConverted;
    }
    
    public static List<String> splitByLength(String input, Integer chunkSize) {
        List<String> chunks = new List<String>();
        if (String.isBlank(input) || chunkSize <= 0) {
            return chunks;
        }

        for (Integer i = 0; i < input.length(); i += chunkSize) {
            Integer ending = Math.min(i + chunkSize, input.length());
            chunks.add(input.substring(i, ending));
        }

        return chunks;
    }
    
    public static String setGetSubscriptionTokenRequest(String searchCriteria, String searchCriteriaValue) {
        DPOClasses.getSubscriptionTokenRequest req = new DPOClasses.getSubscriptionTokenRequest();
        req.CompanyToken = companyToken;
        req.Request = 'getSubscriptionToken';
        req.SearchCriteria = searchCriteria;	//occur by Email (1) or phone number (2)
        req.SearchCriteriaValue = searchCriteriaValue;
        
        String jsonStr = JSON.serialize(req);
        return getXMLFromJson(jsonStr, null);
    }
    
    public static Map<String, String> getResultCodes() {
        Map<String, String> resultCodes = new Map<String, String>();
        resultCodes.put('000','Transaction created');
        resultCodes.put('801','Request missing company token');
        resultCodes.put('802','Company token does not exist');
        resultCodes.put('803','No request or error in Request type name');
        resultCodes.put('804','Error in XML');
        resultCodes.put('901','Error max string size allowed');
        resultCodes.put('902','Request missing transaction level mandatory fields - name of field');
        resultCodes.put('904','Currency not supported');
        resultCodes.put('905','The transaction amount has exceeded your allowed transaction limit, please contact: support@directpay.online');
        resultCodes.put('906','You exceeded your monthly transactions limit, please contact support');
        resultCodes.put('922','Provider does not exist');
        resultCodes.put('923','Allocated money exceeds payment amount');
        resultCodes.put('930','Block payment code incorrect');
        resultCodes.put('940','CompanyREF already exists and paid');
        resultCodes.put('950','Request missing mandatory fields - name of field, Request fields empty');
        resultCodes.put('960','Tag has been sent multiple times');
		return resultCodes;
    }
        
    
    public static String sendChargeTokenRecurrentRequest(String transactionToken, String subscriptionToken) {
        DPOClasses.ChargeTokenRecurrentRequest req = new DPOClasses.ChargeTokenRecurrentRequest();
        req.CompanyToken = companyToken;
        req.Request = 'chargeTokenRecurrent';
        req.TransactionToken = transactionToken;	//Token of transaction we want to pay
        req.subscriptionToken = subscriptionToken;	//Token you got from 3G to operate this API
        
        String jsonStr = JSON.serialize(req);
        return getXMLFromJson(jsonStr, null); 
    }
    
    public static String setDPORequest(String companyToken, String startTimestamp, String endTimestamp, Integer records, Integer offSet) {
        String xmlRequest = '';
        xmlRequest = '<?xml version="1.0" encoding="utf-8"?>';
        xmlRequest += '<API3G>';
        xmlRequest += '    <CompanyToken>' + companyToken + '</CompanyToken>';
        xmlRequest += '    <Request>getTransactions</Request>';
        xmlRequest += '    <recordOffset>' + offSet + '</recordOffset>';
        xmlRequest += '    <numOfRecords>' + records + '</numOfRecords>';
        xmlRequest += '    <startTimeStamp>' + startTimestamp + '</startTimeStamp>';
        xmlRequest += '    <endTimeStamp>' + endTimestamp + '</endTimeStamp>';
        xmlRequest += '    <allTrans>1</allTrans>';
        xmlRequest += '    <userToken></userToken>';
        xmlRequest += '    <descOrder>1</descOrder>';
        xmlRequest += '    <filterBy>1</filterBy>';
        xmlRequest += '</API3G>';
        return xmlRequest;
    }
    public static Object convertXMLResponseToClass(String xmlContent, String className) {
        Dom.Document doc = new Dom.Document(); 
        doc.load(xmlContent);
        switch on className {
            when 'DPOClasses.getSubscriptionTokenResponse' {
                return new DPOClasses.getSubscriptionTokenResponse(doc.getRootElement());    
            }  
            when 'DPOClasses.chargeTokenRecurrentResponse' {
                return new DPOClasses.ChargeTokenRecurrentResponse(doc.getRootElement());    
            }               
            when 'DPOClasses.createTokenResponse' {
                return new DPOClasses.createTokenResponse(doc.getRootElement());    
            }                           
            when 'DPOClasses.verifyTokenResponse' {
                return new DPOClasses.verifyTokenResponse(doc.getRootElement());    
            }  
        } 
        return null;
    }
    
    public static DPOXMLResponse getDPOTransactionObjectByXML(String xmlContent) {
        // Aquí iría el XML completo 
        Dom.Document doc = new Dom.Document(); 
        doc.load(xmlContent);
        //return new AccountData(doc.getRootElement());
        DPOXMLResponse apiResponse = new DPOXMLResponse(); 
        Dom.XmlNode root = doc.getRootElement(); 
        apiResponse.Result = root.getChildElement('Result', null).getText(); 
        apiResponse.ResultExplanation = root.getChildElement('ResultExplanation', null).getText(); 
        // Procesar las transacciones 
        Dom.XmlNode transactionsNode = root.getChildElement('Transactions', null); 
        for (Dom.XmlNode transactionNode : transactionsNode.getChildElements()) {     
            DPOXMLResponse.DPOTransaction transactionRec = new DPOXMLResponse.DPOTransaction();          
            transactionRec.TransactionBookRef = transactionNode.getChildElement('TransactionBookRef', null).getText();     
            transactionRec.TransactionAmount = Decimal.valueOf(transactionNode.getChildElement('TransactionAmount', null).getText());     
            transactionRec.TransactionCurrency = transactionNode.getChildElement('TransactionCurrency', null).getText();     
            transactionRec.TransactionCityId = Integer.valueOf(transactionNode.getChildElement('TransactionCityId', null).getText());     
            transactionRec.TransactionPhone = transactionNode.getChildElement('TransactionPhone', null).getText();     
            transactionRec.TransactionPhonePrefix = transactionNode.getChildElement('TransactionPhonePrefix', null).getText();     
            transactionRec.TransactionRef = transactionNode.getChildElement('TransactionRef', null).getText();     
            transactionRec.TransactionPaymentDate = Datetime.valueOf(transactionNode.getChildElement('TransactionPaymentDate', null).getText());     
            transactionRec.TransactionCardType = transactionNode.getChildElement('TransactionCardType', null).getText();     
            transactionRec.TransactionUserName = transactionNode.getChildElement('TransactionUserName', null).getText();     
            transactionRec.TransactionApprovalNumber = transactionNode.getChildElement('TransactionApprovalNumber', null).getText();          
            // Procesar las descripciones de servicio     
            Dom.XmlNode serviceDescNode = transactionNode.getChildElement('TransactionServiceDescription', null);     
            for (Dom.XmlNode serviceItem : serviceDescNode.getChildElements()) {         
                transactionRec.TransactionServiceDescriptions.add(serviceItem.getText());     
            }     
            transactionRec.TransactionCustomerPhone = transactionNode.getChildElement('TransactionCustomerPhone', null).getText();     
            transactionRec.TransactionCustomerEmail = transactionNode.getChildElement('TransactionCustomerEmail', null).getText();     
            transactionRec.TransactionCustomerName = transactionNode.getChildElement('TransactionCustomerName', null).getText();          
            apiResponse.Transactions.add(transactionRec); 
        }
        return apiResponse;
    }
}