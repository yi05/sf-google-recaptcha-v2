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
}
