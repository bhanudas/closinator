import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getJobStatus from '@salesforce/apex/util_closer_SchedulerController.getJobStatus';
import getSettings from '@salesforce/apex/util_closer_SchedulerController.getSettings';
import rescheduleJob from '@salesforce/apex/util_closer_SchedulerController.rescheduleJob';
import unscheduleJob from '@salesforce/apex/util_closer_SchedulerController.unscheduleJob';
import updateSettings from '@salesforce/apex/util_closer_SchedulerController.updateSettings';
import runBatchNow from '@salesforce/apex/util_closer_SchedulerController.runBatchNow';

const CRON_PRESETS = [
    { label: 'Daily 2 AM', value: '0 0 2 * * ?' },
    { label: 'Daily 6 AM', value: '0 0 6 * * ?' },
    { label: 'Every 6 Hours', value: '0 0 */6 * * ?' },
    { label: 'Weekdays 3 AM', value: '0 0 3 ? * MON-FRI' },
    { label: 'Weekly Sunday 1 AM', value: '0 0 1 ? * SUN' },
    { label: 'Custom', value: 'custom' }
];

export default class Util_closer_schedulerManager extends LightningElement {
    @track isLoading = true;
    @track isEditMode = false;
    @track showConfirmModal = false;
    
    // Job Status
    @track isScheduled = false;
    @track nextFireTime;
    @track jobName;
    @track cronExpression = '0 0 2 * * ?';
    @track isBatchRunning = false;
    
    // Settings
    @track batchSize = 200;
    @track debugMode = false;
    @track isActive = true;
    @track errorEmails = '';
    @track completionEmails = '';
    
    // Cron Presets
    cronPresets = CRON_PRESETS;
    @track selectedPreset = '0 0 2 * * ?';
    
    // Wire results for refresh
    wiredJobStatusResult;
    wiredSettingsResult;
    
    @wire(getJobStatus)
    wiredJobStatus(result) {
        this.wiredJobStatusResult = result;
        if (result.data) {
            this.isScheduled = result.data.isScheduled;
            this.nextFireTime = result.data.nextFireTime;
            this.jobName = result.data.jobName;
            this.isBatchRunning = result.data.isBatchRunning;
            if (result.data.cronExpression) {
                this.cronExpression = result.data.cronExpression;
                this.updatePresetFromCron();
            }
            this.isLoading = false;
        } else if (result.error) {
            this.handleError(result.error);
            this.isLoading = false;
        }
    }
    
    @wire(getSettings)
    wiredSettings(result) {
        this.wiredSettingsResult = result;
        if (result.data) {
            this.batchSize = result.data.batchSize || 200;
            this.debugMode = result.data.debugMode || false;
            this.isActive = result.data.isActive !== false;
            this.errorEmails = result.data.errorEmails || '';
            this.completionEmails = result.data.completionEmails || '';
            if (result.data.cronExpression) {
                this.cronExpression = result.data.cronExpression;
            }
        } else if (result.error) {
            this.handleError(result.error);
        }
    }
    
    get statusLabel() {
        return this.isScheduled ? 'Scheduled' : 'Not Scheduled';
    }
    
    get statusVariant() {
        return this.isScheduled ? 'success' : 'warning';
    }
    
    get formattedNextFireTime() {
        if (!this.nextFireTime) return 'N/A';
        return new Date(this.nextFireTime).toLocaleString();
    }
    
    get activeLabel() {
        return this.isActive ? 'Yes' : 'No';
    }
    
    get debugModeLabel() {
        return this.debugMode ? 'On' : 'Off';
    }
    
    get isCustomCron() {
        return this.selectedPreset === 'custom';
    }
    
    get isPresetSelected() {
        return this.selectedPreset !== 'custom';
    }
    
    get unscheduleDisabled() {
        return !this.isScheduled || this.isLoading;
    }
    
    get runNowDisabled() {
        return this.isLoading || this.isBatchRunning;
    }
    
    get scheduleButtonLabel() {
        return this.isScheduled ? 'Reschedule' : 'Schedule';
    }
    
    updatePresetFromCron() {
        const preset = this.cronPresets.find(p => p.value === this.cronExpression);
        this.selectedPreset = preset ? preset.value : 'custom';
    }
    
    handlePresetChange(event) {
        this.selectedPreset = event.detail.value;
        if (this.selectedPreset !== 'custom') {
            this.cronExpression = this.selectedPreset;
        }
    }
    
    handleCronChange(event) {
        this.cronExpression = event.target.value;
        this.selectedPreset = 'custom';
    }
    
    handleSettingChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this[field] = value;
    }
    
    handleRefresh() {
        this.isLoading = true;
        Promise.all([
            refreshApex(this.wiredJobStatusResult),
            refreshApex(this.wiredSettingsResult)
        ]).then(() => {
            this.isLoading = false;
            this.showToast('Success', 'Status refreshed', 'success');
        }).catch(error => {
            this.handleError(error);
            this.isLoading = false;
        });
    }
    
    handleSchedule() {
        this.isLoading = true;
        rescheduleJob({ cronExpression: this.cronExpression })
            .then(result => {
                this.showToast('Success', result, 'success');
                return refreshApex(this.wiredJobStatusResult);
            })
            .catch(error => {
                this.handleError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    handleUnschedule() {
        this.isLoading = true;
        unscheduleJob()
            .then(() => {
                this.showToast('Success', 'Job unscheduled successfully', 'success');
                return refreshApex(this.wiredJobStatusResult);
            })
            .catch(error => {
                this.handleError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    handleRunNowClick() {
        this.showConfirmModal = true;
    }
    
    handleConfirmRunNow() {
        this.showConfirmModal = false;
        this.isLoading = true;
        runBatchNow()
            .then(jobId => {
                this.showToast('Success', 'Batch job started. Job ID: ' + jobId, 'success');
                return refreshApex(this.wiredJobStatusResult);
            })
            .catch(error => {
                this.handleError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    handleCancelRunNow() {
        this.showConfirmModal = false;
    }
    
    handleEditSettings() {
        this.isEditMode = true;
    }
    
    handleCancelEdit() {
        this.isEditMode = false;
        // Refresh to restore original values
        refreshApex(this.wiredSettingsResult);
    }
    
    handleSaveSettings() {
        this.isLoading = true;
        
        const settingsMap = {
            batchSize: parseInt(this.batchSize, 10),
            debugMode: this.debugMode,
            isActive: this.isActive,
            cronExpression: this.cronExpression,
            errorEmails: this.errorEmails,
            completionEmails: this.completionEmails
        };
        
        updateSettings({ settingsMap: settingsMap })
            .then(() => {
                this.showToast('Success', 'Settings saved successfully', 'success');
                this.isEditMode = false;
                return refreshApex(this.wiredSettingsResult);
            })
            .catch(error => {
                this.handleError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    handleError(error) {
        let message = 'An unknown error occurred';
        if (error.body && error.body.message) {
            message = error.body.message;
        } else if (error.message) {
            message = error.message;
        }
        this.showToast('Error', message, 'error');
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}

