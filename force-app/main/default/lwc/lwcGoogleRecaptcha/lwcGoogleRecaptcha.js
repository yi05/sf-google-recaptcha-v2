import { LightningElement, api, track } from "lwc";
import fetchBaseURL from "@salesforce/apex/GoogleRecaptchaHandler.fetchBaseURL";
import getRecaptchaSetting from "@salesforce/apex/GoogleRecaptchaHandler.getRecaptchaSetting";
import verifyResponse from "@salesforce/apex/GoogleRecaptchaHandler.verifyResponse";
import GOOGLE_RECAPTCHA from "@salesforce/resourceUrl/Google_Recaptcha";

/**
 * Lightning Web Component for Google reCAPTCHA v2 checkbox integration
 *
 * This component renders a Google reCAPTCHA v2 checkbox within an iframe and handles
 * verification with server-side validation. It is designed to work with Salesforce
 * Flows and can be used in communities, Lightning pages, and external pages with Lightning Out.
 *
 * @component lwcGoogleRecaptcha
 * @implements lightning:availableForFlowScreens
 * @access global
 *
 * @example
 * <c-lwc-google-recaptcha
 *     is-human={isHuman}
 *     google-recaptcha-setting-name="Portal1GoogleRecaptchaSetting"
 *     origin-page-url="https://example.com"
 *     required={true}
 *     required-message="Please complete the captcha"
 *     required-once={false}
 *     frame-title="I'm not a robot captcha"
 *     flow-guid={flowGuid}
 * ></c-lwc-google-recaptcha>
 *
 * @author Salesforce Community
 * @version 2.0.0
 * @since 48.0
 */
export default class LwcGoogleRecaptcha extends LightningElement {
  /**
   * Internal tracked state for human verification
   * @type {boolean}
   * @private
   */
  @track _isHuman = false;

  /**
   * Indicates whether the user has been verified as human
   * @type {boolean}
   * @default false
   * @public
   */
  @api
  get isHuman() {
    return this._isHuman;
  }
  set isHuman(value) {
    this._isHuman = value;
  }

  /**
   * Name of the Google reCAPTCHA Setting (Custom Metadata Type record)
   * This is required to retrieve the site key securely from the server
   * @type {string}
   * @required
   * @public
   */
  @api googleRecaptchaSettingName;

  /**
   * Comma-separated list of origin page URLs where the component is deployed
   * Used for security validation of postMessage communications
   * @type {string}
   * @public
   */
  @api originPageURL;

  /**
   * Whether the reCAPTCHA is required to proceed
   * @type {boolean}
   * @default false
   * @public
   */
  @api required = false;

  /**
   * Custom error message displayed when required validation fails
   * @type {string}
   * @public
   */
  @api requiredMessage;

  /**
   * If true, the reCAPTCHA will only appear once and remain validated
   * @type {boolean}
   * @default false
   * @public
   */
  @api requiredOnce = false;

  /**
   * Title for the iframe element (for accessibility)
   * @type {string}
   * @public
   */
  @api frameTitle;

  /**
   * Flow Interview GUID for server-side verification
   * @type {string}
   * @public
   */
  @api flowGuid;

  /**
   * Array of allowed URLs for postMessage security
   * @type {string[]}
   * @private
   */
  @track allowedURLs = [];

  /**
   * Response token from reCAPTCHA
   * @type {string}
   * @private
   */
  @track recaptchaResponse = "";

  /**
   * Site key fetched from Custom Metadata Type
   * @type {string}
   * @private
   */
  @track siteKey = null;

  /**
   * Bound event handler for window messages
   * @type {Function}
   * @private
   */
  boundMessageHandler = null;

  /**
   * Lifecycle hook - Called when component is inserted into DOM
   * Initializes the component and sets up message listeners
   * @private
   */
  connectedCallback() {
    this.initializeComponent();
    this.setupMessageListener();
  }

  /**
   * Lifecycle hook - Called when component is removed from DOM
   * Cleans up message listeners
   * @private
   */
  disconnectedCallback() {
    this.removeMessageListener();
  }

  /**
   * Computes whether the captcha should be displayed based on requiredOnce, isHuman, and siteKey
   * @returns {boolean} True if captcha should be displayed
   * @readonly
   * @private
   */
  get shouldDisplayCaptcha() {
    // Only display if siteKey is available
    if (!this.siteKey) {
      return false;
    }
    
    if (this.requiredOnce) {
      return !this._isHuman;
    }
    return true;
  }

  /**
   * Computes the iframe source URL with site key and frame title parameters
   * @returns {string} Complete iframe source URL
   * @readonly
   * @private
   */
  get iframeSrc() {
    const title = encodeURIComponent(
      this.frameTitle || "I'm not a robot captcha"
    );
    return `${GOOGLE_RECAPTCHA}?sitekey=${this.siteKey}&#38;title=${title}`;
  }

  /**
   * Initializes component state and fetches allowed URLs and reCAPTCHA settings
   * @private
   */
  initializeComponent() {
    // Reset isHuman if not requiredOnce
    if (!this.requiredOnce) {
      this._isHuman = false;
    }

    // Parse originPageURL
    const allowedURLs = [];
    if (this.originPageURL) {
      const urls = this.originPageURL.split(",");
      urls.forEach((url) => {
        allowedURLs.push(url.trim());
      });
    }

    // Fetch base URLs from Salesforce
    fetchBaseURL()
      .then((records) => {
        this.allowedURLs = [...allowedURLs, ...records];
      })
      .catch((error) => {
        console.error("ERROR fetching base URLs:", error);
      });

    // Fetch reCAPTCHA settings from Custom Metadata Type
    if (this.googleRecaptchaSettingName) {
      getRecaptchaSetting({ settingName: this.googleRecaptchaSettingName })
        .then((result) => {
          if (result && result.siteKey) {
            this.siteKey = result.siteKey;
          } else {
            console.error(
              "No reCAPTCHA settings found for: " +
                this.googleRecaptchaSettingName
            );
          }
        })
        .catch((error) => {
          console.error("ERROR fetching reCAPTCHA settings:", error);
        });
    } else {
      console.error(
        "googleRecaptchaSettingName is required but not provided"
      );
    }
  }

  /**
   * Sets up the window message event listener
   * @private
   */
  setupMessageListener() {
    this.boundMessageHandler = this.handleMessage.bind(this);
    window.addEventListener("message", this.boundMessageHandler, false);
  }

  /**
   * Removes the window message event listener
   * @private
   */
  removeMessageListener() {
    if (this.boundMessageHandler) {
      window.removeEventListener("message", this.boundMessageHandler, false);
    }
  }

  /**
   * Handles postMessage events from the reCAPTCHA iframe
   * Validates message origin and processes captcha events
   * @param {MessageEvent} event - The message event from the iframe
   * @private
   */
  handleMessage(event) {
    // Security check - validate origin
    if (!this.isAllowedOrigin(event.origin)) {
      return;
    }

    // Extract event data
    const eventName = event.data[0];
    const data = event.data[1];

    // Get iframe element
    const iframe = this.template.querySelector('[data-id="captchaFrame"]');
    if (!iframe) {
      return;
    }

    // Process different event types
    switch (eventName) {
      case "setHeight":
        iframe.height = data;
        break;
      case "setWidth":
        iframe.width = data;
        break;
      case "Lock":
        this._isHuman = false;
        break;
      case "Unlock":
        this.handleUnlock(data);
        break;
      default:
        // Unknown event type
        break;
    }
  }

  /**
   * Validates if the message origin is in the allowed URLs list
   * @param {string} origin - The origin URL to validate
   * @returns {boolean} True if origin is allowed
   * @private
   */
  isAllowedOrigin(origin) {
    if (!this.allowedURLs || this.allowedURLs.length === 0) {
      return false;
    }
    return this.allowedURLs.includes(origin);
  }

  /**
   * Handles the Unlock event when user completes reCAPTCHA
   * Always performs server-side verification for security
   * @param {string} response - The reCAPTCHA response token
   * @private
   */
  handleUnlock(response) {
    this.recaptchaResponse = response;

    // Always perform server-side verification for security
    const params = {
      recaptchaResponse: this.recaptchaResponse,
      recaptchaSettingName: this.googleRecaptchaSettingName,
      flowInterviewGuid: this.flowGuid
    };

    verifyResponse(params)
      .then((result) => {
        if (result === true) {
          // Add delay for requiredOnce animation
          if (this.requiredOnce) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
              this._isHuman = true;
            }, 500);
          } else {
            this._isHuman = true;
          }
        }
      })
      .catch((error) => {
        console.error("ERROR verifying reCAPTCHA:", error);
      });
  }

  /**
   * Public validation method for Flow screens
   * Validates if the reCAPTCHA has been completed when required
   * @returns {Object} Validation result with isValid flag and optional errorMessage
   * @public
   */
  @api
  validate() {
    const errorMessage = this.requiredMessage || "Please complete the captcha";

    if (this.required && !this._isHuman) {
      return {
        isValid: false,
        errorMessage: errorMessage
      };
    }

    return { isValid: true };
  }
}
