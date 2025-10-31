/**
 * Data selector layer for Google reCAPTCHA Custom Metadata settings.
 * @author Yi Zhang
 * @see GoogleRecaptchaSetting__mdt
 */
public with sharing class DS_GoogleRecaptchaSetting {
    /**
     * Returns the GoogleRecaptchaSetting__mdt record for the provided DeveloperName.
     * If no record is found, null is returned.
     * @param settingName The DeveloperName of the Custom Metadata record to retrieve.
     * @return GoogleRecaptchaSetting__mdt or null when no match is found.
     */
    public static GoogleRecaptchaSetting__mdt getSettingByDevName(String settingName) {
        List<GoogleRecaptchaSetting__mdt> settings = [
            SELECT SiteKey__c, SecretKey__c
            FROM GoogleRecaptchaSetting__mdt
            WHERE DeveloperName = :settingName
            LIMIT 1
        ];
        return settings.isEmpty() ? null : settings[0];
    }
}
