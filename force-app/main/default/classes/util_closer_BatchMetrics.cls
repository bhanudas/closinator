/**
 * @description Tracks and reports batch execution statistics.
 * Used to collect metrics during batch processing and generate reports.
 */
public with sharing class util_closer_BatchMetrics {
    
    private static final Integer MAX_ERRORS = 50;
    
    public Integer totalRecordsProcessed { get; set; }
    public Integer totalRecordsUpdated { get; set; }
    public Integer totalRecordsFailed { get; set; }
    public Integer totalBatchesExecuted { get; set; }
    public DateTime startTime { get; set; }
    public DateTime endTime { get; set; }
    public List<String> errors { get; set; }
    public Map<String, Integer> statusTransitionCounts { get; set; }
    
    /**
     * @description Constructor initializes all metrics to zero/empty.
     */
    public util_closer_BatchMetrics() {
        this.totalRecordsProcessed = 0;
        this.totalRecordsUpdated = 0;
        this.totalRecordsFailed = 0;
        this.totalBatchesExecuted = 0;
        this.startTime = DateTime.now();
        this.errors = new List<String>();
        this.statusTransitionCounts = new Map<String, Integer>();
    }
    
    /**
     * @description Records a successful status transition.
     * @param fromStatus The original status.
     * @param toStatus The new status.
     */
    public void recordSuccess(String fromStatus, String toStatus) {
        this.totalRecordsUpdated++;
        String transitionKey = fromStatus + ' -> ' + toStatus;
        Integer count = this.statusTransitionCounts.get(transitionKey);
        this.statusTransitionCounts.put(transitionKey, (count == null ? 0 : count) + 1);
    }
    
    /**
     * @description Records a failed record update.
     * @param errorMessage The error message.
     * @param caseId The Case ID that failed.
     */
    public void recordFailure(String errorMessage, Id caseId) {
        this.totalRecordsFailed++;
        if (this.errors.size() < MAX_ERRORS) {
            this.errors.add('Case ' + caseId + ': ' + errorMessage);
        }
    }
    
    /**
     * @description Increments the processed count.
     * @param count Number of records processed.
     */
    public void addProcessedCount(Integer count) {
        this.totalRecordsProcessed += count;
    }
    
    /**
     * @description Increments the batch count.
     */
    public void incrementBatchCount() {
        this.totalBatchesExecuted++;
    }
    
    /**
     * @description Formats metrics as HTML email content.
     * @return HTML formatted metrics.
     */
    public String toEmailBody() {
        Long durationMs = this.endTime != null 
            ? this.endTime.getTime() - this.startTime.getTime() 
            : 0;
        
        String html = '<html><body>';
        html += '<h2>Case Status Auto-Closer - Batch Completion Report</h2>';
        html += '<table border="1" cellpadding="5" cellspacing="0">';
        html += '<tr><td><strong>Start Time</strong></td><td>' + this.startTime.format('yyyy-MM-dd HH:mm:ss') + '</td></tr>';
        html += '<tr><td><strong>End Time</strong></td><td>' + (this.endTime != null ? this.endTime.format('yyyy-MM-dd HH:mm:ss') : 'N/A') + '</td></tr>';
        html += '<tr><td><strong>Duration</strong></td><td>' + formatDuration(durationMs) + '</td></tr>';
        html += '<tr><td><strong>Batches Executed</strong></td><td>' + this.totalBatchesExecuted + '</td></tr>';
        html += '<tr><td><strong>Records Processed</strong></td><td>' + this.totalRecordsProcessed + '</td></tr>';
        html += '<tr><td><strong>Records Updated</strong></td><td>' + this.totalRecordsUpdated + '</td></tr>';
        html += '<tr><td><strong>Records Failed</strong></td><td>' + this.totalRecordsFailed + '</td></tr>';
        html += '</table>';
        
        if (!this.statusTransitionCounts.isEmpty()) {
            html += '<h3>Status Transitions</h3>';
            html += '<table border="1" cellpadding="5" cellspacing="0">';
            html += '<tr><th>Transition</th><th>Count</th></tr>';
            for (String transition : this.statusTransitionCounts.keySet()) {
                html += '<tr><td>' + transition + '</td><td>' + this.statusTransitionCounts.get(transition) + '</td></tr>';
            }
            html += '</table>';
        }
        
        if (!this.errors.isEmpty()) {
            html += '<h3>Errors (' + this.errors.size() + (this.errors.size() >= MAX_ERRORS ? '+' : '') + ')</h3>';
            html += '<ul>';
            for (String err : this.errors) {
                html += '<li>' + err + '</li>';
            }
            html += '</ul>';
        }
        
        html += '</body></html>';
        return html;
    }
    
    /**
     * @description Formats metrics for debug log output.
     * @return Formatted string for logging.
     */
    public String toLogSummary() {
        return 'Batch Metrics: ' +
            'Batches=' + this.totalBatchesExecuted + ', ' +
            'Processed=' + this.totalRecordsProcessed + ', ' +
            'Updated=' + this.totalRecordsUpdated + ', ' +
            'Failed=' + this.totalRecordsFailed;
    }
    
    /**
     * @description Formats duration in human-readable format.
     * @param milliseconds Duration in milliseconds.
     * @return Formatted duration string.
     */
    private String formatDuration(Long milliseconds) {
        if (milliseconds < 1000) {
            return milliseconds + 'ms';
        }
        Long seconds = milliseconds / 1000;
        if (seconds < 60) {
            return seconds + 's';
        }
        Long minutes = seconds / 60;
        seconds = Math.mod(seconds, 60);
        return minutes + 'm ' + seconds + 's';
    }
}

