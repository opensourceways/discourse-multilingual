import DropdownSelectBoxHeaderComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-header";
import computed from "ember-addons/ember-computed-decorators";

export default DropdownSelectBoxHeaderComponent.extend({
  @computed("currentUser.content_languages")
  btnClassName(contentLanguages) {
    let extraClass = contentLanguages && contentLanguages.length ? 'has-languages' : '';
    return `btn no-text btn-icon ${extraClass}`;
  }
});
