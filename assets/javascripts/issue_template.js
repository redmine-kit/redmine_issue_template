// Redmine sets up dropping files on the file fields of a page once, when the
// page loads (setupFileDrop in attachments.js), and has no call to set up
// the fields of the issue form it renders again on each update. A form's
// upload fields are in that part, so this sets the new fields up after each
// request; setupFileDrop leaves the fields already set up as they are.
$(document).ajaxComplete(function() {
  if (typeof setupFileDrop === 'function') { setupFileDrop(); }
});
