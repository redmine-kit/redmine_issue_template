# 導入

<a id="requirements"></a>

## 動作環境

- Redmine 7.0 以降。
- Redmine のテキスト書式が CommonMark Markdown であること(管理 › 設定 › 全般)。テンプレートと YAML フォームの回答は Markdown なので、Textile では説明が意図どおりに表示されません。
- テンプレートをリポジトリに置く場合は、Redmine が読めるプロジェクトのリポジトリ(Git、または Redmine が対応するほかの SCM)。

<a id="required-plugins"></a>

### 必須プラグイン

| プラグイン | 用途 |
| --- | --- |
| [Redmine Kit Subprojects](https://github.com/redmine-kit/redmine_kit_subprojects) | テンプレートのほかのプロジェクトとの共有と、プロジェクトのコピーの項目 |

ないときは、Redmine が起動時に停止し、そのプラグインの名前を示します。gem としてインストールすると、このプラグインがそれもインストールします ([インストール](#installation))。

<a id="optional-plugins"></a>

### オプションのプラグイン

| プラグイン | 使える機能 |
| --- | --- |
| [Redmine Kit UI](https://github.com/redmine-kit/redmine_kit_ui) | 新しい UI の画面 |
| [Redmine Kit MCP](https://github.com/redmine-kit/redmine_kit_mcp) | MCP のツールでのテンプレート |
| [Redmine Kit Help](https://github.com/redmine-kit/redmine_help) | ヘルプのパネルに表示するこのプラグインのヘルプ |

<a id="installation"></a>

## インストール

プラグインは gem としてインストールするか (推奨)、`plugins/` に置きます。マイグレーションは、`redmine_kit_issue_template_files` と `redmine_kit_issue_template_sources` の 2 つのテーブルを作ります。インストールしたら Redmine を再起動します。

<a id="gem"></a>

### gem

`bin/release` が、各バージョンのプラグインを gem として GitHub Packages (`https://rubygems.pkg.github.com/redmine-kit`。[リリース](#releasing)) に公開します。GitHub Packages からのインストールには、公開のパッケージでも `read:packages` の権限を持つ GitHub のトークンが必要です。Redmine の `Gemfile.local` に gem を追加し、Redmine のフォルダーでインストールとマイグレーションを実行します。

```ruby
# Redmine の Gemfile.local
source 'https://rubygems.pkg.github.com/redmine-kit' do
  gem 'redmine_kit_issue_template'
end
```

```sh
bundle config set --global rubygems.pkg.github.com <ユーザー>:<トークン>   # または BUNDLE_RUBYGEMS__PKG__GITHUB__COM
bundle install
bin/rails redmine:plugins:migrate RAILS_ENV=production
```

Bundler は `boot/redmine_kit_issue_template.rb` を読み込みます。このファイルが gem のフォルダーを Redmine のプラグインローダーに渡すので、Redmine は `plugins/` のプラグインと同じように、gem の `init.rb` を実行し、アセット、文字列、ビュー、マイグレーションを使い、`lib/` と `app/` を Rails のコードローダーに追加して、ルートを登録します。`plugins/` に同じ ID のフォルダーがあれば、そちらが優先されます。

<a id="in-plugins"></a>

### plugins/ に置く場合

リポジトリを `plugins/redmine_kit_issue_template` にクローンし、マイグレーションを実行します。ほかの gem は不要です。

```sh
git clone https://github.com/redmine-kit/redmine_issue_template.git plugins/redmine_kit_issue_template
bin/rails redmine:plugins:migrate RAILS_ENV=production
```

<a id="configuration"></a>

## 設定

プロジェクトの設定で、モジュール「チケットテンプレート」を有効にします(新しいプロジェクトのデフォルトは、管理 › 設定 › プロジェクト で決めます)。テンプレートを管理するロールには、権限「チケットテンプレートの管理」を与えます。この権限で、プロジェクトの設定の「チケットテンプレート」タブ、「インポート」のボタン、ファイルの編集が使えます。選択画面を使うだけなら、「チケットの追加」の権限で足ります。

そのうえで、リポジトリにテンプレートを置いてリポジトリを取得するか([テンプレートの形式](format.md))、プロジェクトの設定でファイルを追加します([取り込みと同期](sync.md))。

<a id="redmine-kits-new-ui"></a>

## Redmine Kit の新しい UI

[Redmine Kit UI](https://github.com/redmine-kit/redmine_kit_ui) をインストールすると、このプラグインはその拡張 API
(`init.rb` の `kit_ui`。設定は不要です) で新しい UI でも動きます:

- **新しいチケット** は、新しい UI のフォームのステップとしてテンプレートの選択画面を表示します。選んだテンプレートは
  フォームの先頭 (名前の前に選択画面に戻る ‹、その後に説明) に、フォームの入力欄は題名の後、説明の位置に表示します。
  テキストエリアはコンパクトな Markdown エディター (`render` があるときは、回答をコードブロックとして記録すると注記した
  通常のテキストエリア)、`multiple` のドロップダウンは複数選択のリスト、`link` の入力欄には設定するチケットの項目を
  注記します。テンプレートが設定する値は、その項目の位置に読み取り専用 (読み取り専用 (テンプレート)) で表示し、
  フォームではチケットのほかの項目を そのほかの項目 に要約付きで折りたたみます (必須の項目は折りたたみません)。
  作成 はフォームの必須の回答を待ち、最初の 1 件を表示します。作成 をクリックすると各項目のメッセージを表示します。
  テンプレートに入力した内容はフォームを開いている間は残ります。戻ると選択画面で 入力中 と表示し、もう一度選ぶと続きから
  入力できます。ページのサイドバーには、テンプレートの取得元 (テンプレートのファイル)、テンプレートで非表示の項目、
  チケットテンプレートを管理できるユーザーには 設定 › チケットテンプレート へのリンクを表示します。
  ルールは Redmine のフォームと同じで (非表示、設定済み、リンク、必須の項目。説明に書く回答。`config.yml` のとおりの
  空白のチケット)、サーバーでプラグインが決めます。
- **アップロードの欄** は新しい UI 自身のファイルの欄です。新しい UI が Redmine の制限 (サイズ、拡張子、欄の `accept`)
  でファイルをアップロードして Redmine 自身の uploads で送り、フォームは添付ファイルの ID で指します。サーバーは、
  そのリクエストのファイルのうちユーザーがアップロードしたものだけを受け取ります。
- **プロジェクトの設定 › チケットテンプレート** は 2 つのペインです: ファイルとその状態 (エラー、警告) と
  テンプレートの選択画面 (`config.yml`)、そして選んだファイルの 編集 と 削除、メッセージ、プレビュー (ユーザーが見る
  選択画面の行と、そのテンプレートでの新しいチケットのフォーム)、内容、`config.yml` では 設定 (空白のチケットと
  その他の連絡先)。取得元 はファイルの取得元 (リポジトリのフォルダー、リビジョン、日時、またはプロジェクトの設定で編集して
  いるときは プロジェクトの設定) を示し、ファイルのメッセージには エラー または 警告 の見出しが付きます。設定 には
  空白のチケットを許可 の説明と、保存すると `config.yml` を作り直す旨の注記があります。ヘッダーに ヘルプ、インポート
  (リポジトリがあるとき。ツールチップで今すぐフォルダーを読み込むことを示し、Redmine で編集したファイルを置き換えるときは先に確認します)、新しいテンプレート (ファイルを Redmine で編集しているとき) があります。新しいファイルと
  編集 はファイルのフォームをドロワーで開き、入力中のテキストを プレビュー できます。フォームの URL
  (`/projects/<id>/issue_templates/new`、`…/<ファイル>/edit`) を開くと、同じフォームを設定のタブの横のページで、
  形式のヘルプ と一緒に表示します。

新しい UI のモジュールは `assets/javascripts/kit/issue_template.js` で、`frontend/` (React と TypeScript) から
ビルドします。`bin/setup` が、このリポジトリの隣の ui のチェックアウトで、ビルドに使うアプリのパッケージ
(`@redmine-kit/ui`、`@redmine-kit/plugin`) をビルドし、フロントエンドのパッケージをインストールします。そのあと
`cd frontend && npm run check` で型チェック、テスト (`npm test`。Vitest と Testing Library、`@redmine-kit/plugin/testing`)、ビルド、`kit-check-ui` を実行します。ビルドしたファイルはソースと一緒に
コミットします。

<a id="mcp"></a>

## MCP

[redmine_kit_mcp](https://github.com/redmine-kit/redmine_kit_mcp) をインストールすると、AI のクライアントが、ユーザーの権限とトークンのスコープで、MCP からテンプレートを使えます。

| ツール | 内容 | 書き込み | 権限 (スコープ) |
| --- | --- | --- | --- |
| `issue_template.list_templates` | プロジェクトでユーザーが使えるテンプレート (キー、名前、説明、トラッカー。フォームは入力欄とその選択肢、テンプレートが設定する値) と、空白のチケットを作れるか | | `add_issues` |
| `issue_template.create_issue` | テンプレートからのチケットの作成。Redmine の画面と同じく、指定のない項目にテンプレートの値を入れ、テンプレートが設定する項目と非表示の項目は変更できず、フォームの `answers` (入力欄の ref ごと。選択欄とチェックボックスは選択肢の値) を説明にまとめて入力チェックします | ○ | `add_issues` |

`blank_issues_enabled` が false のプロジェクトでは、MCP の `create_issue` も画面と同じく「チケットを作成するには、テンプレートを選択してください。」で拒否します。テンプレートを管理できるユーザーで、トークンにスコープ `manage_issue_templates` がある場合は除きます (Redmine はすべての権限をトークンのスコープでも確認するので、両方のツールがこのスコープを提示します)。アップロードの入力欄には MCP から回答できません。

`issue_template.create_issue` は、MCP の `create_issue` と同じく書き込むツールです。どちらも redmine_kit_mcp の設定「AI クライアントに許す操作」の「チケットの作成」に当たり、それを許しているときだけ提供します。許していないときは、AI クライアントが使えるのは `issue_template.list_templates` だけです。

<a id="skill"></a>

### スキル

redmine_kit_mcp があるとき、このプラグインはスキル (MCP の Skills 拡張: redmine_kit_mcp の[スキル](https://github.com/redmine-kit/redmine_kit_mcp/blob/main/README.ja.md#skills)) も登録します。スキルは、先にテンプレートの一覧を読むこと、フォームに入力欄の ref ごとに回答すること、テンプレートが設定する値はテンプレートに任せること、`issue_template.create_issue` でチケットを作成することをクライアントに指示します。

| スキル | URI | 表示する条件 |
| --- | --- | --- |
| `issue_template.use-issue-templates` | `skill://plugins/issue_template/use-issue-templates/SKILL.md` | トークンで `issue_template.list_templates` と `issue_template.create_issue` を使える (「AI クライアントに許す操作」で「チケットの作成」を許し、スコープ `add_issues` がある)。ユーザーが、モジュール「チケットトラッキング」が有効ないずれかのプロジェクトで「チケットの追加」を持つ |

本文は `config/mcp_skills/use-issue-templates/SKILL.md` です。「チケットの作成」を許していないときは、クライアントに提供しません。

<a id="tests"></a>

## テスト

`bin/test` は、コンテナ ([Apple container](https://github.com/apple/container) がインストールされて動いていればそれ、なければ Docker。`CONTAINER_CLI=container` または `CONTAINER_CLI=docker` で選べます) の中の Redmine 7.0.3 と PostgreSQL 16 で、プラグインのテストを実行します。続けて、プラグインをインストールした状態で、Redmine のチケットの入力画面、プロジェクトの設定、Git リポジトリのテストを実行し、最後に redmine_kit_mcp と redmine_kit_ui (このリポジトリの隣のチェックアウト。`REDMINE_KIT_MCP_DIR` と `REDMINE_KIT_UI` で変更できます) を入れて MCP のツールとスキルのテストを実行します。`REDMINE_KIT_MCP=1 bin/test test/integration/mcp_tools_test.rb` はこれだけを実行します。`bin/test --redmine` は、Redmine のすべてのテストを実行します。GitHub のドキュメントの例は `test/fixtures/github/` にあり、そのままの形でテストします。

実行は、終わったときに (テストの成功、失敗、中断のいずれでも)、自分が起動したサービスのコンテナを停止します (削除はしません)。実行の前から動いていたコンテナと、このリポジトリの別の実行がまだ使っているコンテナは、そのまま動かしておきます。`KEEP_SERVICES=1` を指定すると、実行の後も動かしたままにします。

```sh
bin/test
bin/test --redmine
REDMINE_BRANCH=master bin/test   # Redmine の master ブランチで実行
COVERAGE=1 bin/test              # プラグインのカバレッジも (coverage/coverage.xml)
bin/test-gem                     # gem としてインストールしたプラグイン、続けて plugins/ のプラグイン
bin/services --down              # PostgreSQL (と Chromium) を止める
bin/lint                         # RuboCop と Brakeman (同じコンテナのツールで)
bin/screenshots                  # ドキュメントのスクリーンショット(docs/images/、docs/ja/images/)
```

`COVERAGE=1 bin/test` は、テストによるプラグインのファイルのカバレッジも [SimpleCov](https://github.com/simplecov-ruby/simplecov) で測り、Cobertura XML として `coverage/coverage.xml` に書き出します。1 ワーカーで実行するため、時間が長くかかります。CI は Redmine 7.0.3 でこれを実行し、ファイルを GitHub の OIDC トークンで [Codecov](https://app.codecov.io/gh/redmine-kit/redmine_issue_template) にアップロードします。Codecov のトークンは使いません (`.github/workflows/ci.yml`、`codecov.yml`)。

`bin/screenshots` (`bin/test` と同じく Apple container または Docker) は、Redmine のテストのデータと GitHub の例を使い、ヘッドレスの Chromium でスクリーンショットを撮ります(`test/screenshots/screens.rb`)。画面を変えたら実行します。

<a id="releasing"></a>
## リリース

`bin/release` は、gemspec のバージョンの gem を GitHub Packages の Redmine Kit のレジストリに公開します。実行できるのは変更のない `main` からだけで、バージョンが最後のタグ `v<version>` より新しいこと、必須プラグインがレジストリから範囲どおりに解決できること (`config/dependencies.yml`)、`bin/lint`、`bin/test`、`bin/test-gem` が成功することが条件です。公開には `~/.gem/credentials` のキー `github` (`:github: Bearer <token>`。`write:packages` を持つトークン) を使い、レジストリの読み取りには `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` を使います。トークンはリポジトリにも出力にも含めません。署名付きのタグ `v<version>` を作り、それをプッシュするコマンドを表示します。バージョンはセマンティックバージョニングに従います。このプラグインを使うプラグインが動かなくなる変更ではメジャーバージョン (1.0 より前はマイナーバージョン) を上げ、それを必要とするプラグインの範囲も変えます。

<a id="to-verify"></a>

## 未確認の事項

- Subversion、Mercurial など、Git 以外の SCM に置いたテンプレート(テストは Git で行っています)。
- 大きなリポジトリでの所要時間。取り込みは、リポジトリの取得で新しいコミットが追加されるたびにテンプレートフォルダーを読みます。
