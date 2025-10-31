/**
 * @description Handler class for Google reCAPTCHA v2 integration with Salesforce.
 * This class provides server-side verification of reCAPTCHA responses and manages
 * verification state using Platform Cache.
 */
public with sharing class GoogleRecaptchaHandler {

    /**
     * @description Fetch the list of allowed base URLs for postMessage security validation.
     * Returns organization domain URLs and their variants for Lightning and Visualforce.
     * @return List<String> List of allowed URLs for secure communication.
     */
    @AuraEnabled
    public static List<String> fetchBaseURL() {
        List<String> allowedURLs = new List<String>();

        allowedURLs.add(URL.getOrgDomainUrl().toExternalForm());
        allowedURLs.add(URL.getOrgDomainUrl().toExternalForm().replace('.my.salesforce.com', '.lightning.force.com'));
        allowedURLs.add(URL.getOrgDomainUrl().toExternalForm().replace('.my.salesforce.com', '--c.visualforce.com'));

        return allowedURLs;
    } 
    /**
     * @description Verify reCAPTCHA response with Google's verification API.
     * Deprecated in favor of verifyResponse(String, String, String) which uses Custom Metadata settings.
     * @param recaptchaResponse The response token from Google reCAPTCHA.
     * @param recaptchaSecretKey The secret key for verification.
     * @param flowInterviewGuid The Flow Interview GUID for cache storage.
     * @return Boolean True if verification successful, false otherwise.
     * @deprecated Use verifyResponse(String, String, String) instead.
     * @throws CalloutException If the HTTP callout fails.
     */
    @AuraEnabled
    public static Boolean isVerified(String recaptchaResponse, String recaptchaSecretKey, String flowInterviewGuid){
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://www.google.com/recaptcha/api/siteverify');
        request.setMethod('POST');
        request.setBody('secret=' + recaptchaSecretKey + '&response=' + recaptchaResponse);
        HttpResponse response = http.send(request);

        if (response.getStatusCode() == 200) {
            System.debug(response.getBody());
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

            if (result.containsKey('success') && result.get('success') == true) {      
                
                // Store in platform cache
                Cache.Org.put(getCacheKey(flowInterviewGuid), DateTime.now());

                return true;      
            } else {
                return false;
            }
        }
        
        return false;
    }
    
    /**
     * @description Validate that reCAPTCHA has been completed for the given Flow Interview.
     * This invocable method checks Platform Cache for a valid verification record.
     * @param flowInterviewGuids List of Flow Interview GUIDs to validate.
     * @return List<Boolean> List of validation results corresponding to input GUIDs.
     */
    @InvocableMethod (label='Validate reCAPTCHA' description='Use the Flow Interview ID to validate the reCAPTCHA has been submitted by user')
    public static List<Boolean> validateRecaptcha(List<String> flowInterviewGuids) {  
        
        List<Boolean> validated = new List<Boolean>();

        for (String flowInterviewGuid :flowInterviewGuids) {

            // If we have a valid validation record
            if (Cache.Org.contains(getCacheKey(flowInterviewGuid))) {

                validated.add(true);

                // Remove the cache
                Cache.Org.remove(getCacheKey(flowInterviewGuid));
            }
            else {

                validated.add(false); 
            }
        }

        return validated;
    }

    /**
     * @description Generate a cache key for storing verification results.
     * @param flowInterviewGuid The Flow Interview GUID.
     * @return String The cache key for Platform Cache storage.
     */
    public static String getCacheKey(String flowInterviewGuid) {
        return 'local.GoogleRecaptchaVerification.' + flowInterviewGuid.split('-')[0];
    }

    /**
     * @description Retrieve Google reCAPTCHA settings from Custom Metadata Type.
     * Returns only the site key (secret key remains server-side for security).
     * @param settingName The DeveloperName of the GoogleRecaptchaSetting__mdt record.
     * @return Map<String, String> Map containing the site key.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getRecaptchaSetting(String settingName) {
        Map<String, String> result = new Map<String, String>();
        
        try {
            // Query the Custom Metadata Type
            List<GoogleRecaptchaSetting__mdt> settings = [
                SELECT SiteKey__c, SecretKey__c 
                FROM GoogleRecaptchaSetting__mdt 
                WHERE DeveloperName = :settingName 
                LIMIT 1
            ];
            
            if (!settings.isEmpty()) {
                // Only return the site key to LWC (secret key stays on server)
                result.put('siteKey', settings[0].SiteKey__c);
            }
        } catch (Exception e) {
            System.debug('Error fetching reCAPTCHA settings: ' + e.getMessage());
        }
        
        return result;
    }

    /**
     * @description Verify reCAPTCHA response using settings from Custom Metadata Type.
     * Makes a callout to Google's verification API and stores result in Platform Cache.
     * @param recaptchaResponse The response token from Google reCAPTCHA.
     * @param recaptchaSettingName The DeveloperName of the GoogleRecaptchaSetting__mdt record.
     * @param flowInterviewGuid The Flow Interview GUID for cache storage.
     * @return Boolean True if verification successful, false otherwise.
     * @throws CalloutException If the HTTP callout fails.
     */
    @AuraEnabled
    public static Boolean verifyResponse(String recaptchaResponse, String recaptchaSettingName, String flowInterviewGuid) {
        try {
            // Retrieve the secret key from Custom Metadata Type
            List<GoogleRecaptchaSetting__mdt> settings = [
                SELECT SecretKey__c 
                FROM GoogleRecaptchaSetting__mdt 
                WHERE DeveloperName = :recaptchaSettingName 
                LIMIT 1
            ];
            
            if (settings.isEmpty()) {
                System.debug('No reCAPTCHA setting found with name: ' + recaptchaSettingName);
                return false;
            }
            
            String secretKey = settings[0].SecretKey__c;
            
            // Make the verification request to Google
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('https://www.google.com/recaptcha/api/siteverify');
            request.setMethod('POST');
            request.setBody('secret=' + secretKey + '&response=' + recaptchaResponse);
            HttpResponse response = http.send(request);

            if (response.getStatusCode() == 200) {
                System.debug(response.getBody());
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

                if (result.containsKey('success') && result.get('success') == true) {      
                    // Store in platform cache
                    Cache.Org.put(getCacheKey(flowInterviewGuid), DateTime.now());
                    return true;      
                } else {
                    return false;
                }
            }
            
            return false;
        } catch (Exception e) {
            System.debug('Error verifying reCAPTCHA: ' + e.getMessage());
            return false;
        }
    }
}
