//SFESWCSD-74
public class ArifpayService {
    private static Arifpay_Config__mdt config;
    
    static {
        config = [
            SELECT Bearer_Token__c, Endpoint__c, Merchant_API_Key__c
            FROM Arifpay_Config__mdt
            WHERE Active__c = true
            LIMIT 1
        ];
    }
    
    public static void setToken(String newToken) {
        Metadata.CustomMetadata cmd = new Metadata.CustomMetadata();
        cmd.fullName = 'Arifpay_Credentials.Default';
        cmd.label = 'Default';
        
        Metadata.CustomMetadataValue tokenField = new Metadata.CustomMetadataValue();
        tokenField.field = 'Bearer_Token__c';
        tokenField.value = newToken;
        cmd.values.add(tokenField);
        
        tokenField = new Metadata.CustomMetadataValue();
        tokenField.field = 'Token_Expiry__c';
        tokenField.value = Datetime.Now();
        cmd.values.add(tokenField);
        
        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(cmd);
        
        Metadata.Operations.enqueueDeployment(container, null);    
    }
    
    public static String getToken(){
        return config.Bearer_Token__c;
    }
    
    public static String getEndpoint(){
        return config.Endpoint__c;
    }

    public static String getMerchantApiKey(){
        return config.Merchant_API_Key__c;
    }
    
    public static String getValidToken(){
        Arifpay_Config__mdt config = [
            SELECT Bearer_Token__c, Token_Expiry__c
            FROM Arifpay_Config__mdt
            WHERE Active__c = true
            LIMIT 1
        ];

        // If token still valid → use it
        if(config.Token_Expiry__c != null &&
           config.Token_Expiry__c > System.now().addMinutes(5)){
            return config.Bearer_Token__c;
        }

        // Otherwise → refresh
        return refreshToken();
    }

    private static String refreshToken(){
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ArifpayService.getEndpoint() + '/auth/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        req.setBody(JSON.serialize(new Map<String, String>{
            'client_id' => 'YOUR_CLIENT_ID',
            'client_secret' => 'YOUR_SECRET'
        }));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if(res.getStatusCode() != 200){
            throw new CalloutException('Auth failed: ' + res.getBody());
        }

        Map<String, Object> result =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        String token = (String) result.get('access_token');
        Integer expiresIn = (Integer) result.get('expires_in');

        setToken(token);
            
        // ⚠️ CMDT is NOT writable in Apex → use Custom Setting OR Cache
        // Option: store in Platform Cache or Custom Setting
        return token;
    }
    
    public static void charge(String agreementId, Decimal amount) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ArifpayService.getEndpoint() + '/payment');
        req.setMethod('POST');
        req.setHeader('Authorization', ArifpayService.getToken());
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'amount' => amount,
            'agreement' => new Map<String, Object>{
                'id' => agreementId
            }
        };

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if(res.getStatusCode() != 200){
            throw new CalloutException(res.getBody());
        }
    }
}
