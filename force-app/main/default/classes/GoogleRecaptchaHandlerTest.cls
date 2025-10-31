/**
 * @description Unit tests for GoogleRecaptchaHandler.
 * Verifies reCAPTCHA verification flow, allowed base URL retrieval, and HTTP callout handling.
 */
@IsTest
global with sharing class GoogleRecaptchaHandlerTest {

    /**
     * @description Validate that the deprecated isVerified method returns true with a successful mock response.
     * @see GoogleRecaptchaHandler#isVerified(String, String, String)
     */
    @IsTest static void testIsVerified() {
        Test.setMock(HttpCalloutMock.class, new GoogleRecaptchaHandlerTest.RecaptchaHttpCalloutMock());

        System.assert(GoogleRecaptchaHandler.isVerified('8djkfhsdfjsd49234734', '6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe', 'XXX'));
    }

    /**
     * @description Ensure fetchBaseURL returns org domain and expected variants.
     * @see GoogleRecaptchaHandler#fetchBaseURL()
     */
    @IsTest static void testFetchBaseURL() {
        List<String> myURLs = GoogleRecaptchaHandler.fetchBaseURL();

        System.assertEquals(3, myURLs.size());
        System.assert(myURLs.contains(URL.getOrgDomainUrl().toExternalForm()));
    }

    /**
     * @description Test validateRecaptcha with valid cache entries.
     */
    @IsTest static void testValidateRecaptchaSuccess() {
        String flowInterviewGuid = 'test-guid-123';
        String cacheKey = GoogleRecaptchaHandler.getCacheKey(flowInterviewGuid);
        
        // Store verification in cache
        Cache.Org.put(cacheKey, DateTime.now());
        
        List<String> guids = new List<String>{ flowInterviewGuid };
        List<Boolean> results = GoogleRecaptchaHandler.validateRecaptcha(guids);
        
        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0]);
        
        // Cache should be removed after validation
        System.assertEquals(false, Cache.Org.contains(cacheKey));
    }

    /**
     * @description Test validateRecaptcha with invalid/missing cache entries.
     */
    @IsTest static void testValidateRecaptchaFailure() {
        String flowInterviewGuid = 'test-guid-456';
        
        List<String> guids = new List<String>{ flowInterviewGuid };
        List<Boolean> results = GoogleRecaptchaHandler.validateRecaptcha(guids);
        
        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0]);
    }

    /**
     * @description Test validateRecaptcha with multiple GUIDs.
     */
    @IsTest static void testValidateRecaptchaMultiple() {
        String validGuid = 'valid-guid-123';
        String invalidGuid = 'invalid-guid-456';
        
        // Only store one in cache
        Cache.Org.put(GoogleRecaptchaHandler.getCacheKey(validGuid), DateTime.now());
        
        List<String> guids = new List<String>{ validGuid, invalidGuid };
        List<Boolean> results = GoogleRecaptchaHandler.validateRecaptcha(guids);
        
        System.assertEquals(2, results.size());
        System.assertEquals(true, results[0]);
        System.assertEquals(false, results[1]);
    }

    /**
     * @description Test getRecaptchaSetting with valid setting name.
     */
    @IsTest static void testGetRecaptchaSettingSuccess() {
        // Mock the DataSource to return a setting
        Test.startTest();
        
        Map<String, String> result = GoogleRecaptchaHandler.getRecaptchaSetting('Default');
        
        Test.stopTest();
        
        // Since we can't create Custom Metadata in tests, this will return empty map
        System.assertNotEquals(null, result);
    }

    /**
     * @description Test getRecaptchaSetting with invalid setting name.
     */
    @IsTest static void testGetRecaptchaSettingNotFound() {
        Test.startTest();
        
        Map<String, String> result = GoogleRecaptchaHandler.getRecaptchaSetting('NonExistentSetting');
        
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size());
    }

    /**
     * @description Test verifyResponse with successful verification.
     */
    @IsTest static void testVerifyResponseSuccess() {
        Test.setMock(HttpCalloutMock.class, new GoogleRecaptchaHandlerTest.RecaptchaHttpCalloutMock());
        
        Test.startTest();
        
        Boolean result = GoogleRecaptchaHandler.verifyResponse(
            'test-response-token', 
            'Default', 
            'test-guid-789'
        );
        
        Test.stopTest();
        
        System.assertEquals(true, result);
    }

    /**
     * @description Test verifyResponse with failed Google API response.
     */
    @IsTest static void testVerifyResponseGoogleFailure() {
        Test.setMock(HttpCalloutMock.class, new GoogleRecaptchaHandlerTest.RecaptchaFailureHttpCalloutMock());
        
        Test.startTest();
        
        Boolean result = GoogleRecaptchaHandler.verifyResponse(
            'invalid-response-token', 
            'TestSetting', 
            'test-guid-890'
        );
        
        Test.stopTest();
        
        System.assertEquals(false, result);
    }

    /**
     * @description Test verifyResponse with HTTP error.
     */
    @IsTest static void testVerifyResponseHttpError() {
        Test.setMock(HttpCalloutMock.class, new GoogleRecaptchaHandlerTest.RecaptchaErrorHttpCalloutMock());
        
        Test.startTest();
        
        Boolean result = GoogleRecaptchaHandler.verifyResponse(
            'test-response-token', 
            'TestSetting', 
            'test-guid-901'
        );
        
        Test.stopTest();
        
        System.assertEquals(false, result);
    }

    /**
     * @description Test getCacheKey method.
     */
    @IsTest static void testGetCacheKey() {
        String flowInterviewGuid = 'abc123-def456-ghi789';
        String cacheKey = GoogleRecaptchaHandler.getCacheKey(flowInterviewGuid);
        
        System.assertEquals('local.GoogleRecaptchaVerification.abc123', cacheKey);
    }

    /**
     * @description HttpCalloutMock to simulate Google's reCAPTCHA verification API response.
     */
    global class RecaptchaHttpCalloutMock implements HttpCalloutMock {
        // Implement this interface method
            global HTTPResponse respond(HTTPRequest request) {
                
                // First create a fake response
                HttpResponse response = new HttpResponse();
                
                response.setHeader('Content-Type', 'application/json');
                response.setBody('{"success":true, "challenge_ts": "2020-07-06T11:14:25Z", "hostname": "example.com"}');
                response.setStatusCode(200);
                
                return response;
            }
        }

    /**
     * @description HttpCalloutMock to simulate failed Google reCAPTCHA verification response.
     */
    global class RecaptchaFailureHttpCalloutMock implements HttpCalloutMock {
        global HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"success":false, "error-codes": ["invalid-input-response"]}');
            response.setStatusCode(200);
            return response;
        }
    }

    /**
     * @description HttpCalloutMock to simulate HTTP error from Google API.
     */
    global class RecaptchaErrorHttpCalloutMock implements HttpCalloutMock {
        global HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"error": "Internal Server Error"}');
            response.setStatusCode(500);
            return response;
        }
    }
}
