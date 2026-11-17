// Redmine Issue Template's module for Redmine Kit's new UI, built from frontend/src by `npm run build`
// (frontend/vite.config.js). Edit the source, not this file. React and @redmine-kit/ui come from the app.
import { ApiError, AttrGrid, Badge, Button, Card, CardBody, CardHeader, CardSection, Checkbox, CheckboxGroup, ConfirmDialog, EmptyState, ErrorState, FormActions, FormActionsSkeleton, FormRow, Icon, IconButton, Input, ListRow, Notice, Prose, SectionHeading, Select, Skeleton, SkeletonRegion, Textarea, kitApi, useExtensionContext, useKitNavigate, useKitQuery, useNewIssueExtension, useT } from "@redmine-kit/ui";
import { Fragment, jsx, jsxs } from "react/jsx-runtime";
import { useEffect, useState } from "react";
// src/api.ts
var base = (project) => `/projects/${encodeURIComponent(project.identifier)}/issue_templates`;
var settingsPath = (project) => `${base(project)}.json`;
var filePath = (project, id) => `${base(project)}/${encodeURIComponent(String(id))}.json`;
var chooserSettingsPath = (project) => `${base(project)}/settings.json`;
var syncPath = (project) => `${base(project)}/sync.json`;
/** the pages the app draws (init.rb's screens) and Redmine's settings tab */
var newPage = (project) => `${base(project)}/new`;
var editPage = (project, id) => `${base(project)}/${id}/edit`;
var tabPage = (project) => `/projects/${encodeURIComponent(project.identifier)}/settings/issue_templates`;
/** A contact link's URL, only when it is a web page (a link of any other scheme stays text). */
var webUrl = (url) => /^https?:\/\//i.test(url) ? url : void 0;
// src/IssueTemplateChooser.tsx
var hostOf = (url) => url.replace(/^https?:\/\//, "").replace(/\/$/, "");
function IssueTemplateChooser() {
	const t = useT();
	const { data, setParams } = useNewIssueExtension();
	const choose = (key) => setParams({
		issue_template: key,
		issue_template_answers: null
	});
	return /* @__PURE__ */ jsxs("div", {
		className: "flex min-w-0 flex-col",
		children: [
			/* @__PURE__ */ jsx(SectionHeading, {
				heading: t("label_issue_template_plural"),
				count: data.templates.length,
				inset: 24
			}),
			/* @__PURE__ */ jsxs("div", {
				className: "flex flex-col",
				children: [data.templates.map((template) => /* @__PURE__ */ jsx(ListRow, {
					id: template.key,
					icon: template.kind === "form" ? "grid" : "document",
					title: template.name,
					sub: template.about || void 0,
					onSelect: choose,
					inset: 24,
					size: 44,
					divider: true,
					cols: [{
						content: template.tracker ?? "",
						kind: "text",
						width: 88
					}, {
						content: template.kind === "form" ? t("label_issue_template_form") : "Markdown",
						kind: "muted",
						width: 72
					}],
					cta: t("label_issue_template_start")
				}, template.key)), data.blank && /* @__PURE__ */ jsx(ListRow, {
					id: "blank",
					icon: "plus",
					title: t("label_issue_template_blank"),
					sub: t("text_issue_template_blank_info"),
					onSelect: choose,
					inset: 24,
					size: 44,
					cta: t("label_issue_template_start")
				})]
			}),
			data.contact_links.length > 0 && /* @__PURE__ */ jsx(CardSection, {
				heading: t("label_issue_template_contact_links"),
				count: data.contact_links.length,
				inset: 24,
				level: 3,
				className: "flex flex-col",
				children: data.contact_links.map((link) => /* @__PURE__ */ jsx(ListRow, {
					icon: "link",
					title: link.name,
					href: webUrl(link.url),
					target: webUrl(link.url) ? "_blank" : void 0,
					sub: link.about || void 0,
					inset: 24,
					size: 44,
					cols: [{
						content: hostOf(link.url),
						kind: "muted"
					}, {
						content: /* @__PURE__ */ jsx(Icon, {
							name: "external",
							size: 13
						}),
						kind: "muted"
					}]
				}, link.name + link.url))
			})
		]
	});
}
// src/IssueTemplateSection.tsx
function IssueTemplateSection() {
	const t = useT();
	const { data, params, setParams } = useNewIssueExtension();
	const change = () => setParams({
		issue_template: null,
		issue_template_answers: null
	});
	const answers = params.issue_template_answers ?? {};
	const fields = (data.elements ?? []).filter((element) => element.type !== "markdown");
	const starting = JSON.stringify(Object.fromEntries(fields.flatMap((field) => "value" in field && field.value != null ? [[field.ref, field.value]] : [])));
	useEffect(() => {
		if (params.issue_template_answers === void 0 && starting !== "{}") setParams({ issue_template_answers: JSON.parse(starting) });
	}, [
		starting,
		params.issue_template_answers,
		setParams
	]);
	const answer = (ref, value) => setParams({ issue_template_answers: {
		...answers,
		[ref]: value
	} });
	const template = data.template;
	return /* @__PURE__ */ jsxs("div", {
		className: "flex min-w-0 flex-col gap-4",
		children: [
			/* @__PURE__ */ jsxs("div", {
				className: "flex min-h-8 min-w-0 items-center gap-2.5",
				children: [
					/* @__PURE__ */ jsx(Icon, {
						name: data.blank ? "plus" : template?.kind === "form" ? "grid" : "document",
						size: 16
					}),
					/* @__PURE__ */ jsx("span", {
						className: "min-w-0 truncate font-medium",
						children: data.blank ? t("label_issue_template_blank") : template?.name
					}),
					template && /* @__PURE__ */ jsx("span", {
						className: "flex-none text-meta text-text-muted",
						children: template.kind === "form" ? t("label_issue_template_form") : "Markdown"
					}),
					/* @__PURE__ */ jsx("span", { className: "flex-1" }),
					/* @__PURE__ */ jsx(Button, {
						size: 28,
						variant: "ghost",
						onClick: change,
						children: t("button_change")
					})
				]
			}),
			template?.about && /* @__PURE__ */ jsx(Prose, { text: template.about }),
			data.preset && data.preset.length > 0 && /* @__PURE__ */ jsx(AttrGrid, { items: data.preset.map((item) => ({
				label: item.label,
				value: item.value
			})) }),
			(data.elements ?? []).map((element, index) => element.type === "markdown" ? /* @__PURE__ */ jsx(Prose, { text: element.text }, `markdown-${index}`) : /* @__PURE__ */ jsx(FieldRow, {
				field: element,
				value: answers[element.ref],
				onChange: (value) => answer(element.ref, value)
			}, element.ref))
		]
	});
}
var asList = (value) => Array.isArray(value) ? value : value ? [value] : [];
var asText = (value) => typeof value === "string" ? value : "";
/** One field of a YAML form, with the app's form parts. */
function FieldRow({ field, value, onChange }) {
	const t = useT();
	const row = (control) => /* @__PURE__ */ jsx(FormRow, {
		layout: "stack",
		label: field.label,
		required: field.required,
		hint: hint(field),
		children: control
	});
	switch (field.type) {
		case "input": return row(/* @__PURE__ */ jsx(Input, {
			value: asText(value),
			placeholder: field.placeholder || void 0,
			onChange: (event) => onChange(event.target.value)
		}));
		case "textarea": return row(/* @__PURE__ */ jsx(Textarea, {
			rows: 4,
			mono: field.render,
			value: asText(value),
			placeholder: field.placeholder || void 0,
			onChange: (event) => onChange(event.target.value)
		}));
		case "dropdown": return field.multiple ? row(/* @__PURE__ */ jsx(Choices, {
			options: field.options,
			value: asList(value),
			onChange
		})) : row(/* @__PURE__ */ jsx(Select, {
			label: field.label,
			options: [...field.blank ? [{
				value: "",
				label: t("actionview_instancetag_blank_option")
			}] : [], ...field.options],
			value: asText(value),
			onValueChange: (next) => onChange(next)
		}));
		case "checkboxes": return row(/* @__PURE__ */ jsx(Choices, {
			options: field.options,
			value: asList(value),
			onChange
		}));
		case "link":
			if (field.kind === "select") return field.multiple ? row(/* @__PURE__ */ jsx(Choices, {
				options: field.options ?? [],
				value: asList(value),
				onChange
			})) : row(/* @__PURE__ */ jsx(Select, {
				label: field.label,
				options: [{
					value: "",
					label: t("actionview_instancetag_blank_option")
				}, ...field.options ?? []],
				value: asText(value),
				onValueChange: (next) => onChange(next)
			}));
			if (field.kind === "textarea") return row(/* @__PURE__ */ jsx(Textarea, {
				rows: 4,
				value: asText(value),
				placeholder: field.placeholder || void 0,
				onChange: (event) => onChange(event.target.value)
			}));
			return row(/* @__PURE__ */ jsx(Input, {
				type: field.kind === "date" ? "date" : "text",
				value: asText(value),
				placeholder: field.placeholder || void 0,
				onChange: (event) => onChange(event.target.value)
			}));
		case "upload": return row(/* @__PURE__ */ jsx(Notice, {
			tone: "warning",
			inset: 0,
			wrap: true,
			text: t("text_issue_template_upload_unavailable")
		}));
	}
}
/** Checkboxes for the options of a field with several answers. */
function Choices({ options, value, onChange }) {
	return /* @__PURE__ */ jsx(CheckboxGroup, { children: options.map((option) => /* @__PURE__ */ jsx(Checkbox, {
		label: option.required ? `${option.label} *` : option.label,
		checked: value.includes(option.value),
		onCheckedChange: (checked) => onChange(checked === true ? [...value, option.value] : value.filter((item) => item !== option.value))
	}, option.value)) });
}
/** A field's description, and the extensions an upload field takes. */
function hint(field) {
	return [field.description, field.accept?.length ? field.accept.join(", ") : ""].filter(Boolean).join(" · ") || void 0;
}
// src/IssueTemplateSettings.tsx
var DOCS = "https://redmine-kit.github.io/redmine_issue_template/";
function IssueTemplateSettings() {
	const t = useT();
	const { project } = useExtensionContext();
	const query = useKitQuery(project && settingsPath(project));
	const [notice, setNotice] = useState(null);
	const [deleting, setDeleting] = useState(null);
	if (!project) return null;
	if (query.isPending) return /* @__PURE__ */ jsx(SettingsSkeleton, {});
	if (query.isError) return /* @__PURE__ */ jsx(Notice, {
		tone: "warning",
		text: t("kit.error.load_failed")
	});
	const data = query.data.issue_templates;
	const fail = (error) => setNotice({
		tone: "danger",
		text: error instanceof ApiError && error.errors.length ? error.errors.join("\n") : t("kit.error.load_failed")
	});
	const sync = () => kitApi.post(syncPath(project), {}).then((answer) => {
		setNotice({
			tone: answer.kind === "warning" ? "warning" : "neutral",
			text: answer.message
		});
		return query.refetch();
	}).catch(fail);
	const remove = (file) => kitApi.delete(filePath(project, file.id)).then(() => {
		setNotice({
			tone: "neutral",
			text: t("notice_successful_delete")
		});
		return query.refetch();
	}).catch(fail);
	return /* @__PURE__ */ jsxs("div", {
		className: "flex min-w-0 flex-col pb-6",
		children: [
			notice && /* @__PURE__ */ jsx(Notice, {
				tone: notice.tone,
				role: "status",
				wrap: true,
				text: notice.text
			}),
			data.errors && /* @__PURE__ */ jsx(Notice, {
				tone: "danger",
				wrap: true,
				text: t("text_issue_template_files_with_errors")
			}),
			data.text_formatting && /* @__PURE__ */ jsx(Notice, {
				tone: "warning",
				wrap: true,
				text: t("warning_issue_template_text_formatting", { name: data.text_formatting })
			}),
			data.source && /* @__PURE__ */ jsxs(Fragment, { children: [/* @__PURE__ */ jsx(SectionHeading, {
				heading: t("label_repository"),
				inset: 24,
				className: "mt-section"
			}), /* @__PURE__ */ jsx(AttrGrid, {
				columns: 1,
				className: "px-gutter",
				items: [
					{
						label: data.source.kind === "github" ? "GitHub" : t("label_repository"),
						value: data.source.folder
					},
					...data.source.revision ? [{
						label: t("label_revision"),
						value: data.source.revision
					}] : [],
					...data.source.synced_at ? [{
						label: t("field_updated_on"),
						value: new Date(data.source.synced_at).toLocaleString()
					}] : []
				]
			})] }),
			/* @__PURE__ */ jsx(SectionHeading, {
				heading: t("label_issue_template_plural"),
				count: data.files.length,
				inset: 24,
				className: "mt-section",
				actions: /* @__PURE__ */ jsxs(Fragment, { children: [/* @__PURE__ */ jsx(IconButton, {
					icon: "help",
					size: 28,
					"aria-label": t("label_help"),
					onClick: () => window.open(DOCS, "_blank", "noopener,noreferrer")
				}), data.has_repository && /* @__PURE__ */ jsx(Button, {
					size: 28,
					icon: "import",
					onClick: () => void sync(),
					children: t("button_import")
				})] }),
				action: data.manual ? t("label_issue_template_file_new") : void 0,
				icon: "plus",
				href: data.manual ? newPage(project) : void 0
			}),
			data.files.length === 0 ? /* @__PURE__ */ jsx(EmptyState, {
				variant: "block",
				text: t("label_no_data")
			}) : /* @__PURE__ */ jsx("div", {
				className: "flex flex-col",
				children: data.files.map((file) => /* @__PURE__ */ jsx(ListRow, {
					id: String(file.id),
					icon: file.kind === "config" ? "settings" : file.kind === "form" ? "grid" : "document",
					title: file.path,
					mono: true,
					sub: [file.name, file.tracker].filter(Boolean).join(" · ") || void 0,
					href: data.manual ? editPage(project, file.id) : filePath(project, file.id).replace(/\.json$/, ""),
					inset: 24,
					divider: true,
					cols: [{
						content: /* @__PURE__ */ jsx(FileState, { file }),
						kind: "muted",
						width: 96,
						align: "right"
					}],
					actions: data.manual ? [{
						icon: "delete",
						label: t("button_delete"),
						action: "delete",
						danger: true
					}] : [],
					onAction: () => setDeleting(file)
				}, file.id))
			}),
			/* @__PURE__ */ jsx(ChooserSettings, {
				data,
				onSaved: () => setNotice({
					tone: "neutral",
					text: t("notice_successful_update")
				}),
				onError: fail,
				refetch: () => void query.refetch()
			}, JSON.stringify(data.config)),
			/* @__PURE__ */ jsx(ConfirmDialog, {
				open: !!deleting,
				onOpenChange: (open) => !open && setDeleting(null),
				title: t("kit.confirm.delete_title", { name: deleting?.path ?? "" }),
				onConfirm: () => {
					if (deleting) remove(deleting);
					setDeleting(null);
				}
			})
		]
	});
}
/** A file's state, as Redmine's tab marks it: its errors (not usable), its warnings, or fine. */
function FileState({ file }) {
	const t = useT();
	if (file.errors) return /* @__PURE__ */ jsx(Badge, {
		tone: "danger",
		icon: "warning",
		children: t("label_issue_template_errors", { count: file.errors })
	});
	if (file.warnings) return /* @__PURE__ */ jsx(Badge, {
		tone: "warning",
		icon: "warning",
		children: t("label_issue_template_warnings", { count: file.warnings })
	});
	return /* @__PURE__ */ jsx(Icon, {
		name: "check",
		size: 14,
		"aria-label": t("label_issue_template_usable")
	});
}
/** The chooser's settings (config.yml): saved here when the templates are edited here, read-only otherwise. */
function ChooserSettings({ data, onSaved, onError, refetch }) {
	const t = useT();
	const { project } = useExtensionContext();
	const [blank, setBlank] = useState(data.config.blank_issues_enabled);
	const [links, setLinks] = useState(data.config.contact_links);
	const [saving, setSaving] = useState(false);
	const filled = links.filter((link) => link.name || link.url || link.about);
	const dirty = blank !== data.config.blank_issues_enabled || JSON.stringify(filled) !== JSON.stringify(data.config.contact_links);
	const readOnly = !data.manual;
	const setLink = (index, patch) => setLinks((current) => current.map((link, i) => i === index ? {
		...link,
		...patch
	} : link));
	const save = () => {
		if (!project) return;
		setSaving(true);
		kitApi.put(chooserSettingsPath(project), {
			blank_issues_enabled: blank,
			contact_links: filled
		}).then(() => {
			onSaved();
			refetch();
		}).catch(onError).finally(() => setSaving(false));
	};
	return /* @__PURE__ */ jsxs(Fragment, { children: [
		/* @__PURE__ */ jsx(SectionHeading, {
			heading: t("label_issue_template_chooser"),
			inset: 24,
			className: "mt-section"
		}),
		/* @__PURE__ */ jsx("div", {
			className: "flex flex-col gap-3 px-gutter",
			children: /* @__PURE__ */ jsx(Checkbox, {
				label: t("label_issue_template_blank_issues_enabled"),
				checked: blank,
				readOnly,
				onCheckedChange: (checked) => setBlank(checked === true)
			})
		}),
		/* @__PURE__ */ jsx(SectionHeading, {
			heading: t("label_issue_template_contact_links"),
			count: filled.length,
			inset: 24,
			className: "mt-section",
			action: readOnly ? void 0 : t("button_add"),
			icon: "plus",
			onAction: () => setLinks((current) => [...current, {
				name: "",
				url: "",
				about: ""
			}])
		}),
		links.length === 0 && /* @__PURE__ */ jsx(EmptyState, {
			variant: "block",
			text: t("label_no_data")
		}),
		links.map((link, index) => /* @__PURE__ */ jsxs("div", {
			className: "flex min-w-0 flex-col gap-2 px-gutter pb-4",
			children: [/* @__PURE__ */ jsxs("div", {
				className: "flex min-w-0 items-end gap-2",
				children: [
					/* @__PURE__ */ jsx(FormRow, {
						layout: "stack",
						label: t("field_name"),
						className: "min-w-0 flex-1",
						children: /* @__PURE__ */ jsx(Input, {
							value: link.name,
							readOnly,
							onChange: (event) => setLink(index, { name: event.target.value })
						})
					}),
					/* @__PURE__ */ jsx(FormRow, {
						layout: "stack",
						label: t("field_url"),
						className: "min-w-0 flex-1",
						children: /* @__PURE__ */ jsx(Input, {
							value: link.url,
							mono: true,
							readOnly,
							onChange: (event) => setLink(index, { url: event.target.value })
						})
					}),
					!readOnly && /* @__PURE__ */ jsx(IconButton, {
						icon: "delete",
						size: 32,
						tone: "danger",
						"aria-label": t("button_delete"),
						onClick: () => setLinks((current) => current.filter((_, i) => i !== index))
					})
				]
			}), /* @__PURE__ */ jsx(FormRow, {
				layout: "stack",
				label: t("field_description"),
				children: /* @__PURE__ */ jsx(Textarea, {
					rows: 2,
					value: link.about,
					readOnly,
					onChange: (event) => setLink(index, { about: event.target.value })
				})
			})]
		}, index)),
		readOnly ? /* @__PURE__ */ jsx("p", {
			className: "px-gutter pt-3 text-meta text-text-muted",
			children: t("text_issue_template_chooser_elsewhere")
		}) : /* @__PURE__ */ jsxs(FormActions, {
			placement: "sticky",
			dirty,
			children: [/* @__PURE__ */ jsx(Button, {
				variant: "ghost",
				disabled: !dirty || saving,
				onClick: () => {
					setBlank(data.config.blank_issues_enabled);
					setLinks(data.config.contact_links);
				},
				children: t("button_cancel")
			}), /* @__PURE__ */ jsx(Button, {
				submit: "primary",
				variant: "primary",
				disabled: !dirty || saving,
				tip: dirty ? void 0 : t("kit.common.no_changes"),
				onClick: save,
				children: t("button_save")
			})]
		})
	] });
}
function SettingsSkeleton() {
	const t = useT();
	return /* @__PURE__ */ jsxs(SkeletonRegion, {
		label: t("label_loading"),
		className: "flex flex-col gap-3 px-gutter py-section",
		children: [
			/* @__PURE__ */ jsx(Skeleton, {
				width: "30%",
				height: 14
			}),
			/* @__PURE__ */ jsx(Skeleton, {
				width: "70%",
				height: 32
			}),
			/* @__PURE__ */ jsx(Skeleton, {
				width: "65%",
				height: 32
			}),
			/* @__PURE__ */ jsx(Skeleton, {
				width: "60%",
				height: 32
			}),
			/* @__PURE__ */ jsx(Skeleton, {
				width: "30%",
				height: 14
			}),
			/* @__PURE__ */ jsx(Skeleton, {
				width: "40%",
				height: 20
			})
		]
	});
}
// src/IssueTemplateEdit.tsx
function IssueTemplateEdit() {
	const t = useT();
	const { project, params } = useExtensionContext();
	const id = params.id;
	const query = useKitQuery(project && id ? filePath(project, id) : null);
	if (!project) return null;
	if (id && query.isPending) return /* @__PURE__ */ jsx(EditSkeleton, {});
	if (id && query.isError) {
		const status = query.error instanceof ApiError ? query.error.status : 0;
		return /* @__PURE__ */ jsx(Card, {
			"aria-label": t("label_issue_template_plural"),
			children: /* @__PURE__ */ jsx(CardBody, {
				className: "flex flex-col px-gutter",
				children: status === 403 || status === 404 ? /* @__PURE__ */ jsx(ErrorState, {
					status,
					title: t(status === 403 ? "notice_not_authorized" : "notice_file_not_found")
				}) : /* @__PURE__ */ jsx(ErrorState, {
					icon: "warning",
					title: t("kit.error.load_failed"),
					actions: /* @__PURE__ */ jsx(Button, {
						onClick: () => void query.refetch(),
						children: t("kit.error.reload")
					})
				})
			})
		});
	}
	return /* @__PURE__ */ jsx(FileForm, {
		project,
		file: id ? query.data?.issue_template_file : void 0
	}, id ?? "new");
}
function FileForm({ project, file }) {
	const t = useT();
	const navigate = useKitNavigate();
	const [path, setPath] = useState(file?.path ?? "");
	const [content, setContent] = useState(file?.content ?? "");
	const [errors, setErrors] = useState([]);
	const [saving, setSaving] = useState(false);
	const dirty = path !== (file?.path ?? "") || content !== (file?.content ?? "");
	const back = () => navigate(tabPage(project));
	const save = () => {
		setSaving(true);
		setErrors([]);
		const body = { issue_template_file: {
			path,
			content
		} };
		(file ? kitApi.put(filePath(project, file.id), body) : kitApi.post(settingsPath(project), body)).then(back).catch((error) => setErrors(error instanceof ApiError && error.errors.length ? error.errors : [t("kit.error.load_failed")])).finally(() => setSaving(false));
	};
	const title = file ? file.path : t("label_issue_template_file_new");
	return /* @__PURE__ */ jsxs(Card, {
		"aria-label": title,
		children: [
			/* @__PURE__ */ jsx(CardHeader, {
				title,
				subtitle: project.name,
				divider: errors.length === 0 && !file?.messages.length
			}),
			errors.length > 0 && /* @__PURE__ */ jsx(Notice, {
				tone: "danger",
				role: "alert",
				wrap: true,
				text: errors.join("\n")
			}),
			file?.messages.map((message) => /* @__PURE__ */ jsx(Notice, {
				tone: message.level === "error" ? "danger" : "warning",
				wrap: true,
				text: message.text
			}, message.text)),
			/* @__PURE__ */ jsxs(CardBody, {
				className: "flex flex-col gap-4 px-gutter py-section",
				children: [/* @__PURE__ */ jsx(FormRow, {
					layout: "stack",
					label: t("field_filename"),
					required: true,
					hint: t("text_issue_template_path_info"),
					children: /* @__PURE__ */ jsx(Input, {
						value: path,
						mono: true,
						onChange: (event) => setPath(event.target.value)
					})
				}), /* @__PURE__ */ jsx(FormRow, {
					layout: "stack",
					label: t("field_content"),
					children: /* @__PURE__ */ jsx(Textarea, {
						rows: 16,
						maxRows: 60,
						mono: true,
						value: content,
						onChange: (event) => setContent(event.target.value)
					})
				})]
			}),
			/* @__PURE__ */ jsxs(FormActions, {
				placement: "sticky",
				dirty,
				children: [/* @__PURE__ */ jsx(Button, {
					"data-form-cancel": true,
					variant: "ghost",
					disabled: saving,
					onClick: back,
					children: t("button_cancel")
				}), /* @__PURE__ */ jsx(Button, {
					submit: "primary",
					variant: "primary",
					keycap: "⌘↵",
					disabled: !path.trim() || saving,
					onClick: save,
					children: t("button_save")
				})]
			})
		]
	});
}
function EditSkeleton() {
	const t = useT();
	return /* @__PURE__ */ jsxs(Card, {
		"aria-label": t("label_loading"),
		children: [
			/* @__PURE__ */ jsx(CardHeader, {
				title: /* @__PURE__ */ jsx(Skeleton, {
					width: 200,
					height: 16
				}),
				divider: true
			}),
			/* @__PURE__ */ jsxs(SkeletonRegion, {
				label: t("label_loading"),
				className: "flex flex-col gap-4 px-gutter py-section",
				children: [/* @__PURE__ */ jsx(Skeleton, {
					width: "40%",
					height: 32
				}), /* @__PURE__ */ jsx(Skeleton, {
					width: "100%",
					height: 320
				})]
			}),
			/* @__PURE__ */ jsx(FormActionsSkeleton, {})
		]
	});
}
export { IssueTemplateChooser, IssueTemplateEdit, IssueTemplateSection, IssueTemplateSettings };
