/**********************************************************************************
* Date:           22 Aug 2023
* Author:         Shohrat Muhamov
* Description:    This is utility class to integrate with Cybersource APIs
* Version:        1.0
* 
**********************************************************************************/
public class CybersourceAPI {
    private cybs__Payment_Configuration__mdt cybersourceConfigs;
    private String body;
    private String host;

    public CybersourceAPI() {
        this.cybersourceConfigs = [SELECT cybs__REST_Shared_Key__c, cybs__REST_Key_ID__c, cybs__Merchant_ID__c, DeveloperName FROM cybs__Payment_Configuration__mdt Where DeveloperName = 'Name' Limit 1];
        if (isSandbox()) {
            this.host = 'apitest.cybersource.com';
        } else {
            this.host = 'api.cybersource.com';
        }
    }
   
    private static Boolean isSandbox() {
        return [SELECT IsSandbox FROM Organization].IsSandbox;
    }

    public void setCaptureBody(String orderNumber, String totalAmount) {
        this.body = '{'
            +'"clientReferenceInformation":{'
            +'"code":"'+orderNumber+'"'
                +'},'
            +'"orderInformation":{'
            +'"amountDetails":{'
                    +'"totalAmount":"'+totalAmount+'",'
                    +'"currency":"USD"'
                +'}'
            +'}'
        +'}';        
    }

    public void setBody(String body) {
        this.body = body;
    }

    private String generateDigest() {
        return 'SHA-256='+ EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(this.body)));        
    }

    private String generateSignatureHash(String method, String requestTarget) {
        return EncodingUtil.base64Encode(Crypto.generateMac('hmacSHA256', Blob.valueOf(generateSignatureHashHeaders(method, requestTarget)), EncodingUtil.base64Decode(this.cybersourceConfigs.cybs__REST_Shared_Key__c)));
    }

    private String generateSignature(String method, String requestTarget) {
        String signature = 'Signature: keyid="' + this.cybersourceConfigs.cybs__REST_Key_ID__c+'", ';
        signature += 'algorithm="HmacSHA256", ';
        signature += 'headers="'+generateHeaders(method)+'", ';
        signature += 'signature="' + generateSignatureHash(method, requestTarget) + '"';
        return signature;
    }
    
    private String generateHeaders(String method) {
        String header = 'host ';
        header += '(request-target) ';
        if (method.equals('post')) {
            header += 'digest ';
        }
        header += 'v-c-merchant-id';
        return header;
    }

   private String generateSignatureHashHeaders(String method, String requestTarget)  {
        String headers = 'host: '+this.host + '\n';
        headers += '(request-target): '+ method + ' ' + requestTarget + '\n';
        if (method.equals('post')) {
            headers += 'digest: ' + generateDigest()+'\n';
        }
        headers += 'v-c-merchant-id: ' + this.cybersourceConfigs.cybs__Merchant_ID__c;
        return headers;
    }

    public HttpResponse makeCallout(String method, String requestTarget) {
        String dateGMT = DateTime.now().formatGMT('EEE, MMM d yyyy HH:mm:ss z');

        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://'+this.host+requestTarget);
        req.setMethod(method);
        req.setTimeout(120000);
        req.setHeader('Host', this.host);
        req.setHeader('Signature', generateSignature(method.toLowerCase(), requestTarget));
        if (method == 'POST'){
         req.setHeader('Digest', generateDigest());
         req.setBody(this.body);
        }
        req.setHeader('v-c-merchant-id', 'merchantName');
        req.setHeader('v-c-date', dateGMT);
        req.setHeader('Content-Type', 'application/json');
		HttpResponse res = h.send(req);
        return res;
    }
}
