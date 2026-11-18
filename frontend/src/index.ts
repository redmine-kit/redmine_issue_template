// Redmine Kit Issue Template's module for Redmine Kit's new UI: the components its manifest names (init.rb's kit_ui block).
// Vite bundles these files into one ES module, ../assets/javascripts/kit/issue_template.js (vite.config.js); react,
// react/jsx-runtime and @redmine-kit/ui stay imports, which the app's import map resolves to its own.
export { IssueTemplateChooser } from './IssueTemplateChooser';
export { IssueTemplateSection } from './IssueTemplateSection';
export { IssueTemplateFields } from './IssueTemplateFields';
export { IssueTemplateSettings } from './IssueTemplateSettings';
export { IssueTemplateEdit } from './IssueTemplateEdit';
