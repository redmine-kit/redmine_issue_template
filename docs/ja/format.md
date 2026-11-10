# テンプレートの形式

テンプレートは Markdown テンプレート、YAML フォーム、`config.yml` です。`.github/ISSUE_TEMPLATE/` のファイルも、そのまま読めます。トラッカーや優先度などの Redmine のキーは、ほかのキーと同じ一番上の階層に書きます([Redmine のキー](#redmine-keys))。

<a id="folder"></a>

## フォルダー

Redmine は、プロジェクトのリポジトリの既定のブランチで、次のうちテンプレートファイルがある最初のフォルダーを読みます。

1. `.redmine/ISSUE_TEMPLATE/`
2. `.github/ISSUE_TEMPLATE/`

2 つのフォルダーは混ぜません。`.github/ISSUE_TEMPLATE/` と別のテンプレートを Redmine で使うときは、`.redmine/ISSUE_TEMPLATE/` に置きます。Redmine のキーを使う YAML フォームは `.redmine/ISSUE_TEMPLATE/` に置きます。GitHub は、許可していないキーが一番上の階層にあるフォームを受け付けません。

テンプレート選択画面には、YAML フォーム(`.yml`、`.yaml`)が先、Markdown テンプレート(`.md`)が後で、それぞれファイル名の順です。順番を決めるには、ファイル名の先頭に番号を付けます(`1-bug.yml`、`2-feature.md`)。拡張子を除いたファイル名が、URL でのテンプレートの ID になります(`?issue_template=1-bug`)。

<a id="markdown-templates"></a>

## Markdown テンプレート

Markdown テンプレートは、YAML の front matter と、入力画面に最初から入る説明でできています。`name` と `about` は必須です。

```markdown
---
name: 🐞 Bug
about: File a bug/issue
title: '[BUG] <title>'
labels: Bug, Needs Triage
assignees: ''
---

### Current Behavior:
<!-- A concise description of what you're experiencing. -->

### Steps To Reproduce:
```

<a id="yaml-forms"></a>

## YAML フォーム

YAML フォームは、`name`、`description`、`body` を持ちます。`title`、`labels`、`assignees`、`type`、`projects` も書けます。YAML フォームは説明の代わりに自分の入力欄を出し、チケットを作るときに、その回答を説明に書きます。次の例は GitHub のドキュメントからの引用です。

```yaml
name: Bug Report
description: File a bug report.
title: "[Bug]: "
labels: ["bug", "triage"]
type: bug
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
      description: Also tell us, what did you expect to happen?
      value: "A bug happened!"
    validations:
      required: true
  - type: dropdown
    id: version
    attributes:
      label: Version
      options:
        - 1.0.2 (Default)
        - 1.0.3 (Edge)
      default: 0
    validations:
      required: true
  - type: checkboxes
    id: terms
    attributes:
      label: Code of Conduct
      options:
        - label: I agree to follow this project's Code of Conduct
          required: true
```

<a id="fields"></a>

### 入力欄

body には次の入力の種類を使えます。どれも `attributes` を持ち、`markdown` 以外は `id`(英数字、`-`、`_`)と `validations` を持てます。

| 種類 | 属性 | 検証 | 入力画面での形 |
| --- | --- | --- | --- |
| `markdown` | `value` | なし | 説明の文。送信はしない |
| `textarea` | `label`、`description`、`placeholder`、`value`、`render` | `required`、`min_length` | 複数行の入力欄。`render` があると、回答はその言語のコードブロックになる |
| `input` | `label`、`description`、`placeholder`、`value` | `required`、`min_length` | 1 行の入力欄 |
| `dropdown` | `label`、`description`、`multiple`、`options`、`default` | `required` | 選択欄。`default` は最初に選ぶ選択肢の番号 |
| `checkboxes` | `label`、`description`、`options`(それぞれ `label` と `required`) | `required` | 選択肢ごとのチェックボックス |
| `upload` | `label`、`description` | `required`、`accept` | チケットの「ファイル」の欄を使う。説明には添付したファイルを並べる |

`validations` は、チケットを作るときに常に検証します。

<a id="the-description"></a>

### 説明への書き方

回答は Markdown で書きます。入力欄ごとに `### <label>` の見出しを置き、その下に回答を書きます。空の回答は `_No response_` です。選択欄で選んだ選択肢はカンマで区切り、チェックボックスの選択肢は `- [X] <label>` か `- [ ] <label>` になります。

```markdown
### What happened?

It crashed.

### Version

1.0.2 (Default)

### Code of Conduct

- [X] I agree to follow this project's Code of Conduct
```

<a id="checks"></a>

### 検証

ファイルごとに入力チェックを行います。必須のキー、使えるキーと属性、`id` と `label` の重複、パラメーターにしたときに同じになる `label`、`markdown` 以外の入力欄が 1 つ以上あること、選択欄の選択肢の重複と予約語 `None`、YAML で真偽値になる選択肢、YAML で真偽値になるキー(`yes`、`no`、`on`、`off` など)、4 文字以上の `name` です。規則に合わないファイルは、プロジェクトの設定にエラーと一緒に表示し、選択画面には出しません。ほかのファイルはそのまま使えます。

問題は、ファイル、キー、Redmine の検証のメッセージで表示します。たとえば `bug.yml: body[2]: id は不正な値です`、`bug.yml: description を入力してください` です。プロジェクトの設定の「ヘルプ」から、このページを開けます。

<a id="config-yml"></a>

## config.yml

`config.yml` で選択画面を設定します。ファイルがなければ、空白のチケットを作れます。

```yaml
blank_issues_enabled: false
contact_links:
  - name: GitHub Community Support
    url: https://github.com/orgs/community/discussions
    about: Please ask and answer questions here.
```

`blank_issues_enabled: false` にすると、選択画面に「空白のチケット」を出しません。ただし、「チケットテンプレートの管理」の権限を持つ利用者には出します。`contact_links` は、テンプレートの後に「その他の連絡先」として並びます。

<a id="redmine-keys"></a>

## Redmine のキー

Redmine のキーは、Markdown テンプレートでは front matter に、YAML フォームでは一番上の階層に、`name` などのほかのキーと並べて書きます。

```yaml
tracker: Bug
priority: High
category: UI
fixed_version: "2.0"
is_private: false
custom_fields:
  Severity: Major
fields:
  assigned_to: hidden
  estimated_hours: hidden
  due_date: required
  Severity: required
```

| キー | 値 |
| --- | --- |
| `tracker` | トラッカー。名前か ID |
| `priority` | 優先度。名前か ID |
| `category` | プロジェクトのカテゴリ。名前か ID |
| `fixed_version` | プロジェクトの未完了のバージョン。名前か ID |
| `is_private` | `true` か `false` |
| `custom_fields` | カスタムフィールドの名前(か ID)と値 |
| `fields` | 入力欄の表示 |

名前は大文字と小文字を区別せずに比べます。プロジェクトにない名前は、プロジェクトの設定に警告として出し、その項目は Redmine の既定のままになります。

<a id="fields-of-the-form"></a>

### 入力欄の表示

`fields` では、入力欄ごとに `shown`(既定)、`hidden`、`required` を決めます。`hidden` の入力欄は画面に出さず、テンプレートで決めた値を入れます。`required` の入力欄は、Redmine のワークフローで必須にした項目と同じように、印を付けて検証します。指定できる名前は `assigned_to`(担当者)、`category`(カテゴリ)、`fixed_version`(対象バージョン)、`parent_issue`(親チケット)、`start_date`(開始日)、`due_date`(期日)、`estimated_hours`(予定工数)、`done_ratio`(進捗率)、`description`(説明。Markdown テンプレートだけで、YAML フォームでは常に入力欄に置き換わる)、`priority`(優先度)、`is_private`(プライベート)、`watchers`(ウォッチャー)と、カスタムフィールドの名前か ID です。

トラッカー、題名、プロジェクトは、Redmine が必須にしているので、いつも表示します。Redmine の規則もそのまま効きます。トラッカーで無効にした項目は、テンプレートで `shown` にしても出ず、ワークフローで読み取り専用にした項目は読み取り専用のままです。

<a id="other-keys"></a>

## ほかのキー

キーには、Redmine に当たるものがないものもあります。そうしたキーがあってもテンプレートは使え、プロジェクトの設定に警告として出ます。

| キー | Redmine では |
| --- | --- |
| `name` | 選択画面でのテンプレートの名前 |
| `about`、`description` | 選択画面でのテンプレートの説明 |
| `title` | 入力画面に最初から入る題名 |
| `type` | 同じ名前のトラッカー。`tracker` があればそちらを使う |
| `labels` | 使わず、警告を出す |
| `assignees` | プロジェクトで担当者にできる最初の項目が、担当者になる。ユーザーはログイン、グループは名前で探す。グループは、Redmine でグループへのチケット割り当てを許可しているときだけ。担当者にできない項目は警告を出す |
| `projects` | 使わず、警告を出す |
| Markdown テンプレートの本文 | 入力画面に最初から入る説明 |
| YAML フォームの `body` | 入力画面の入力欄。回答は説明になる |
