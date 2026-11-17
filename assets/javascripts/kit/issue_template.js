// Redmine Issue Template's module for Redmine Kit's new UI, built from frontend/src by `npm run build`
// (frontend/vite.config.js). Edit the source, not this file. React and @redmine-kit/ui come from the app.
import { ApiError, AttrGrid, Badge, Button, Card, CardBody, CardHeader, CardHeaderActions, CardSection, Checkbox, CheckboxGroup, ConfirmDialog, Drawer, DrawerActionsGroup, DrawerCloseButton, EmptyState, ErrorState, FormActions, FormActionsSkeleton, FormRow, Icon, IconButton, Input, ListRow, NewIssueFileField, Notice, Pane, Panes, Prose, SectionHeading, Select, Skeleton, SkeletonRegion, Tabs, TabsContent, Textarea, kitApi, useExtensionContext, useKitInvalidate, useKitNavigate, useKitQuery, useNewIssueExtension, useT } from "@redmine-kit/ui";
import { Fragment, jsx, jsxs } from "react/jsx-runtime";
import { useEffect, useState } from "react";
// src/api.ts
var base = (project) => `/projects/${encodeURIComponent(project.identifier)}/issue_templates`;
var settingsPath = (project) => `${base(project)}.json`;
var filePath = (project, id) => `${base(project)}/${encodeURIComponent(String(id))}.json`;
var chooserSettingsPath = (project) => `${base(project)}/settings.json`;
var syncPath = (project) => `${base(project)}/sync.json`;
var previewPath = (project) => `${base(project)}/preview.json`;
/** the pages the app draws (init.rb's screens) and Redmine's settings tab */
var newPage = (project) => `${base(project)}/new`;
var editPage = (project, id) => `${base(project)}/${id}/edit`;
var tabPage = (project) => `/projects/${encodeURIComponent(project.identifier)}/settings/issue_templates`;
/** The format's documentation (ヘルプ). */
var DOCS = "https://redmine-kit.github.io/redmine_issue_template/format";
/** A contact link's URL, only when it is a web page (a link of any other scheme stays text). */
var webUrl = (url) => /^https?:\/\//i.test(url) ? url : void 0;
// src/ChooserList.tsx
var hostOf = (url) => url.replace(/^https?:\/\//, "").replace(/\/$/, "");
function ChooserList({ data, onChoose }) {
	const t = useT();
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
					onSelect: onChoose,
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
					cta: onChoose ? t("label_issue_template_start") : void 0
				}, template.key)), data.blank && /* @__PURE__ */ jsx(ListRow, {
					id: "blank",
					icon: "plus",
					title: t("label_issue_template_blank"),
					sub: t("text_issue_template_blank_info"),
					onSelect: onChoose,
					inset: 24,
					size: 44,
					cta: onChoose ? t("label_issue_template_start") : void 0
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
					href: onChoose ? webUrl(link.url) : void 0,
					target: onChoose && webUrl(link.url) ? "_blank" : void 0,
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
// src/IssueTemplateChooser.tsx
function IssueTemplateChooser() {
	const { data, setParams } = useNewIssueExtension();
	return /* @__PURE__ */ jsx(ChooserList, {
		data,
		onChoose: (key) => setParams({
			issue_template: key,
			issue_template_answers: null,
			issue_template_uploads: null
		})
	});
}
// src/TemplateSummary.tsx
function TemplateSummary({ data, onChange }) {
	const t = useT();
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
					onChange && /* @__PURE__ */ jsx(Button, {
						size: 28,
						variant: "ghost",
						onClick: onChange,
						children: t("button_change")
					})
				]
			}),
			template?.about && /* @__PURE__ */ jsx(Prose, { text: template.about }),
			data.preset && data.preset.length > 0 && /* @__PURE__ */ jsx(AttrGrid, { items: data.preset.map((item) => ({
				label: item.label,
				value: item.value
			})) })
		]
	});
}
// src/IssueTemplateSection.tsx
function IssueTemplateSection() {
	const { data, setParams } = useNewIssueExtension();
	return /* @__PURE__ */ jsx(TemplateSummary, {
		data,
		onChange: () => setParams({
			issue_template: null,
			issue_template_answers: null,
			issue_template_uploads: null
		})
	});
}
// src/TemplateQuestions.tsx
function TemplateQuestions({ elements, answers, onAnswer, onFiles }) {
	if (elements.length === 0) return null;
	return /* @__PURE__ */ jsx("div", {
		className: "flex min-w-0 flex-col gap-4",
		children: elements.map((element, index) => element.type === "markdown" ? /* @__PURE__ */ jsx(Prose, { text: element.text }, `markdown-${index}`) : /* @__PURE__ */ jsx(FieldRow, {
			field: element,
			value: answers[element.ref],
			onChange: (value) => onAnswer?.(element.ref, value),
			onFiles: (files) => onFiles?.(element.ref, files)
		}, element.ref))
	});
}
var asList = (value) => Array.isArray(value) ? value : value ? [value] : [];
var asText = (value) => typeof value === "string" ? value : "";
/** One field of a YAML form, with the app's form parts. */
function FieldRow({ field, value, onChange, onFiles }) {
	const t = useT();
	const row = (control) => /* @__PURE__ */ jsx(FormRow, {
		layout: "stack",
		label: field.label,
		required: field.required,
		hint: hint(field),
		children: control
	});
	const blank = {
		value: "",
		label: t("actionview_instancetag_blank_option")
	};
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
			options: [...field.blank ? [blank] : [], ...field.options],
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
				options: [blank, ...field.options ?? []],
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
		case "upload": return row(/* @__PURE__ */ jsx(NewIssueFileField, {
			name: field.ref,
			accept: field.accept.length ? field.accept.map((ext) => ext.startsWith(".") ? ext : `.${ext}`) : void 0,
			onChange: onFiles
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
/** A field's description, as written (Markdown: a link in it is a link), under the field; the upload field's extensions are
*  the file field's own. */
function hint(field) {
	return field.description ? /* @__PURE__ */ jsx(Prose, {
		text: field.description,
		className: "text-meta text-text-muted"
	}) : void 0;
}
// src/IssueTemplateFields.tsx
function IssueTemplateFields() {
	const { data, params, setParams } = useNewIssueExtension();
	const elements = data.elements ?? [];
	const answers = params.issue_template_answers ?? {};
	const uploads = params.issue_template_uploads ?? {};
	const fields = elements.filter((element) => element.type !== "markdown");
	const starting = JSON.stringify(Object.fromEntries(fields.flatMap((field) => "value" in field && field.value != null ? [[field.ref, field.value]] : [])));
	useEffect(() => {
		if (params.issue_template_answers === void 0 && starting !== "{}") setParams({ issue_template_answers: JSON.parse(starting) });
	}, [
		starting,
		params.issue_template_answers,
		setParams
	]);
	return /* @__PURE__ */ jsx(TemplateQuestions, {
		elements,
		answers,
		onAnswer: (ref, value) => setParams({ issue_template_answers: {
			...answers,
			[ref]: value
		} }),
		onFiles: (ref, files) => setParams({ issue_template_uploads: {
			...uploads,
			[ref]: files.map((file) => file.id)
		} })
	});
}
// src/TemplatePreview.tsx
function TemplatePreview({ preview }) {
	const t = useT();
	if (!preview) return /* @__PURE__ */ jsx(EmptyState, {
		variant: "block",
		text: t("text_issue_template_unusable")
	});
	if (preview.kind === "config") return /* @__PURE__ */ jsx("div", {
		inert: true,
		className: "flex min-w-0 flex-col pt-section pb-6",
		children: /* @__PURE__ */ jsx(ChooserList, { data: preview.chooser })
	});
	const row = preview.chooser_row;
	return /* @__PURE__ */ jsxs("div", {
		className: "flex min-w-0 flex-col pt-section pb-6",
		children: [
			/* @__PURE__ */ jsx(SectionHeading, {
				heading: t("label_issue_template_chooser"),
				inset: 24
			}),
			/* @__PURE__ */ jsx("div", {
				inert: true,
				children: /* @__PURE__ */ jsx(ListRow, {
					icon: row.kind === "form" ? "grid" : "document",
					title: row.name,
					sub: row.about || void 0,
					size: 44,
					cols: [{
						content: row.tracker ?? "",
						kind: "text",
						width: 88
					}]
				})
			}),
			/* @__PURE__ */ jsx(CardSection, {
				heading: t("label_issue_new"),
				level: 3,
				children: /* @__PURE__ */ jsxs("div", {
					inert: true,
					className: "flex min-w-0 flex-col gap-4 px-gutter",
					children: [
						/* @__PURE__ */ jsx(TemplateSummary, { data: preview.section }),
						/* @__PURE__ */ jsx(FormRow, {
							layout: "stack",
							label: t("field_tracker"),
							required: true,
							children: /* @__PURE__ */ jsx(Input, {
								readOnly: true,
								value: preview.issue.tracker ?? ""
							})
						}),
						/* @__PURE__ */ jsx(FormRow, {
							layout: "stack",
							label: t("field_subject"),
							required: true,
							children: /* @__PURE__ */ jsx(Input, {
								readOnly: true,
								value: preview.issue.subject
							})
						}),
						/* @__PURE__ */ jsx(TemplateQuestions, {
							elements: preview.section.elements ?? [],
							answers: answersOf(preview)
						}),
						preview.issue.description != null && /* @__PURE__ */ jsx(FormRow, {
							layout: "stack",
							label: t("field_description"),
							children: /* @__PURE__ */ jsx(Textarea, {
								readOnly: true,
								rows: 6,
								maxRows: 20,
								value: preview.issue.description
							})
						})
					]
				})
			})
		]
	});
}
/** The answers a YAML form starts with (the template's values and defaults). */
function answersOf(preview) {
	return Object.fromEntries((preview.section.elements ?? []).flatMap((element) => element.type !== "markdown" && "value" in element && element.value != null ? [[element.ref, element.value]] : []));
}
// src/useTemplateFileForm.tsx
function useTemplateFileForm({ project, file, onSaved, onCancel }) {
	const t = useT();
	const [path, setPath] = useState(file?.path ?? "");
	const [content, setContent] = useState(file?.content ?? "");
	const [tab, setTab] = useState("edit");
	const [errors, setErrors] = useState([]);
	const [saving, setSaving] = useState(false);
	const dirty = path !== (file?.path ?? "") || content !== (file?.content ?? "");
	const reason = !file || dirty ? void 0 : t("kit.common.no_changes");
	const save = () => {
		setSaving(true);
		setErrors([]);
		const body = { issue_template_file: {
			path,
			content
		} };
		(file ? kitApi.put(filePath(project, file.id), body) : kitApi.post(settingsPath(project), body)).then(() => onSaved(!file)).catch((error) => setErrors(error instanceof ApiError && error.errors.length ? error.errors : [t("kit.error.load_failed")])).finally(() => setSaving(false));
	};
	return {
		title: file ? file.path : t("label_issue_template_file_new"),
		dirty,
		bands: /* @__PURE__ */ jsxs(Fragment, { children: [errors.length > 0 && /* @__PURE__ */ jsx(Notice, {
			tone: "danger",
			role: "alert",
			wrap: true,
			text: errors.join("\n")
		}), file?.messages.map((message) => /* @__PURE__ */ jsx(Notice, {
			tone: message.level === "error" ? "danger" : "warning",
			wrap: true,
			text: message.text
		}, message.text))] }),
		body: /* @__PURE__ */ jsxs(Tabs, {
			"aria-label": t("label_issue_template_plural"),
			items: [{
				value: "edit",
				label: t("button_edit")
			}, {
				value: "preview",
				label: t("label_preview")
			}],
			value: tab,
			onValueChange: setTab,
			className: "flex min-w-0 flex-col",
			children: [/* @__PURE__ */ jsx(TabsContent, {
				value: "edit",
				children: /* @__PURE__ */ jsxs("div", {
					className: "flex min-w-0 flex-col gap-4 px-gutter py-section",
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
						required: true,
						children: /* @__PURE__ */ jsx(Textarea, {
							rows: 16,
							maxRows: 60,
							mono: true,
							value: content,
							onChange: (event) => setContent(event.target.value)
						})
					})]
				})
			}), /* @__PURE__ */ jsx(TabsContent, {
				value: "preview",
				children: tab === "preview" && /* @__PURE__ */ jsx(FilePreview, {
					project,
					id: file?.id,
					path,
					content
				})
			})]
		}),
		actions: /* @__PURE__ */ jsxs(Fragment, { children: [/* @__PURE__ */ jsx(Button, {
			"data-form-cancel": true,
			variant: "ghost",
			keycap: "Esc",
			disabled: saving,
			onClick: onCancel,
			children: t("button_cancel")
		}), /* @__PURE__ */ jsx(Button, {
			submit: "primary",
			variant: "primary",
			keycap: "⌘↵",
			disabled: !path.trim() || !!reason || saving,
			tip: reason,
			onClick: save,
			children: t(file ? "button_save" : "button_create")
		})] })
	};
}
/** The preview of the text as typed: asked again when the tab opens with another text. */
function FilePreview({ project, id, path, content }) {
	const t = useT();
	const [answer, setAnswer] = useState(null);
	const key = JSON.stringify([
		id ?? null,
		path,
		content
	]);
	useEffect(() => {
		let current = true;
		kitApi.post(previewPath(project), { issue_template_file: {
			id: id ?? "",
			path,
			content
		} }).then((data) => current && setAnswer({
			key,
			data: data.preview
		})).catch(() => current && setAnswer({
			key,
			failed: true
		}));
		return () => {
			current = false;
		};
	}, [
		project,
		id,
		path,
		content,
		key
	]);
	if (!answer || answer.key !== key) return /* @__PURE__ */ jsx(PreviewSkeleton, {});
	if (answer.failed || !answer.data) return /* @__PURE__ */ jsx(Notice, {
		tone: "warning",
		text: t("kit.error.load_failed")
	});
	return /* @__PURE__ */ jsxs(Fragment, { children: [answer.data.messages.map((message) => /* @__PURE__ */ jsx(Notice, {
		tone: message.level === "error" ? "danger" : "warning",
		wrap: true,
		text: message.text
	}, message.text)), /* @__PURE__ */ jsx(TemplatePreview, { preview: answer.data.preview })] });
}
/** A preview while it comes, laid out as a template's preview (TemplatePreview): the chooser's heading and row, then
*  新しいチケット with the template's line and the form's first fields. */
function PreviewSkeleton() {
	const t = useT();
	return /* @__PURE__ */ jsxs(SkeletonRegion, {
		label: t("label_loading"),
		className: "flex min-w-0 flex-col pt-section pb-6",
		children: [
			/* @__PURE__ */ jsx(SectionHeading, {
				heading: t("label_issue_template_chooser"),
				inset: 24
			}),
			/* @__PURE__ */ jsx(ListRow, {
				icon: /* @__PURE__ */ jsx(Skeleton, {
					width: 16,
					height: 16
				}),
				title: /* @__PURE__ */ jsx(Skeleton, {
					width: 140,
					height: 12,
					className: "inline-block align-middle"
				}),
				sub: /* @__PURE__ */ jsx(Skeleton, {
					width: 220,
					height: 10,
					className: "inline-block align-middle"
				}),
				size: 44
			}),
			/* @__PURE__ */ jsx(CardSection, {
				heading: t("label_issue_new"),
				level: 3,
				children: /* @__PURE__ */ jsxs("div", {
					className: "flex min-w-0 flex-col gap-4 px-gutter",
					children: [
						/* @__PURE__ */ jsx("div", {
							className: "flex min-h-8 items-center",
							children: /* @__PURE__ */ jsx(Skeleton, {
								width: 180,
								height: 14
							})
						}),
						/* @__PURE__ */ jsx(FormRow, {
							layout: "stack",
							label: t("field_tracker"),
							required: true,
							children: /* @__PURE__ */ jsx(Skeleton, {
								width: "100%",
								height: 32
							})
						}),
						/* @__PURE__ */ jsx(FormRow, {
							layout: "stack",
							label: t("field_subject"),
							required: true,
							children: /* @__PURE__ */ jsx(Skeleton, {
								width: "100%",
								height: 32
							})
						})
					]
				})
			})
		]
	});
}
// src/IssueTemplateFileDrawer.tsx
function IssueTemplateFileDrawer({ project, file, onClose, onSaved }) {
	const form = useTemplateFileForm({
		project,
		file,
		onSaved,
		onCancel: onClose
	});
	return /* @__PURE__ */ jsxs(Drawer, {
		label: form.title,
		onClose,
		preset: "create",
		trapFocus: true,
		url: file ? editPage(project, file.id) : newPage(project),
		children: [
			/* @__PURE__ */ jsx(CardHeader, {
				title: form.title,
				divider: true,
				actions: /* @__PURE__ */ jsx(DrawerActionsGroup, { children: /* @__PURE__ */ jsx(DrawerCloseButton, { onClose }) })
			}),
			form.bands,
			form.body,
			/* @__PURE__ */ jsx(FormActions, {
				placement: "sticky",
				edge: true,
				dirty: form.dirty,
				children: form.actions
			})
		]
	});
}
// src/IssueTemplateSettings.tsx
function IssueTemplateSettings() {
	const t = useT();
	const { project } = useExtensionContext();
	const query = useKitQuery(project && settingsPath(project));
	const invalidate = useKitInvalidate();
	const [band, setBand] = useState(null);
	const [selected, setSelected] = useState(null);
	const [deleting, setDeleting] = useState(null);
	const [drawer, setDrawer] = useState(null);
	if (!project) return null;
	if (query.isPending) return /* @__PURE__ */ jsx(SettingsSkeleton, {});
	if (query.isError) return /* @__PURE__ */ jsx(Notice, {
		tone: "warning",
		text: t("kit.error.load_failed")
	});
	const data = query.data.issue_templates;
	const templates = data.files.filter((file) => file.kind !== "config");
	const configFile = data.files.find((file) => file.kind === "config");
	const current = selected?.kind === "config" || selected && templates.some((file) => file.id === selected.id) ? selected : templates[0] ? {
		kind: "file",
		id: templates[0].id
	} : { kind: "config" };
	const fail = (error) => setBand({
		tone: "danger",
		text: error instanceof ApiError && error.errors.length ? error.errors.join("\n") : t("kit.error.load_failed")
	});
	const sync = () => kitApi.post(syncPath(project), {}).then((answer) => {
		setBand({
			tone: answer.kind === "warning" ? "warning" : "neutral",
			text: answer.message
		});
		invalidate();
	}).catch(fail);
	const remove = (file) => kitApi.delete(filePath(project, file.id)).then(() => {
		setBand({
			tone: "neutral",
			text: t("notice_successful_delete")
		});
		setSelected(null);
		invalidate();
	}).catch(fail);
	const saved = (created) => {
		setDrawer(null);
		setBand({
			tone: "neutral",
			text: t(created ? "notice_successful_create" : "notice_successful_update")
		});
		invalidate();
	};
	return /* @__PURE__ */ jsxs(Fragment, { children: [
		/* @__PURE__ */ jsxs(CardHeaderActions, { children: [
			/* @__PURE__ */ jsx(Button, {
				variant: "ghost",
				icon: "help",
				onClick: () => window.open(DOCS, "_blank", "noopener,noreferrer"),
				children: t("label_help")
			}),
			data.has_repository && /* @__PURE__ */ jsx(Button, {
				icon: "import",
				onClick: () => void sync(),
				children: t("button_import")
			}),
			data.manual && /* @__PURE__ */ jsx(Button, {
				variant: "primary",
				icon: "plus",
				onClick: () => setDrawer({}),
				children: t("label_issue_template_file_new")
			})
		] }),
		band && /* @__PURE__ */ jsx(Notice, {
			tone: band.tone,
			role: "status",
			wrap: true,
			text: band.text
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
		/* @__PURE__ */ jsxs(Panes, {
			dividers: true,
			stacked: true,
			children: [/* @__PURE__ */ jsxs(Pane, {
				as: "nav",
				width: 320,
				"aria-label": t("label_issue_template_plural"),
				className: "pb-6",
				children: [
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
						count: templates.length,
						inset: 24,
						className: "mt-section"
					}),
					templates.length === 0 && /* @__PURE__ */ jsx(EmptyState, {
						variant: "block",
						text: t("label_no_data")
					}),
					templates.map((file) => /* @__PURE__ */ jsx(ListRow, {
						id: String(file.id),
						icon: file.kind === "form" ? "grid" : "document",
						title: file.name ?? file.path,
						sub: [file.path, file.tracker].filter(Boolean).join(" · "),
						selected: current.kind === "file" && current.id === file.id,
						onSelect: () => setSelected({
							kind: "file",
							id: file.id
						}),
						cols: [{
							content: /* @__PURE__ */ jsx(FileState, { file }),
							kind: "muted",
							width: 104,
							align: "right"
						}]
					}, file.id)),
					/* @__PURE__ */ jsx(ListRow, {
						id: "config",
						icon: "settings",
						title: t("label_issue_template_chooser"),
						sub: data.config.path,
						selected: current.kind === "config",
						onSelect: () => setSelected({ kind: "config" }),
						cols: [{
							content: configFile ? /* @__PURE__ */ jsx(FileState, { file: configFile }) : null,
							kind: "muted",
							width: 104,
							align: "right"
						}]
					})
				]
			}), /* @__PURE__ */ jsx(Pane, {
				as: "section",
				className: "flex flex-col",
				children: current.kind === "config" ? /* @__PURE__ */ jsx(ConfigPane, {
					data,
					file: configFile,
					onEdit: (file) => setDrawer({ file }),
					onSaved: () => {
						setBand({
							tone: "neutral",
							text: t("notice_successful_update")
						});
						invalidate();
					},
					onError: fail
				}, "config") : /* @__PURE__ */ jsx(FilePane, {
					id: current.id,
					manual: data.manual,
					onEdit: (file) => setDrawer({ file }),
					onDelete: setDeleting,
					files: data.files
				}, current.id)
			})]
		}),
		drawer && /* @__PURE__ */ jsx(IssueTemplateFileDrawer, {
			project,
			file: drawer.file,
			onClose: () => setDrawer(null),
			onSaved: saved
		}),
		/* @__PURE__ */ jsx(ConfirmDialog, {
			open: !!deleting,
			onOpenChange: (open) => !open && setDeleting(null),
			title: t("kit.common.delete_named", { name: deleting?.path ?? "" }),
			onConfirm: () => {
				if (deleting) remove(deleting);
				setDeleting(null);
			}
		})
	] });
}
/** A file's state, as Redmine's tab marks it: its errors (not usable), its warnings, or usable. */
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
/** The pane's heading: the file's name, and 編集 and 削除 when the templates are edited here. */
function FileHeading({ path, onEdit, onDelete, elsewhere }) {
	const t = useT();
	return /* @__PURE__ */ jsx(SectionHeading, {
		heading: path,
		inset: 24,
		className: "mt-section",
		actions: elsewhere ? /* @__PURE__ */ jsx("span", {
			className: "text-meta text-text-muted",
			children: t("error_issue_template_managed_elsewhere")
		}) : /* @__PURE__ */ jsxs(Fragment, { children: [onEdit && /* @__PURE__ */ jsx(Button, {
			size: 28,
			icon: "edit",
			onClick: onEdit,
			children: t("button_edit")
		}), onDelete && /* @__PURE__ */ jsx(Button, {
			size: 28,
			variant: "danger",
			icon: "delete",
			onClick: onDelete,
			children: t("button_delete")
		})] })
	});
}
/** A template file: its messages, プレビュー and 内容 (GET the file: its text, messages and preview). */
function FilePane({ id, manual, files, onEdit, onDelete }) {
	const t = useT();
	const { project } = useExtensionContext();
	const query = useKitQuery(project && filePath(project, id));
	const [tab, setTab] = useState("preview");
	const row = files.find((file) => file.id === id);
	if (query.isPending) return /* @__PURE__ */ jsx(FilePaneSkeleton, { path: row?.path });
	if (query.isError) return /* @__PURE__ */ jsx(Notice, {
		tone: "warning",
		text: t("kit.error.load_failed")
	});
	const file = query.data.issue_template_file;
	return /* @__PURE__ */ jsxs(Fragment, { children: [
		/* @__PURE__ */ jsx(FileHeading, {
			path: file.path,
			elsewhere: !manual,
			onEdit: () => onEdit(file),
			onDelete: row ? () => onDelete(row) : void 0
		}),
		file.messages.map((message) => /* @__PURE__ */ jsx(Notice, {
			tone: message.level === "error" ? "danger" : "warning",
			wrap: true,
			text: message.text
		}, message.text)),
		/* @__PURE__ */ jsxs(Tabs, {
			"aria-label": file.path,
			items: [{
				value: "preview",
				label: t("label_preview")
			}, {
				value: "content",
				label: t("field_content")
			}],
			value: tab,
			onValueChange: setTab,
			className: "flex min-w-0 flex-col",
			children: [/* @__PURE__ */ jsx(TabsContent, {
				value: "preview",
				children: /* @__PURE__ */ jsx(TemplatePreview, { preview: file.preview })
			}), /* @__PURE__ */ jsx(TabsContent, {
				value: "content",
				children: /* @__PURE__ */ jsx(FileContent, { content: file.content })
			})]
		})
	] });
}
function FileContent({ content }) {
	const t = useT();
	return /* @__PURE__ */ jsx("div", {
		className: "px-gutter py-section",
		children: /* @__PURE__ */ jsx(Textarea, {
			readOnly: true,
			mono: true,
			"aria-label": t("field_content"),
			rows: Math.min(content.split("\n").length, 80),
			maxRows: 80,
			value: content
		})
	});
}
/** config.yml: 設定 (the chooser's settings), プレビュー (the chooser the templates make) and 内容 (when the file exists). */
function ConfigPane({ data, file, onEdit, onSaved, onError }) {
	const t = useT();
	const { project } = useExtensionContext();
	const query = useKitQuery(project && file ? filePath(project, file.id) : null);
	const [tab, setTab] = useState("settings");
	const loaded = file ? query.data?.issue_template_file : void 0;
	return /* @__PURE__ */ jsxs(Fragment, { children: [
		/* @__PURE__ */ jsx(FileHeading, {
			path: data.config.path,
			elsewhere: !data.manual,
			onEdit: loaded ? () => onEdit(loaded) : void 0
		}),
		loaded?.messages.map((message) => /* @__PURE__ */ jsx(Notice, {
			tone: message.level === "error" ? "danger" : "warning",
			wrap: true,
			text: message.text
		}, message.text)),
		/* @__PURE__ */ jsxs(Tabs, {
			"aria-label": data.config.path,
			items: [
				{
					value: "settings",
					label: t("label_settings")
				},
				{
					value: "preview",
					label: t("label_preview")
				},
				...file ? [{
					value: "content",
					label: t("field_content")
				}] : []
			],
			value: tab,
			onValueChange: setTab,
			className: "flex min-w-0 flex-col",
			children: [
				/* @__PURE__ */ jsx(TabsContent, {
					value: "settings",
					children: /* @__PURE__ */ jsx(ChooserSettings, {
						data,
						onSaved,
						onError
					}, JSON.stringify(data.config))
				}),
				/* @__PURE__ */ jsx(TabsContent, {
					value: "preview",
					children: /* @__PURE__ */ jsx("div", {
						inert: true,
						className: "flex min-w-0 flex-col pt-section pb-6",
						children: /* @__PURE__ */ jsx(ChooserList, { data: data.chooser })
					})
				}),
				file && /* @__PURE__ */ jsx(TabsContent, {
					value: "content",
					children: loaded ? /* @__PURE__ */ jsx(FileContent, { content: loaded.content }) : /* @__PURE__ */ jsx(PreviewSkeleton, {})
				})
			]
		})
	] });
}
/** The chooser's settings (config.yml): saved here when the templates are edited here, read-only otherwise. */
function ChooserSettings({ data, onSaved, onError }) {
	const t = useT();
	const { project } = useExtensionContext();
	const [blank, setBlank] = useState(data.config.blank_issues_enabled);
	const [links, setLinks] = useState(data.config.contact_links);
	const [saving, setSaving] = useState(false);
	const filled = links.filter((link) => link.name || link.url || link.about);
	const dirty = blank !== data.config.blank_issues_enabled || JSON.stringify(filled) !== JSON.stringify(data.config.contact_links);
	const readOnly = !data.manual;
	const setLink = (index, patch) => setLinks((list) => list.map((link, i) => i === index ? {
		...link,
		...patch
	} : link));
	const save = () => {
		if (!project) return;
		setSaving(true);
		kitApi.put(chooserSettingsPath(project), {
			blank_issues_enabled: blank,
			contact_links: filled
		}).then(onSaved).catch(onError).finally(() => setSaving(false));
	};
	return /* @__PURE__ */ jsxs("div", {
		className: "flex min-w-0 flex-col",
		children: [
			/* @__PURE__ */ jsx("div", {
				className: "flex flex-col gap-3 px-gutter pt-section",
				children: /* @__PURE__ */ jsx(Checkbox, {
					label: t("label_issue_template_blank_issues_enabled"),
					checked: blank,
					disabled: readOnly,
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
				onAction: () => setLinks((list) => [...list, {
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
							onClick: () => setLinks((list) => list.filter((_, i) => i !== index))
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
				className: "px-gutter pt-3 pb-6 text-meta text-text-muted",
				children: t("text_issue_template_chooser_elsewhere")
			}) : /* @__PURE__ */ jsxs(FormActions, {
				placement: "sticky",
				edge: true,
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
		]
	});
}
/** A file's pane while its text and preview come: its heading (the name, known from the list), its tabs, the preview. */
function FilePaneSkeleton({ path }) {
	const t = useT();
	return /* @__PURE__ */ jsxs(Fragment, { children: [/* @__PURE__ */ jsx(SectionHeading, {
		heading: path ?? /* @__PURE__ */ jsx(Skeleton, {
			width: 160,
			height: 14,
			className: "inline-block align-middle"
		}),
		inset: 24,
		className: "mt-section"
	}), /* @__PURE__ */ jsx(Tabs, {
		"aria-label": path ?? t("label_loading"),
		items: [{
			value: "preview",
			label: t("label_preview")
		}, {
			value: "content",
			label: t("field_content")
		}],
		value: "preview",
		className: "flex min-w-0 flex-col",
		children: /* @__PURE__ */ jsx(PreviewSkeleton, {})
	})] });
}
/** A row of the files' list while it comes: the ListRow itself, with bars for its icon, name and file name. */
function RowSkeleton({ id, width }) {
	return /* @__PURE__ */ jsx(ListRow, {
		id,
		icon: /* @__PURE__ */ jsx(Skeleton, {
			width: 16,
			height: 16
		}),
		title: /* @__PURE__ */ jsx(Skeleton, {
			width,
			height: 12,
			className: "inline-block align-middle"
		}),
		sub: /* @__PURE__ */ jsx(Skeleton, {
			width: width * .7,
			height: 10,
			className: "inline-block align-middle"
		})
	});
}
/** The tab while its files come: the two panes as the loaded tab lays them out (the list's heading and rows, the chosen
*  file's heading, tabs and preview), so that nothing moves when the files arrive. */
function SettingsSkeleton() {
	const t = useT();
	return /* @__PURE__ */ jsxs(SkeletonRegion, {
		label: t("label_loading"),
		className: "flex min-h-0 min-w-0 flex-1 flex-col",
		children: [/* @__PURE__ */ jsxs(CardHeaderActions, { children: [/* @__PURE__ */ jsx(Skeleton, {
			width: 88,
			height: 32
		}), /* @__PURE__ */ jsx(Skeleton, {
			width: 160,
			height: 32
		})] }), /* @__PURE__ */ jsxs(Panes, {
			dividers: true,
			stacked: true,
			children: [/* @__PURE__ */ jsxs(Pane, {
				as: "nav",
				width: 320,
				"aria-label": t("label_issue_template_plural"),
				className: "pb-6",
				children: [
					/* @__PURE__ */ jsx(SectionHeading, {
						heading: t("label_issue_template_plural"),
						inset: 24,
						className: "mt-section"
					}),
					/* @__PURE__ */ jsx(RowSkeleton, {
						id: "1",
						width: 120
					}),
					/* @__PURE__ */ jsx(RowSkeleton, {
						id: "2",
						width: 96
					}),
					/* @__PURE__ */ jsx(RowSkeleton, {
						id: "3",
						width: 140
					})
				]
			}), /* @__PURE__ */ jsx(Pane, {
				as: "section",
				className: "flex flex-col",
				children: /* @__PURE__ */ jsx(FilePaneSkeleton, {})
			})]
		})]
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
	return /* @__PURE__ */ jsx(FilePage, {
		project,
		file: id ? query.data?.issue_template_file : void 0
	}, id ?? "new");
}
function FilePage({ project, file }) {
	const t = useT();
	const navigate = useKitNavigate();
	const back = () => navigate(tabPage(project));
	const form = useTemplateFileForm({
		project,
		file,
		onSaved: back,
		onCancel: back
	});
	return /* @__PURE__ */ jsxs(Card, {
		"aria-label": form.title,
		children: [
			/* @__PURE__ */ jsx(CardHeader, {
				back: {
					label: t("button_back"),
					href: tabPage(project)
				},
				title: form.title,
				sidebarToggle: true,
				sidebarLabel: t("label_settings"),
				divider: true
			}),
			form.bands,
			/* @__PURE__ */ jsxs(Panes, {
				dividers: true,
				stacked: true,
				children: [/* @__PURE__ */ jsx(Pane, {
					as: "section",
					"aria-label": form.title,
					className: "flex flex-col",
					children: form.body
				}), /* @__PURE__ */ jsx(Pane, {
					as: "aside",
					width: 360,
					"aria-label": t("label_issue_template_format_help"),
					className: "pb-6",
					children: /* @__PURE__ */ jsx(FormatHelp, {})
				})]
			}),
			/* @__PURE__ */ jsx(FormActions, {
				placement: "footer",
				dirty: form.dirty,
				children: form.actions
			})
		]
	});
}
/** The format in short, and the full documentation. */
function FormatHelp() {
	const t = useT();
	return /* @__PURE__ */ jsxs(Fragment, { children: [/* @__PURE__ */ jsx(SectionHeading, {
		heading: t("label_issue_template_format_help"),
		inset: 24,
		className: "mt-section"
	}), /* @__PURE__ */ jsxs("div", {
		className: "flex flex-col gap-3 px-gutter",
		children: [/* @__PURE__ */ jsx(Prose, { text: t("text_issue_template_format_help") }), /* @__PURE__ */ jsx(Button, {
			variant: "plain",
			size: 28,
			iconEnd: "external",
			className: "self-start",
			onClick: () => window.open(DOCS, "_blank", "noopener,noreferrer"),
			children: t("label_help")
		})]
	})] });
}
/** The page while the file comes: the loaded page's header, panes, tabs, fields and help, with bars for the file's name and
*  text, so that nothing moves when it arrives (the text's height is the file's). */
function EditSkeleton() {
	const t = useT();
	const { project } = useExtensionContext();
	return /* @__PURE__ */ jsxs(Card, {
		"aria-label": t("label_loading"),
		children: [
			/* @__PURE__ */ jsx(CardHeader, {
				back: project ? {
					label: t("button_back"),
					href: tabPage(project)
				} : void 0,
				title: /* @__PURE__ */ jsx(Skeleton, {
					width: 120,
					height: 16,
					className: "inline-block align-middle"
				}),
				sidebarToggle: true,
				sidebarLabel: t("label_settings"),
				divider: true
			}),
			/* @__PURE__ */ jsxs(Panes, {
				dividers: true,
				stacked: true,
				children: [/* @__PURE__ */ jsx(Pane, {
					as: "section",
					className: "flex flex-col",
					children: /* @__PURE__ */ jsx(Tabs, {
						"aria-label": t("label_loading"),
						items: [{
							value: "edit",
							label: t("button_edit")
						}, {
							value: "preview",
							label: t("label_preview")
						}],
						value: "edit",
						className: "flex min-w-0 flex-col",
						children: /* @__PURE__ */ jsxs(SkeletonRegion, {
							label: t("label_loading"),
							className: "flex min-w-0 flex-col gap-4 px-gutter py-section",
							children: [/* @__PURE__ */ jsx(FormRow, {
								layout: "stack",
								label: t("field_filename"),
								required: true,
								hint: t("text_issue_template_path_info"),
								children: /* @__PURE__ */ jsx(Skeleton, {
									width: "100%",
									height: 32
								})
							}), /* @__PURE__ */ jsx(FormRow, {
								layout: "stack",
								label: t("field_content"),
								required: true,
								children: /* @__PURE__ */ jsx(Skeleton, {
									width: "100%",
									height: 320
								})
							})]
						})
					})
				}), /* @__PURE__ */ jsx(Pane, {
					as: "aside",
					width: 360,
					"aria-label": t("label_issue_template_format_help"),
					className: "pb-6",
					children: /* @__PURE__ */ jsx(FormatHelp, {})
				})]
			}),
			/* @__PURE__ */ jsx(FormActionsSkeleton, {})
		]
	});
}
export { IssueTemplateChooser, IssueTemplateEdit, IssueTemplateFields, IssueTemplateSection, IssueTemplateSettings };
