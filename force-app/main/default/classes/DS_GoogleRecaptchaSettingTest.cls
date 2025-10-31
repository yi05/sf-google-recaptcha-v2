/**
 * Unit tests for DS_GoogleRecaptchaSetting.
 * @author Yi Zhang
 * @see DS_GoogleRecaptchaSetting
 */
@IsTest
private class DS_GoogleRecaptchaSettingTest {

    /**
     * Ensures a record is returned when a matching DeveloperName exists.
     */
    @IsTest
    static void testGetSettingByDevName_Found() {
        GoogleRecaptchaSetting__mdt rec = DS_GoogleRecaptchaSetting.getSettingByDevName('Default');
        System.assertNotEquals(null, rec, 'Expected a Custom Metadata record to be returned.');
    }

    /**
     * Ensures null is returned when no record matches the DeveloperName.
     */
    @IsTest
    static void testGetSettingByDevName_NotFound() {
        GoogleRecaptchaSetting__mdt rec = DS_GoogleRecaptchaSetting.getSettingByDevName('DoesNotExist');
        System.assertEquals(null, rec, 'Expected null when no matching Custom Metadata exists.');
    }
}
