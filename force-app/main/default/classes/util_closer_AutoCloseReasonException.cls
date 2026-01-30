/**
 * @description Custom exception thrown when Auto Close Reason configuration is invalid.
 * This exception is thrown when:
 * - Auto Close Reason is enabled but no field is configured
 * - The configured field does not exist on the Case object
 */
public class util_closer_AutoCloseReasonException extends Exception {
}
