# 設計

Redmine Issue Template は、Redmine にチケットテンプレートを加えます。「新しいチケット」を押すとテンプレート選択画面が開き、選んだテンプレートがチケットの入力画面を埋めて、入力欄の形を決めます。テンプレートはプロジェクトのリポジトリに置くファイルなので、コードと一緒にレビューされ、履歴が残ります。リポジトリが変わると、Redmine が取り込み直します。

<a id="goals"></a>

## 目的

- **リポジトリのテンプレートファイル。** Markdown テンプレート、YAML フォーム、`config.yml` を使います。`.github/ISSUE_TEMPLATE/` のファイルも、そのまま読めます。
- **その上に Redmine の概念。** トラッカー(バグ、機能など)、優先度、カテゴリ、対象バージョン、プライベート、カスタムフィールド、入力欄の表示・非表示・必須を、同じファイルに書けるようにします。
- **選択画面が「新しいチケット」の最初の段になる。** 入力画面の中でテンプレートを選ぶのではなく、入力画面の前にテンプレートを選びます。
- **リポジトリが正。** テンプレートはデフォルトブランチに従います。リポジトリのないプロジェクトは、テンプレートをプロジェクトの設定に置きます。

<a id="files"></a>

## ファイル

Redmine は、リポジトリのデフォルトブランチで、次のうちファイルが 1 つ以上ある最初のフォルダーを読みます。

1. `.redmine/ISSUE_TEMPLATE/`
2. `.github/ISSUE_TEMPLATE/`

2 つのフォルダーは混ぜません。`.redmine/` があれば `.github/` の代わりに使うので、Redmine 用のテンプレートを `.github/` と分けて持てます。

| ファイル | 種類 |
| --- | --- |
| `*.md` | Markdown テンプレート。YAML の front matter(`name`、`about`、`title`、`labels`、`assignees`、`type`)とチケットの本文 |
| `*.yml`、`*.yaml` | YAML フォーム。`name`、`description`、`body` と、省略できる `title`、`labels`、`assignees`、`type`、`projects` |
| `config.yml` | 選択画面の設定。`blank_issues_enabled`、`contact_links` |

テンプレート選択画面には、YAML フォームが先、Markdown テンプレートが後で、それぞれファイル名の順に並びます。

<a id="redmine-keys"></a>

### Redmine のキー

Redmine のキーは、Markdown テンプレートの front matter でも YAML フォームでも、ほかのキーと同じ一番上の階層に書きます。ほかのキーと同じ名前のものはありません。Redmine のキーを使う YAML フォームは `.redmine/ISSUE_TEMPLATE/` に置きます。GitHub は、許可していないキーが一番上の階層にあるフォームを受け付けません。

```yaml
tracker: Bug
priority: High
category: UI
fixed_version: "1.0"
is_private: false
custom_fields:
  Severity: Major
fields:
  assigned_to: hidden
  estimated_hours: hidden
  due_date: required
  Severity: required
```

`tracker`、`priority`、`category`、`fixed_version` は、プロジェクトでの名前か ID です。`is_private` は真偽値、`custom_fields` はカスタムフィールドの名前(か ID)と値の組です。

`fields` では、入力欄ごとに `shown`(デフォルト)、`hidden`、`required` を決めます。`hidden` の入力欄は、テンプレートで決めた値のまま保存します。対象は `assigned_to`、`category`、`fixed_version`、`parent_issue`、`start_date`、`due_date`、`estimated_hours`、`done_ratio`、`description`(Markdown テンプレートだけ)、`priority`、`is_private`、`watchers` と、カスタムフィールドの名前か ID です。

<a id="other-keys"></a>

### ほかのキー

| キー | Redmine では |
| --- | --- |
| `name`、`about` / `description` | 選択画面での名前と説明 |
| `title` | 入力画面に最初から入る題名 |
| `type` | 同じ名前のトラッカー(`tracker` がなければ) |
| `labels` | 使わず、警告を出す |
| `assignees` | プロジェクトで担当者にできる最初の項目。ユーザーはログイン、グループは名前で探す。グループは、Redmine でグループへのチケット割り当てを許可しているときだけ(`project.assignable_users`)。ほかの項目は警告を出す |
| `projects` | 使わず、警告を出す |
| Markdown テンプレートの本文 | 入力画面に最初から入る説明 |
| YAML フォームの `body` | 説明の代わりに出る入力欄 |

<a id="issue-forms"></a>

### YAML フォーム

入力の種類は `markdown`、`textarea`(`label`、`description`、`placeholder`、`value`、`render`。検証は `required`、`min_length`)、`input`(`label`、`description`、`placeholder`、`value`。検証は `required`、`min_length`)、`dropdown`(`label`、`description`、`multiple`、`options`、`default`。検証は `required`)、`checkboxes`(`label`、`description`、`label` と `required` を持つ選択肢。検証は `required`)、`upload`(`label`、`description`。検証は `required`、`accept`)です。ファイルごとに入力チェックを行います(必須のキー、使えるキーと属性、`id` と `label` の重複、英数字と `-`、`_` だけの `id`、`markdown` 以外の入力欄が 1 つ以上あること、選択肢の重複、予約語の `None`、選択肢の真偽値)。

チケットを作るときに、回答を Markdown にして説明に書きます。入力欄ごとに `### <label>` の見出しを置き、その下に回答を書きます。空なら `_No response_`、`render` のある `textarea` はコードブロック、`dropdown` は選んだ選択肢をカンマで区切り、`checkboxes` は選択肢ごとに `- [X] <label>` か `- [ ] <label>` です。`upload` はチケットの「ファイル」の欄を使い、その節には添付したファイルを並べます。

Redmine は、説明をテキスト書式の設定で表示します。テンプレートは Markdown なので、設定は CommonMark Markdown にします。そうでなければ、プロジェクトの設定のタブに警告を出します。

<a id="import-and-sync"></a>

## 取り込みと同期

プロジェクトは、使うファイル(`issue_template_files`)と、その取得元(`issue_template_sources`。リポジトリ、GitHub、プロジェクトの設定のどれか、リビジョン、時刻、ファイルごとのエラーと警告)を保存します。画面は保存したファイルを読み、リポジトリは読みません。

- **Redmine のリポジトリ。** Redmine がプロジェクトのメインのリポジトリのコミットを取得したあと、テンプレートフォルダーのファイルを保存したものと比べ、違えば取り込み直して、フォルダーを最後に変えたリビジョンを記録します。Redmine のリポジトリのアダプターを使うので、Redmine が対応するすべての SCM で動きます。プロジェクトの設定のタブには、すぐに取り込むボタンがあります。
- **redmine_github。** [Redmine GitHub](https://github.com/redmine-kit/redmine_github) は、GitHub の push のイベントを受け取ります。デフォルトブランチへの push で `.redmine/ISSUE_TEMPLATE/` か `.github/ISSUE_TEMPLATE/` が変わると、そのフォルダーのファイルを付けて `RedmineIssueTemplate::Importer.import(project, files:, revision:, source: 'github')` を呼びます。
- **プロジェクトの設定。** リポジトリにテンプレートがないプロジェクトは、プロジェクトの設定でファイルを作成、編集、削除します。編集はファイルのテキストをそのまま書く形です。保存するときに取り込みと同じ入力チェックを行い、エラーのあるファイルは保存せず、Redmine のフォームと同じ形でエラーを出します。リポジトリにテンプレートがあればそちらを使い、設定ではファイル、内容、取得元を読み取り専用で表示します。コントローラーも、それらの編集を受け付けません。

エラーのあるファイルは、設定にエラーと一緒に表示し、選択画面には出しません。ほかのファイルはそのまま使えます。

<a id="screens"></a>

## 画面

画面は Redmine 本体の画面に倣います([Redmine Design Guide](https://redmine-kit.github.io/design-guide/ja/))。

- **テンプレート選択画面**(`/projects/<id>/issues/templates`): プロジェクトにテンプレートがあると、「新しいチケット」で開きます。Redmine の一覧と同じ表(`table.list`)に、テンプレートの名前(入力画面へのリンク)、説明、トラッカーを並べます。「空白のチケット」は、`blank_issues_enabled` が false でなければ、またテンプレートを管理できる利用者には常に、アクションのリンクで出します。`contact_links` は「その他の連絡先」として 2 つ目の一覧にします。「新しいチケット」に付いてきたパラメーター(親チケットなど)は引き継ぎます。
- **チケットの入力画面**: Redmine の入力画面に、テンプレートの値を入れたものです。YAML フォームの入力欄は、チケットの属性の後に、入力画面の表の形で出します。隠す入力欄は出さず、必須の入力欄には Redmine と同じ印を付けます。
- **プロジェクトの設定 › チケットテンプレート**: アクションのリンク「新しいファイル」(リポジトリにテンプレートがないとき)、「インポート」、「ヘルプ」(このドキュメントの形式のページ)。テンプレートの取得元、最後に取り込んだリビジョンと日時を、管理 › 情報 と同じ名前と値の表で出します。ファイルの一覧には正常かエラーかのアイコンを付け、リポジトリにテンプレートがなければここで編集、削除します。エラーと警告は、ファイル、キー、Redmine の検証のメッセージで出します。
- **テンプレートファイル**: 一覧のファイル名から、ファイルのページを開きます。取得元(管理 › 情報 と同じ形)と、ボックスの中のテキストを出します。「編集」と「削除」は、プロジェクトの設定のファイルにだけ出します。編集のフォームはテキストのエディター(`.box.tabular`、Wiki のページと同じテキストエリア)で、「保存」「プレビュー」「キャンセル」があります。
- **プレビュー**: 凡例「プレビュー」のボックスの中に(チケットの編集画面が入力欄をまとめるのと同じ形)、選択画面でのテンプレートの行と、テンプレートを当てた Redmine の新しいチケットの入力画面(値、隠す入力欄、必須の入力欄、YAML フォームの入力欄)を、操作できない形(`inert`)で出します。編集のフォームの「プレビュー」は、同じ入力チェックのあと、保存せずに出します。リポジトリのファイルのページには常に出します。`config.yml` のプレビューは、すべてのテンプレートを並べた選択画面です。テンプレートのプレビューは Redmine にない画面なので、チケットの入力画面と一覧をそのまま使います。

<a id="permissions"></a>

## 権限

プロジェクトのモジュール「チケットテンプレート」で、プロジェクトごとにプラグインを有効にします。「チケットテンプレートの管理」の権限で、設定のタブ、編集、取り込みが使えます。テンプレート選択画面と入力画面には、Redmine の入力画面と同じく「チケットの追加」の権限が要ります。

<a id="not-covered"></a>

## 対象外

- プルリクエストとディスカッションのテンプレート。
- `labels`、`projects`、トラッカーを決める以外の `type`。警告にとどめます。Redmine 7.0 にはチケットのタグがありません(Redmine のタグはリポジトリのタグです)。Redmine 本体かタグのプラグインがチケットのタグを持てば、`labels` をタグに当てます。
- デフォルトブランチ以外のブランチ。
