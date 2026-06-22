import {dispatchCommand} from "../../utils";
import {Modal} from "flowbite";

export default class ActivityEdit {
    constructor(rootNode) {
        this.rootNode = rootNode;
        this.modalEl = rootNode.querySelector('#activity-edit-modal');
        this.form = rootNode.querySelector('#activity-edit-form');
    }

    init() {
        if (!this.modalEl || !this.form) return;

        const modal = new Modal(this.modalEl);

        this.rootNode.querySelectorAll('[data-activity-edit-open]').forEach((button) => {
            button.addEventListener('click', () => {
                this.clearError();
                this.form.elements.activityId.value = button.dataset.activityId;
                this.form.elements.name.value = button.dataset.name;
                this.form.elements.description.value = button.dataset.description;
                this.form.elements.sportType.value = button.dataset.sportType;
                this.form.elements.distance.value = button.dataset.distance;
                this.form.elements.elevation.value = button.dataset.elevation;
                this.form.elements.gearId.value = button.dataset.gearId;
                this.form.elements.isCommute.checked = button.dataset.isCommute === '1';
                modal.show();
            });
        });

        this.modalEl.querySelectorAll('[data-modal-hide]').forEach((button) => {
            button.addEventListener('click', () => modal.hide());
        });

        this.form.addEventListener('submit', async (event) => {
            event.preventDefault();
            this.clearError();

            try {
                await dispatchCommand('edit-activity', {
                    activityId: this.form.elements.activityId.value,
                    name: this.form.elements.name.value,
                    description: this.form.elements.description.value,
                    sportType: this.form.elements.sportType.value,
                    distance: parseFloat(this.form.elements.distance.value),
                    elevation: parseFloat(this.form.elements.elevation.value),
                    gearId: this.form.elements.gearId.value,
                    isCommute: this.form.elements.isCommute.checked,
                });
                window.location.reload();
            } catch (error) {
                this.showError(error.message);
            }
        });

        this.rootNode.querySelectorAll('[data-activity-revert]').forEach((button) => {
            button.addEventListener('click', async () => {
                if (!window.confirm('Revert this activity to its original Strava data?')) {
                    return;
                }
                try {
                    await dispatchCommand('revert-activity-override', {
                        activityId: button.dataset.activityId,
                    });
                    window.location.reload();
                } catch (error) {
                    window.alert(error.message);
                }
            });
        });
    }

    showError(message) {
        let errorEl = this.form.querySelector('[data-form-error]');
        if (!errorEl) {
            errorEl = document.createElement('div');
            errorEl.setAttribute('data-form-error', '');
            errorEl.className = 'text-sm text-red-600';
            this.form.prepend(errorEl);
        }
        errorEl.textContent = message;
    }

    clearError() {
        this.form.querySelector('[data-form-error]')?.remove();
    }
}
