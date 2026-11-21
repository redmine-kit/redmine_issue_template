# frozen_string_literal: true

module RedmineKit
  module IssueTemplate
    # The values a template sets on a new issue, shown where the user can't
    # change them: in Redmine's form (templates/_preset_values) and in
    # the new UI's (KitForm). Each entry is the field (an attribute or a
    # custom field's id), Redmine's label of it, and the value as the issue has
    # it: a record, true or false (is_private), or a CustomFieldValue. Custom
    # fields the user can't see are left out.
    class PresetValues
      include Enumerable

      LABELS = { 'tracker_id' => :field_tracker, 'priority_id' => :field_priority, 'category_id' => :field_category,
                 'fixed_version_id' => :field_fixed_version, 'is_private' => :field_is_private }.freeze

      Entry = Struct.new(:field, :label, :value)

      # except: the fields shown elsewhere.
      def initialize(issue, user = User.current, except: [])
        @issue = issue
        @user = user
        @preset = issue.issue_template_visibility[:preset] - except
      end

      def each(&)
        entries.each(&)
      end

      private

      def entries
        @entries ||= core + custom
      end

      def core
        LABELS.filter_map do |name, label|
          Entry.new(name, ::I18n.t(label), @issue.public_send(name.delete_suffix('_id'))) if @preset.include?(name)
        end
      end

      def custom
        @issue.custom_field_values.filter_map do |value|
          field = value.custom_field
          next unless @preset.include?(field.id.to_s) && field.visible_by?(@issue.project, @user)

          Entry.new(field.id.to_s, field.name, value)
        end
      end
    end
  end
end
