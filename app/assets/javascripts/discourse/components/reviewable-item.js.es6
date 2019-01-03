import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import computed from "ember-addons/ember-computed-decorators";

let _components = {};

export default Ember.Component.extend({
  tagName: "",
  updating: null,

  // Find a component to render, if one exists. For example:
  // `ReviewableUser` will return `reviewable-user`
  @computed("reviewable.type")
  reviewableComponent(type) {
    if (_components[type] !== undefined) {
      return _components[type];
    }

    let dasherized = Ember.String.dasherize(type);
    let template = Ember.TEMPLATES[`components/${dasherized}`];
    if (template) {
      _components[type] = dasherized;
      return dasherized;
    }
    _components[type] = null;
  },

  actions: {
    perform(actionId) {
      let reviewable = this.get("reviewable");
      this.set("updating", true);
      ajax(`/review/${reviewable.id}/perform/${actionId}`, { method: "PUT" })
        .then(result => {
          if (result.reviewable_perform_result.success) {
            this.attrs.remove(reviewable);
          } else {
            throw `perform failed ${actionId} on ${reviewable.id}`;
          }
        })
        .catch(popupAjaxError)
        .finally(() => {
          this.set("updating", false);
        });
    }
  }
});
