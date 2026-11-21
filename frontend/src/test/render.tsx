import { useState, type ReactNode } from 'react';
import { render } from '@testing-library/react';
import { NewIssuePartContext } from '@redmine-kit/plugin/host';
import type { NewIssueParamValue, NewIssueParams } from '@redmine-kit/plugin';
import { KitTestHost, type KitTestHostProps } from '@redmine-kit/plugin/testing';
import ja from '../../../config/locales/ja.yml?raw';
import en from '../../../config/locales/en.yml?raw';

// A component of the module in a test, with the app's part (KitTestHost): the plugin's strings from its locale files
// (config/locales/{ja,en}.yml, flat; a plural as its `other` form), Redmine's few strings the components use, the
// permissions given. renderPart draws a component of the new issue's part with the form's side of it (the part's data,
// parameters, state, messages), as the app's form gives them.

/** The plugin's strings of a language: `key: value` lines, and a plural's `other` under its key. */
function strings(yml: string): Record<string, string> {
  const out: Record<string, string> = {};
  let plural = '';
  for (const line of yml.split('\n')) {
    const top = /^ {2}([a-z_0-9]+):\s*(.*)$/.exec(line);
    const sub = /^ {4}other:\s*(.*)$/.exec(line);
    const value = (v: string) => v.replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1');
    if (top) {
      plural = top[2] ? '' : top[1];
      if (top[2]) out[top[1]] = value(top[2]);
    } else if (sub && plural) out[plural] = value(sub[1]);
  }
  return out;
}

/** Redmine 7.0.3's strings (config/locales/ja.yml) and the app's the components use. */
const REDMINE_JA: Record<string, string> = {
  'activerecord.errors.messages.blank': 'を入力してください',
  actionview_instancetag_blank_option: '選んでください',
  button_save: '保存',
  button_create: '作成',
  button_cancel: 'キャンセル',
  button_import: 'インポート',
  button_edit: '編集',
  button_delete: '削除',
  field_subject: '題名',
  field_priority: '優先度',
  field_filename: 'ファイル名',
  field_updated_on: '更新日',
  label_revision: 'リビジョン',
  label_repository: 'リポジトリ',
  label_alert_warning: '警告',
  label_help: 'ヘルプ',
  label_settings: '設定',
  label_preview: 'プレビュー',
  field_content: '内容',
  'kit.new_issue.sidebar': '新しいチケットの補助',
  'kit.common.no_changes': '変更はありません',
  'support.array.words_connector': '、',
};

export const JA = { ...REDMINE_JA, ...strings(ja) };
export const EN = strings(en);

export function renderKit(ui: ReactNode, { lang = 'ja', ...props }: Omit<KitTestHostProps, 'children'> & { lang?: 'ja' | 'en' } = {}) {
  return render(
    <KitTestHost strings={lang} t={lang === 'ja' ? JA : EN} {...props}>
      {ui}
    </KitTestHost>,
  );
}

/** What the form gave and got: the parameters, the state and the messages, as the test reads them after each change. */
export interface PartForm {
  params: NewIssueParams;
  state: unknown;
  missing: string[];
}

/** The form's side of a part: its own parameters, state and messages (the app's useNewIssueParams), in a component. */
function PartHost({ data, params: first, state: firstState, showErrors, form, children }: { data: unknown; params: NewIssueParams; state?: unknown; showErrors: boolean; form: PartForm; children: ReactNode }) {
  const [params, setParamsState] = useState<NewIssueParams>(first);
  const [state, setStateValue] = useState<unknown>(firstState);
  form.params = params;
  form.state = state;
  const setParams = (next: Record<string, NewIssueParamValue | null | undefined>) =>
    setParamsState((current) => {
      const merged = { ...current };
      Object.entries(next).forEach(([name, value]) => (value == null ? delete merged[name] : (merged[name] = value)));
      return merged;
    });
  return (
    <NewIssuePartContext
      value={{ data: data as Record<string, unknown>, params, setParams, state, setState: setStateValue, setMissing: (messages) => (form.missing = messages), showErrors }}
    >
      {children}
    </NewIssuePartContext>
  );
}

/** A component of the new issue's part with its data, parameters and state, in the test host. */
export function renderPart(
  ui: ReactNode,
  { data, params = {}, state, showErrors = false, ...props }: Omit<KitTestHostProps, 'children'> & { data: unknown; params?: NewIssueParams; state?: unknown; showErrors?: boolean },
) {
  const form: PartForm = { params, state, missing: [] };
  const view = renderKit(
    <PartHost data={data} params={params} state={state} showErrors={showErrors} form={form}>
      {ui}
    </PartHost>,
    props,
  );
  return { ...view, form };
}
