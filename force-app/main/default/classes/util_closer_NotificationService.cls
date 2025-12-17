/**
 * @description Handles all email notifications for errors and completion reports.
 * Sends formatted HTML emails to configured recipients.
 */
public with sharing class util_closer_NotificationService {
    
    /**
     * @description Sends an error notification email.
     * @param subject The email subject.
     * @param body The email body.
     * @param ex The exception that occurred.
     */
    public static void sendErrorNotification(String subject, String body, Exception ex) {
        List<String> recipients = util_closer_SettingsService.getErrorEmails();
        
        if (recipients.isEmpty()) {
            util_closer_Logger.debug('NotificationService', 'No error notification recipients configured');
            return;
        }
        
        String htmlBody = buildErrorEmailBody(body, ex);
        String fullSubject = buildSubject('ERROR: ' + subject);
        
        sendEmail(recipients, fullSubject, htmlBody);
    }
    
    /**
     * @description Sends a completion report email.
     * @param metrics The batch metrics to include in the report.
     */
    public static void sendCompletionReport(util_closer_BatchMetrics metrics) {
        List<String> recipients = util_closer_SettingsService.getCompletionEmails();
        
        if (recipients.isEmpty()) {
            util_closer_Logger.debug('NotificationService', 'No completion notification recipients configured');
            return;
        }
        
        String subject = buildSubject('Batch Completion Report');
        String htmlBody = metrics.toEmailBody();
        
        sendEmail(recipients, subject, htmlBody);
    }
    
    /**
     * @description Builds the email subject with org information.
     * @param baseSubject The base subject line.
     * @return Full subject with org details.
     */
    private static String buildSubject(String baseSubject) {
        String orgName = UserInfo.getOrganizationName();
        return '[Case Auto-Closer] ' + baseSubject + ' - ' + orgName;
    }
    
    /**
     * @description Builds the HTML body for error emails.
     * @param body The error message.
     * @param ex The exception.
     * @return Formatted HTML body.
     */
    private static String buildErrorEmailBody(String body, Exception ex) {
        String html = '<html><body>';
        html += '<h2>Case Status Auto-Closer - Error Notification</h2>';
        html += '<p><strong>Time:</strong> ' + DateTime.now().format('yyyy-MM-dd HH:mm:ss') + '</p>';
        html += '<p><strong>Organization:</strong> ' + UserInfo.getOrganizationName() + '</p>';
        html += '<h3>Error Details</h3>';
        html += '<p>' + String.valueOf(body).escapeHtml4() + '</p>';
        
        if (ex != null) {
            html += '<h3>Exception Information</h3>';
            html += '<table border="1" cellpadding="5" cellspacing="0">';
            html += '<tr><td><strong>Type</strong></td><td>' + ex.getTypeName() + '</td></tr>';
            html += '<tr><td><strong>Message</strong></td><td>' + String.valueOf(ex.getMessage()).escapeHtml4() + '</td></tr>';
            html += '<tr><td><strong>Line Number</strong></td><td>' + ex.getLineNumber() + '</td></tr>';
            html += '</table>';
            html += '<h4>Stack Trace</h4>';
            html += '<pre>' + String.valueOf(ex.getStackTraceString()).escapeHtml4() + '</pre>';
        }
        
        html += '</body></html>';
        return html;
    }
    
    /**
     * @description Sends an HTML email to the specified recipients.
     * @param recipients List of email addresses.
     * @param subject Email subject.
     * @param htmlBody HTML email body.
     */
    private static void sendEmail(List<String> recipients, String subject, String htmlBody) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(recipients);
            email.setSubject(subject);
            email.setHtmlBody(htmlBody);
            email.setSaveAsActivity(false);
            
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
            
            util_closer_Logger.debug('NotificationService', 'Email sent to ' + recipients.size() + ' recipients');
        } catch (Exception ex) {
            util_closer_Logger.error('Failed to send email notification', ex);
        }
    }
}

