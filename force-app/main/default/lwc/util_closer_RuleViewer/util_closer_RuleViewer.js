import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getActiveRules from '@salesforce/apex/util_closer_RuleViewerController.getActiveRules';

export default class Util_closer_RuleViewer extends LightningElement {
    @track isExpanded = false;
    @track rules = [];
    @track isLoading = true;
    @track error;

    wiredRulesResult;

    @wire(getActiveRules)
    wiredRules(result) {
        this.wiredRulesResult = result;
        if (result.data) {
            this.rules = result.data;
            this.error = undefined;
            this.isLoading = false;
        } else if (result.error) {
            this.error = result.error;
            this.rules = [];
            this.isLoading = false;
        }
    }

    get ruleCount() {
        return this.rules.length;
    }

    get ruleCountLabel() {
        return `${this.ruleCount} Active`;
    }

    get hasRules() {
        return this.rules.length > 0;
    }

    get hasNoRules() {
        return !this.isLoading && this.rules.length === 0;
    }

    get hasError() {
        return this.error !== undefined && this.error !== null;
    }

    get errorMessage() {
        if (!this.error) return '';
        if (this.error.body && this.error.body.message) {
            return this.error.body.message;
        }
        if (this.error.message) {
            return this.error.message;
        }
        return 'An unknown error occurred';
    }

    get expandIcon() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get expandLabel() {
        return this.isExpanded ? 'Collapse rules' : 'Expand rules';
    }

    get showRules() {
        return this.isExpanded && this.hasRules;
    }

    get formattedRules() {
        return this.rules.map(rule => {
            const timingParts = [];
            if (rule.daysSinceLastModified) {
                timingParts.push(rule.daysSinceLastModified + 'd modified');
            }
            if (rule.daysSinceCreated) {
                timingParts.push(rule.daysSinceCreated + 'd created');
            }
            if (rule.daysSinceLastActivity) {
                timingParts.push(rule.daysSinceLastActivity + 'd activity');
            }

            const timingSummary = timingParts.length > 0
                ? ' | ' + timingParts.join(', ')
                : '';

            return {
                ...rule,
                sectionLabel: '#' + rule.executionOrder + ' — ' + rule.label +
                    ' | ' + rule.sourceStatus + ' → ' + rule.targetStatus +
                    timingSummary,
                hasTimingCriteria: rule.daysSinceLastModified != null ||
                    rule.daysSinceCreated != null ||
                    rule.daysSinceLastActivity != null,
                hasFilterCriteria: rule.recordTypeDeveloperNames != null ||
                    rule.excludeRecordTypeDeveloperNames != null ||
                    rule.origins != null ||
                    rule.ownerNameLike != null ||
                    rule.lastModifiedByNameLike != null ||
                    rule.additionalFilterLogic != null,
                hasChildCriteria: rule.childObjectApiName != null ||
                    rule.childLookupField != null ||
                    rule.childFilterField != null ||
                    rule.childFilterValue != null ||
                    rule.childFilterOperator != null ||
                    rule.requireChildRecord === true
            };
        });
    }

    handleToggleExpand() {
        this.isExpanded = !this.isExpanded;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredRulesResult)
            .then(() => {
                this.isLoading = false;
                this.showToast('Success', 'Rules refreshed', 'success');
            })
            .catch(error => {
                this.handleError(error);
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
