import { useState, type ReactNode } from 'react';
import { render } from '@testing-library/react';
import { NewIssuePartContext } from '@redmine-kit/plugin/host';
import type { NewIssueParamValue, NewIssueParams } from '@redmine-kit/plugin';
import { KitTestHost, type KitTestHostProps } from '@redmine-kit/plugin/testing';
import { kitCatalog } from '@redmine-kit/plugin/locales';

// A component of the module in a test, with the app's part (KitTestHost): the strings as Redmine loads them (Redmine
// 7.0.3's and redmine_kit_ui's, then the plugin's config/locales), the same as its Storybook's, and the permissions given.
// renderPart draws a component of the new issue's part with the form's side of it (the part's data, parameters, state,
// messages), as the app's form gives them.

export const JA = kitCatalog('ja');
export const EN = kitCatalog('en');

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
